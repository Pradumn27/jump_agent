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
        "name" => "Google Calendar",
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
    # Gmail
    try do
      JumpAgent.Integrations.Gmail.fetch_recent_emails(user)
    rescue
      e -> Logger.error("Failed to sync Gmail: #{inspect(e)}")
    end

    # Google Calendar
    try do
      JumpAgent.Integrations.Calendar.sync_upcoming_events(user)
    rescue
      e -> Logger.error("Failed to sync Calendar: #{inspect(e)}")
    end

    # HubSpot (conditionally)
    case Accounts.get_auth_identity(user, "hubspot") do
      %{token: _token} ->
        try do
          JumpAgent.Integrations.Hubspot.sync_contacts(user)
          JumpAgent.Integrations.Hubspot.sync_notes(user)
        rescue
          e -> Logger.error("Failed to sync HubSpot: #{inspect(e)}")
        end

      _ ->
        Logger.debug("HubSpot not connected for user #{user.id}")
    end
  end
end
