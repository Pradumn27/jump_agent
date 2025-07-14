defmodule JumpAgent.OAuth.Hubspot do
  require Logger

  def refresh_token(refresh_token) do
    body =
      URI.encode_query(%{
        grant_type: "refresh_token",
        client_id: Application.fetch_env!(:jump_agent, :hubspot)[:client_id],
        client_secret: Application.fetch_env!(:jump_agent, :hubspot)[:client_secret],
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
