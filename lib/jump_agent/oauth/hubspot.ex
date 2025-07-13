defmodule JumpAgent.OAuth.Hubspot do
  require Logger

  def refresh_token(refresh_token) do
    client_id = "c5520986-8dca-4fe4-8998-aa9fbd39467c"
    client_secret = "fbfd499b-aec0-4e4a-ab72-2fb417866427"

    body =
      URI.encode_query(%{
        grant_type: "refresh_token",
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: refresh_token
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://api.hubapi.com/oauth/v1/token", body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        Logger.error("HubSpot token refresh failed with status #{status}: #{body}")
        {:error, :hubspot_refresh_failed}

      {:error, reason} ->
        Logger.error("HTTP error while refreshing HubSpot token: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
