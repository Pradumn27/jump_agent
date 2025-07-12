defmodule JumpAgent.OAuth.Google do
  @token_url "https://oauth2.googleapis.com/token"
  @client_id "530016174947-s1n491d8ab8e5dsifhkgiqdj90njo1dk.apps.googleusercontent.com"
  @client_secret "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"

  def refresh_token(refresh_token) do
    body =
      URI.encode_query(%{
        client_id: @client_id,
        client_secret: @client_secret,
        refresh_token: refresh_token,
        grant_type: "refresh_token"
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case Req.post(@token_url, body: body, headers: headers) do
      {:ok, %{status: 200, body: %{"access_token" => token, "expires_in" => expires_in}}} ->
        {:ok, token}

      error ->
        {:error, error}
    end
  end
end
