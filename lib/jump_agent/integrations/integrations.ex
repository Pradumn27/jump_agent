defmodule JumpAgent.Integrations do
  alias JumpAgent.Accounts

  require Logger

  def get_integrations(user) do
    statuses =
      JumpAgent.Integrations.Status.list_integration_statuses(user)
      |> Map.new(fn status -> {status.integration, status} end)

    is_hubspot_connected =
      case Accounts.get_auth_identity(user, "hubspot") do
        %{token: _token} -> true
        _ -> false
      end

    gmail_status = statuses["Gmail"] || %{}
    calendar_status = statuses["Calendar"] || %{}
    hubspot_status = statuses["HubSpot"] || %{}

    [
      %{
        "name" => "Gmail",
        "description" => "Sync your emails with Gmail",
        "status" => "connected",
        "sync_status" => Map.get(gmail_status, :status, "disconnected"),
        "last_synced_at" => Map.get(gmail_status, :last_synced_at),
        "canDisconnect" => false
      },
      %{
        "name" => "Calendar",
        "description" => "Sync your calendar events with Google Calendar",
        "status" => "connected",
        "sync_status" => Map.get(calendar_status, :status, "disconnected"),
        "last_synced_at" => Map.get(calendar_status, :last_synced_at),
        "canDisconnect" => false
      },
      %{
        "name" => "HubSpot",
        "description" => "Sync your contacts with HubSpot",
        "status" => (is_hubspot_connected && "connected") || "disconnected",
        "sync_status" => Map.get(hubspot_status, :status, "disconnected"),
        "last_synced_at" => Map.get(hubspot_status, :last_synced_at),
        "canDisconnect" => true
      }
    ]
  end

  def sync_integrations(user) do
    [
      {"Gmail", fn -> JumpAgent.Integrations.Gmail.fetch_recent_emails(user, 10) end},
      {"Calendar", fn -> JumpAgent.Integrations.Calendar.sync_upcoming_events(user, 50) end},
      {"HubSpot", fn -> maybe_sync_hubspot(user) end}
    ]
    |> Enum.each(fn {name, task_fn} ->
      Task.start(fn ->
        try do
          task_fn.()

          JumpAgent.Integrations.Status.update_status(user, name, "completed",
            last_synced_at: DateTime.utc_now()
          )

          Phoenix.PubSub.broadcast(
            JumpAgent.PubSub,
            "integration_sync:#{user.id}",
            {:integration_status_updated}
          )
        rescue
          e ->
            Logger.error("Failed to sync #{name}: #{inspect(e)}")

            JumpAgent.Integrations.Status.update_status(user, name, "error")

            Phoenix.PubSub.broadcast(
              JumpAgent.PubSub,
              "integration_sync:#{user.id}",
              {:integration_status_updated}
            )
        end
      end)
    end)
  end

  defp safe_sync(task_fn, user, name) do
    try do
      task_fn.()

      JumpAgent.Integrations.Status.update_status(user, name, "completed",
        last_synced_at: DateTime.utc_now()
      )

      Phoenix.PubSub.broadcast(
        JumpAgent.PubSub,
        "integration_sync:#{user.id}",
        {:integration_status_updated}
      )
    rescue
      e ->
        Logger.error("Failed to sync #{name}: #{inspect(e)}")
        JumpAgent.Integrations.Status.update_status(user, name, "error")
    end
  end

  defp maybe_sync_hubspot(user) do
    case JumpAgent.Accounts.get_auth_identity(user, "hubspot") do
      %{token: _token} ->
        safe_sync(
          fn -> JumpAgent.Integrations.Hubspot.sync_contacts(user, 50) end,
          user,
          "HubSpot"
        )

        safe_sync(
          fn -> JumpAgent.Integrations.Hubspot.sync_notes(user, 50) end,
          user,
          "HubSpot"
        )

      _ ->
        Logger.debug("HubSpot not connected for user #{user.id}")
    end
  end
end
