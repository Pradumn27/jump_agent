defmodule JumpAgent.Embedding do
  @moduledoc """
  Handles generating embeddings for content using OpenAI.
  """

  @openai_url "https://api.openai.com/v1/embeddings"
  # or "text-embedding-3-small" depending on your plan
  @model "text-embedding-ada-002"

  def generate(text) when is_binary(text) do
    open_ai_key = Application.get_env(:jump_agent, :openai)[:api_key]

    headers = [
      {"Authorization", "Bearer #{open_ai_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        "input" => text,
        "model" => @model
      })

    case HTTPoison.post(@openai_url, body, headers, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => [%{"embedding" => embedding}]}} -> embedding
          _ -> []
        end

      error ->
        IO.inspect(error, label: "Embedding error")
        []
    end
  end
end
