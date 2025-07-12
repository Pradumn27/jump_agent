defmodule JumpAgent.Integrations.Calendar do
  alias JumpAgent.Accounts
  alias JumpAgent.Knowledge
  alias GoogleApi.Calendar.V3.Api.Events
  alias GoogleApi.Calendar.V3.Connection

  def sync_upcoming_events(user) do
    with {:ok, token} <- get_google_token(user),
         conn <- Connection.new(token),
         {:ok, %{items: events}} <-
           Events.calendar_events_list(conn, "primary",
             maxResults: 10,
             timeMin: DateTime.utc_now() |> DateTime.to_iso8601(),
             singleEvents: true,
             orderBy: "startTime"
           ) do
      Enum.each(events, fn event -> store_event_context(user, event) end)
      {:ok, :synced}
    else
      error -> {:error, error}
    end
  end

  defp store_event_context(user, event) do
    start_time =
      event.start.dateTime || event.start.date || "unknown"

    content = """
    Event: #{event.summary || "No title"}
    Description: #{event.description || "No description"}
    Location: #{event.location || "No location"}
    Start Time: #{start_time}
    """

    Knowledge.create_context(%{
      source: "calendar",
      source_id: event.id,
      content: content,
      metadata: %{
        summary: event.summary,
        start: start_time,
        location: event.location
      },
      user_id: user.id
    })
  end

  defp get_google_token(user) do
    case Accounts.get_user!(user.id) do
      %{token: token, refresh_token: refresh_token, expires_at: expires_at} ->
        if expired?(expires_at) do
          # Refresh the access token using the refresh token
          JumpAgent.OAuth.Google.refresh_token(refresh_token)
        else
          {:ok, token}
        end

      _ ->
        {:error, :no_google_auth}
    end
  end

  defp expired?(datetime) do
    DateTime.compare(datetime, DateTime.utc_now()) == :lt
  end
end
