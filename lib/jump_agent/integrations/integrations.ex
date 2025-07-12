defmodule JumpAgent.Integrations do
  alias JumpAgent.Accounts

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
end
