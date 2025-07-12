defmodule JumpAgent.OpenAI do
  @moduledoc false
  require Logger
  alias JumpAgent.Embedding
  alias JumpAgent.Knowledge

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

    IO.puts(context_text)

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

    body =
      Jason.encode!(%{
        model: "gpt-3.5-turbo",
        messages: [
          %{role: "system", content: final_prompt}
        ]
      })

    case HTTPoison.post("https://api.openai.com/v1/chat/completions", body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, response} = Jason.decode(body)
        reply = get_in(response, ["choices", Access.at(0), "message", "content"])
        {:ok, reply}

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        Logger.error("❌ OpenAI returned #{status}: #{inspect(body)}")
        {:error, body}

      {:error, reason} ->
        Logger.error("❌ HTTP request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
