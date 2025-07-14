defmodule JumpAgent.OAuth.Google do
  @token_url "https://oauth2.googleapis.com/token"

  def refresh_token(refresh_token) do
    body =
      URI.encode_query(%{
        client_id:
          Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id],
        client_secret:
          Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret],
        refresh_token: refresh_token,
        grant_type: "refresh_token"
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case Req.post(@token_url, body: body, headers: headers) do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      error ->
        {:error, error}
    end
  end
end
