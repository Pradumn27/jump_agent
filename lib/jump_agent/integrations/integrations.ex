defmodule JumpAgent.Integrations do
  alias JumpAgent.Accounts

  require Logger

  def get_integrations(user) do
    is_hubspot_connected =
      case Accounts.get_auth_identity(user, "hubspot") do
        %{token: _token} -> true
        _ -> false
      end

    [
      %{
        "name" => "Gmail",
        "description" => "Sync your emails with Gmail",
        "status" => "connected",
        "canDisconnect" => false
      },
      %{
        "name" => "Calendar",
        "description" => "Sync your calendar events with Google Calendar",
        "status" => "connected",
        "canDisconnect" => false
      },
      %{
        "name" => "HubSpot",
        "description" => "Sync your contacts with HubSpot",
        "status" => (is_hubspot_connected && "connected") || "disconnected",
        "canDisconnect" => true
      }
    ]
  end

  def sync_integrations(user) do
    tasks = [
      fn ->
        safe_sync(fn -> JumpAgent.Integrations.Gmail.fetch_recent_emails(user, 10) end, "Gmail")
      end,
      fn ->
        safe_sync(
          fn -> JumpAgent.Integrations.Calendar.sync_upcoming_events(user, 50) end,
          "Calendar"
        )
      end,
      fn -> maybe_sync_hubspot(user) end
    ]

    Task.async_stream(tasks, & &1.(), max_concurrency: 3, timeout: 30_000)
    |> Stream.run()
  end

  defp safe_sync(task_fn, label) do
    try do
      task_fn.()
    rescue
      e -> Logger.error("Failed to sync #{label}: #{inspect(e)}")
    end
  end

  defp maybe_sync_hubspot(user) do
    case JumpAgent.Accounts.get_auth_identity(user, "hubspot") do
      %{token: _token} ->
        safe_sync(
          fn -> JumpAgent.Integrations.Hubspot.sync_contacts(user, 50) end,
          "HubSpot Contacts"
        )

        safe_sync(fn -> JumpAgent.Integrations.Hubspot.sync_notes(user, 50) end, "HubSpot Notes")

      _ ->
        Logger.debug("HubSpot not connected for user #{user.id}")
    end
  end
end
