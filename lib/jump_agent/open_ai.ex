defmodule JumpAgent.OpenAI do
  @moduledoc false
  require Logger
  alias JumpAgent.Embedding
  alias JumpAgent.Knowledge
  alias JumpAgent.AgentTools

  def chat_completion(user_prompt, user, chat_session_id) do
    api_key = Application.get_env(:jump_agent, :openai)[:api_key]

    embedding = Embedding.generate(user_prompt)

    contexts =
      Knowledge.search_similar_contexts(embedding, user.id, 50)

    chat_history =
      JumpAgent.Chat.get_chat_session_with_messages!(chat_session_id)
      |> Map.get(:messages)
      |> Enum.sort_by(& &1.inserted_at)
      |> Enum.map_join("\n", fn msg ->
        "#{msg.role}: #{msg.content}"
      end)

    context_text =
      contexts
      |> Enum.map(& &1.content)
      |> Enum.join("\n\n")

    tools = AgentTools.get_tools()

    final_prompt = """
    You are a helpful assistant.
    When presenting email messages, format them using **Markdown triple backtick code blocks** (```).
    Only use **plain text** formatting inside the code block — no bold/italic or Markdown inside.

    Always prefer full email bodies over snippets. Use your best judgment to summarize **only if full content is unavailable**.

    Use the following context if relevant:

    Previous conversation:
    #{chat_history}

    <------------------------>

    Relevant knowledge context:
    #{context_text}

    <------------------------>

    User has the email #{user.email}

    <------------------------>

    User Question: #{user_prompt}
    """

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    messages = [
      %{role: "system", content: final_prompt}
    ]

    body =
      Jason.encode!(%{
        model: "gpt-4o",
        messages: messages,
        tools: tools,
        tool_choice: "auto"
      })

    case HTTPoison.post("https://api.openai.com/v1/chat/completions", body, headers,
           # Wait up to 30 seconds for a response
           recv_timeout: 30_000,
           # Wait up to 10 seconds for connect
           timeout: 10_000
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, response} = Jason.decode(body)

        case get_in(response, ["choices", Access.at(0), "message", "tool_calls"]) do
          nil ->
            reply = get_in(response, ["choices", Access.at(0), "message", "content"])
            {:ok, reply}

          tool_calls ->
            Enum.each(tool_calls, fn %{
                                       "function" => %{
                                         "name" => tool_name,
                                         "arguments" => args_json
                                       },
                                       "id" => tool_call_id
                                     } ->
              {:ok, args} = Jason.decode(args_json)
              result = AgentTools.Dispatcher.dispatch_tool(tool_name, user, args)
              send_tool_response_to_openai(messages, tool_call_id, tool_name, result)
            end)

            {:ok, "Tool call in progress"}
        end

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        Logger.error("❌ OpenAI returned #{status}: #{inspect(body)}")
        {:error, body}

      {:error, reason} ->
        Logger.error("❌ HTTP request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def chat_completion_for_triggers(trigger_instruction, user, last_executed_at \\ nil) do
    api_key = Application.get_env(:jump_agent, :openai)[:api_key]

    embedding = Embedding.generate(trigger_instruction)

    contexts =
      Knowledge.search_similar_contexts(embedding, user.id, 100)

    context_text =
      contexts
      |> Enum.map(& &1.content)
      |> Enum.join("\n\n")

    final_prompt = """
    You are an autonomous assistant responding to an automation **triggered event**.

    This was **not manually asked by the user**, but generated as part of an automated instruction.

    Use the provided context and tools to take action automatically. Do not ask for confirmation.

    Only consider **events that happened after** this time: #{DateTime.to_iso8601(last_executed_at || DateTime.utc_now())}

    Use older context only if needed for reference, not for deciding what to act on.

    <------------------------>

    Relevant knowledge context:
    #{context_text}

    <------------------------>

    Triggered instruction:
    #{trigger_instruction}

    User email: #{user.email}
    """

    tools = AgentTools.get_tools()

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    messages = [
      %{role: "system", content: final_prompt}
    ]

    body =
      Jason.encode!(%{
        model: "gpt-4o",
        messages: messages,
        tools: tools,
        tool_choice: "auto"
      })

    case HTTPoison.post("https://api.openai.com/v1/chat/completions", body, headers,
           # Wait up to 30 seconds for a response
           recv_timeout: 30_000,
           # Wait up to 10 seconds for connect
           timeout: 10_000
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, response} = Jason.decode(body)

        case get_in(response, ["choices", Access.at(0), "message", "tool_calls"]) do
          nil ->
            reply = get_in(response, ["choices", Access.at(0), "message", "content"])
            {:ok, reply}

          tool_calls ->
            Enum.each(tool_calls, fn %{
                                       "function" => %{
                                         "name" => tool_name,
                                         "arguments" => args_json
                                       },
                                       "id" => tool_call_id
                                     } ->
              {:ok, args} = Jason.decode(args_json)
              result = AgentTools.Dispatcher.dispatch_tool(tool_name, user, args)
              send_tool_response_to_openai(messages, tool_call_id, tool_name, result)
            end)

            {:ok, "Tool call in progress"}
        end

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        Logger.error("❌ OpenAI returned #{status}: #{inspect(body)}")
        {:error, body}

      {:error, reason} ->
        Logger.error("❌ HTTP request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def send_tool_response_to_openai(previous_messages, tool_call_id, function_name, result) do
    api_key = Application.get_env(:jump_agent, :openai)[:api_key]

    content =
      case result do
        {:ok, data} -> data
        {:error, reason} -> %{"error" => inspect(reason)}
        other -> %{"unexpected" => inspect(other)}
      end

    new_messages =
      previous_messages ++
        [
          %{
            role: "assistant",
            tool_calls: [
              %{
                id: tool_call_id,
                type: "function",
                function: %{name: function_name, arguments: "{}"}
              }
            ]
          },
          %{
            role: "tool",
            tool_call_id: tool_call_id,
            name: function_name,
            content: Jason.encode!(content)
          }
        ]

    body =
      Jason.encode!(%{
        model: "gpt-4o",
        messages: new_messages
      })

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    HTTPoison.post("https://api.openai.com/v1/chat/completions", body, headers)
  end
end
