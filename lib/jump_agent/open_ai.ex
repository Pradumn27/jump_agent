defmodule JumpAgent.OpenAI do
  @moduledoc false
  require Logger
  alias JumpAgent.Embedding
  alias JumpAgent.Knowledge
  alias JumpAgent.Tools

  def chat_completion(user_prompt, user, chat_session_id) do
    api_key = Application.get_env(:jump_agent, :openai)[:api_key]

    embedding = Embedding.generate(user_prompt)

    contexts =
      Knowledge.search_similar_contexts(embedding, 100)

    # |> filter_by_user(user.id)

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

    tools = Tools.get_tools()

    final_prompt = """
    You are a helpful assistant. Use the following context if relevant:

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

    case HTTPoison.post("https://api.openai.com/v1/chat/completions", body, headers) do
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
              result = Tools.dispatch_tool(tool_name, user, args)
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

  @spec send_tool_response_to_openai(list(), any(), any(), any()) ::
          {:error, HTTPoison.Error.t()}
          | {:ok,
             %{
               :__struct__ =>
                 HTTPoison.AsyncResponse | HTTPoison.MaybeRedirect | HTTPoison.Response,
               optional(:body) => any(),
               optional(:headers) => list(),
               optional(:id) => reference(),
               optional(:redirect_url) => any(),
               optional(:request) => HTTPoison.Request.t(),
               optional(:request_url) => any(),
               optional(:status_code) => integer()
             }}
  def send_tool_response_to_openai(previous_messages, tool_call_id, function_name, result) do
    api_key = Application.get_env(:jump_agent, :openai)[:api_key]

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
            content: result
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
