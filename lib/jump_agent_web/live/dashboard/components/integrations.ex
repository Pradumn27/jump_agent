defmodule JumpAgentWeb.Dashboard.Components.Integrations do
  use Phoenix.LiveComponent
  import JumpAgentWeb.CoreComponents

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

              <div class="flex items-center space-x-2">
                <%= if integration["status"] == "disconnected" do %>
                  <.link href="/auth/hubspot">
                    <button class="bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded-md">
                      Connect {integration["name"]}
                    </button>
                  </.link>
                <% end %>
                <%= if integration["status"] == "connected" && integration["name"] == "HubSpot" do %>
                  <.button
                    phx-click="disconnect_integration"
                    phx-value-name={integration["name"]}
                    class="bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded-md"
                  >
                    Disconnect
                  </.button>
                <% end %>
                <%= if integration["status"] == "connected" do %>
                  <div
                    phx-click="sync_integration"
                    phx-value-name={integration["name"]}
                    class="cursor-pointer bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded-md"
                  >
                    Sync
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
