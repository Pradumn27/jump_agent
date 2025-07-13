defmodule JumpAgent.Integrations.Calendar do
  alias JumpAgent.Accounts
  alias JumpAgent.Knowledge
  alias GoogleApi.Calendar.V3.Api.Events
  alias GoogleApi.Calendar.V3.Connection
  require Logger

  def sync_upcoming_events(user, max_results \\ 500) do
    with {:ok, token} <- get_google_token(user),
         conn <- Connection.new(token),
         {:ok, %{items: events}} <-
           Events.calendar_events_list(conn, "primary",
             maxResults: max_results,
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

    end_time = event.end.dateTime || event.end.date || "unknown"

    attendees =
      (event.attendees || [])
      |> Enum.map(& &1.email)
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    content = """
    Event: #{event.summary || "No title"}
    Description: #{event.description || "No description"}
    Location: #{event.location || "No location"}
    Start Time: #{start_time}
    End Time: #{end_time}
    Attendees: #{attendees}
    Event ID: #{event.id}
    """

    Knowledge.create_context(%{
      source: "calendar",
      source_id: event.id,
      content: content,
      metadata: %{
        summary: event.summary,
        location: event.location,
        start: start_time,
        end: end_time
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

  def create_meeting(user, %{} = params) do
    summary = Map.get(params, "summary", "Untitled Event")
    description = Map.get(params, "description", "")
    location = Map.get(params, "location", "")
    start_time = Map.get(params, "start_time")
    end_time = Map.get(params, "end_time")
    attendees = Map.get(params, "attendees", [])

    with {:ok, token} <- get_google_token(user),
         conn <- GoogleApi.Calendar.V3.Connection.new(token) do
      event = [
        body: %GoogleApi.Calendar.V3.Model.Event{
          summary: summary,
          description: description,
          location: location,
          start: %GoogleApi.Calendar.V3.Model.EventDateTime{
            dateTime: start_time,
            timeZone: "Asia/Kolkata"
          },
          end: %GoogleApi.Calendar.V3.Model.EventDateTime{
            dateTime: end_time,
            timeZone: "Asia/Kolkata"
          },
          attendees:
            Enum.map(attendees, fn email ->
              %GoogleApi.Calendar.V3.Model.EventAttendee{email: email}
            end)
        }
      ]

      GoogleApi.Calendar.V3.Api.Events.calendar_events_insert(conn, "primary", event, [])

      Task.start(fn ->
        try do
          sync_upcoming_events(user, 10)
        rescue
          e -> Logger.error("Calendar sync failed for user #{user.id}: #{inspect(e)}")
        end
      end)
    else
      error -> {:error, error}
    end
  end

  def cancel_meeting(user, event_id) do
    with {:ok, token} <- get_google_token(user),
         conn <- GoogleApi.Calendar.V3.Connection.new(token),
         {:ok, _} <-
           GoogleApi.Calendar.V3.Api.Events.calendar_events_delete(conn, "primary", event_id) do
      :ok
    else
      error -> {:error, error}
    end
  end

  def reschedule_meeting(user, event_id, new_start_time, new_end_time) do
    with {:ok, token} <- get_google_token(user),
         conn <- GoogleApi.Calendar.V3.Connection.new(token),
         {:ok, event} <-
           GoogleApi.Calendar.V3.Api.Events.calendar_events_get(conn, "primary", event_id),
         updated_event = %GoogleApi.Calendar.V3.Model.Event{
           event
           | start: %GoogleApi.Calendar.V3.Model.EventDateTime{
               dateTime: new_start_time,
               timeZone: "Asia/Kolkata"
             },
             end: %GoogleApi.Calendar.V3.Model.EventDateTime{
               dateTime: new_end_time,
               timeZone: "Asia/Kolkata"
             }
         },
         {:ok, event} <-
           GoogleApi.Calendar.V3.Api.Events.calendar_events_update(
             conn,
             "primary",
             event_id,
             body: updated_event
           ) do
      # ✅ Start calendar sync in background
      Task.start(fn ->
        try do
          sync_upcoming_events(user, 10)
        rescue
          e -> Logger.error("Calendar sync failed after reschedule: #{inspect(e)}")
        end
      end)

      {:ok, event}
    else
      error -> {:error, error}
    end
  end
end
