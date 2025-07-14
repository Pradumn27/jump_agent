defmodule JumpAgentWeb.Dashboard.Components.HubspotConnect do
  use Phoenix.LiveComponent
  import JumpAgentWeb.CoreComponents
  alias Phoenix.LiveView.JS

  def hubspot_connect_button(assigns) do
    ~H"""
    <%= if @current_user do %>
      <.button
        phx-click={show_modal("hubspot-connect-modal")}
        class="bg-green-600 hover:bg-green-700 text-white"
      >
        Connect HubSpot
      </.button>
      <.hubspot_connect_modal />
    <% end %>
    """
  end

  def hubspot_connect_modal(assigns) do
    ~H"""
    <.modal id="hubspot-connect-modal" on_cancel={JS.push("close_modal")}>
      <div class="w-full p-6 rounded-lg relative">
        <h2 class="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
          HubSpot
        </h2>

        <p class="text-sm text-gray-600 mb-4">
          Your HubSpot user must have permission to view and edit contacts. This connection requires the following scopes:
        </p>

        <ul class="text-sm text-gray-700 list-disc list-inside space-y-1 mb-4">
          <li><strong>Contacts:</strong> Read and write access to CRM contacts.</li>
          <li><strong>Contact Notes:</strong> Read and write access to CRM contact notes.</li>
        </ul>

        <p class="text-xs text-gray-500 mb-4">
          If you need more permissions in the future (like syncing tasks, or meetings), you’ll need to reconnect with those additional scopes enabled.
        </p>

        <div class="flex justify-end space-x-2">
          <.button
            phx-click={JS.hide(to: "#hubspot-connect-modal")}
            class="bg-gray-200 hover:bg-gray-300 text-gray-800"
          >
            Cancel
          </.button>
          <.link navigate="/auth/hubspot">
            <.button class="bg-green-600 hover:bg-green-700 text-white">Connect</.button>
          </.link>
        </div>
      </div>
    </.modal>
    """
  end
end
