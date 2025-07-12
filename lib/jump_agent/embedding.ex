defmodule JumpAgent.Embedding do
  @moduledoc """
  Handles generating embeddings for content using OpenAI.
  """

  @openai_url "https://api.openai.com/v1/embeddings"
  # or "text-embedding-3-small" depending on your plan
  @model "text-embedding-ada-002"

  def generate(text) when is_binary(text) do
    headers = [
      {"Authorization",
       "Bearer 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"},
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
