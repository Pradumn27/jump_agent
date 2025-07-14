defmodule JumpAgentWeb.Dashboard.Components.Integrations do
  use Phoenix.LiveComponent
  import JumpAgentWeb.CoreComponents
  import JumpAgentWeb.Dashboard.Components.HubspotConnect
  alias Phoenix.LiveView.JS

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %I:%M %p")
  end

  def integrations(assigns) do
    ~H"""
    <div class="rounded-lg border bg-white text-card-foreground shadow-sm border border-gray-200 shadow-sm">
      <div class="flex flex-col space-y-1.5 p-6">
        <div class="font-semibold leading-none tracking-tight text-lg text-gray-900">
          Integrations
        </div>
        <div class="text-sm text-muted-foreground text-gray-600">
          Manage your connected services and data sources
        </div>
      </div>
      <div class="p-6 pt-0 space-y-4">
        <%= for integration <- @integrations do %>
          <div class={
            "p-4 rounded-lg border-2 transition-all " <>
            case integration["sync_status"] do
              "syncing" -> "border-yellow-300 bg-yellow-50"
              "stale_sync" -> "border-yellow-400 bg-yellow-100"
              "completed" -> "border-green-200 bg-green-50"
              "error" -> "border-red-200 bg-red-50"
              _ -> "border-gray-200 bg-gray-50"
            end
          }>
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-3">
                <%= case integration["sync_status"] do %>
                  <% "syncing" -> %>
                    <.icon name="hero-arrow-path" class="h-5 w-5 animate-spin text-yellow-500" />
                  <% "stale_sync" -> %>
                    <span class="text-yellow-700">Still syncing? Try again from more options.</span>
                  <% "completed" -> %>
                    <.icon name="hero-check-circle" class="h-5 w-5 text-green-600" />
                  <% "error" -> %>
                    <.icon name="hero-x-circle" class="h-5 w-5 text-red-600" />
                  <% _ -> %>
                    <div class="h-5 w-5 rounded-full border-2 border-gray-300" />
                <% end %>

                <div>
                  <p class="font-medium text-gray-900">{integration["name"]}</p>
                  <p class="text-sm text-gray-600">{integration["description"]}</p>
                  <%= if integration["sync_status"] do %>
                    <p class="text-xs mt-1">
                      <%= case integration["sync_status"] do %>
                        <% "syncing" -> %>
                          <span class="text-yellow-600">Syncing...</span>
                        <% "completed" -> %>
                          <span class="text-green-600">
                            Last synced: {format_datetime(integration["last_synced_at"])} UTC
                          </span>
                        <% "error" -> %>
                          <span class="text-red-600">Sync failed</span>
                        <% _ -> %>
                          <span class="text-gray-500">Not synced yet</span>
                      <% end %>
                    </p>
                  <% end %>
                </div>
              </div>

              <div class="relative" id={"wrapper-#{integration["name"]}"}>
                <%= if integration["status"] == "disconnected" do %>
                  <.hubspot_connect_button current_user={@current_user} />
                <% else %>
                  <button
                    type="button"
                    phx-click={JS.toggle(to: "#dropdown-#{integration["name"]}", display: "block")}
                    phx-click-away={JS.hide(to: "#dropdown-#{integration["name"]}")}
                    class="text-gray-600 hover:text-gray-800 p-2 rounded-full"
                    aria-label="More options"
                  >
                    <.icon name="hero-ellipsis-vertical" class="h-5 w-5" />
                  </button>
                  <div
                    id={"dropdown-#{integration["name"]}"}
                    class="hidden absolute right-0 z-50 mt-2 w-36 bg-white border border-gray-200 rounded-md shadow-lg"
                  >
                    <div class="flex flex-col divide-y">
                      <button
                        phx-click="sync_integration"
                        phx-value-name={integration["name"]}
                        class="px-4 py-2 text-sm text-left hover:bg-gray-100"
                      >
                        Sync
                      </button>
                      <%= if integration["name"] == "HubSpot" do %>
                        <button
                          phx-click="disconnect_integration"
                          phx-value-name={integration["name"]}
                          class="px-4 py-2 text-sm text-left text-red-600 hover:bg-gray-100"
                        >
                          Disconnect
                        </button>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
