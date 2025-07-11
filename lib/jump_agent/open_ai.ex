defmodule JumpAgent.OpenAI do
  @moduledoc false
  require Logger

  def chat_completion(prompt) do
    api_key = Application.get_env(:jump_agent, :openai)[:api_key]

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    body =
      Jason.encode!(%{
        model: "gpt-3.5-turbo",
        messages: [
          %{role: "system", content: "You are a helpful assistant."},
          %{role: "user", content: prompt}
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
