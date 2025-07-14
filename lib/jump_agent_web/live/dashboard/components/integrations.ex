defmodule JumpAgentWeb.Dashboard.Components.Integrations do
  use Phoenix.LiveComponent
  import JumpAgentWeb.CoreComponents
  alias Phoenix.LiveView.JS

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
            "p-4 rounded-lg border-2 " <>
            if integration["status"] == "connected", do: "border-green-200 bg-green-50", else: "border-gray-200 bg-gray-50"
          }>
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-3">
                <%= if integration["status"] == "connected" do %>
                  <.icon name="hero-check-circle" class="h-5 w-5 text-green-600" />
                <% else %>
                  <div class="h-5 w-5 rounded-full border-2 border-gray-300" />
                <% end %>
                <div>
                  <p class="font-medium text-gray-900">{integration["name"]}</p>
                  <p class="text-sm text-gray-600">{integration["description"]}</p>
                </div>
              </div>

              <div class="relative" id={"wrapper-#{integration["name"]}"}>
                <%= if integration["status"] == "disconnected" do %>
                  <.link href="/auth/#{String.downcase(integration['name'])}">
                    <button class="bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded-md">
                      Connect {integration["name"]}
                    </button>
                  </.link>
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
