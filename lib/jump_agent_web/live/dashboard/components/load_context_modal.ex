defmodule JumpAgentWeb.Dashboard.Components.LoadContextModal do
  use Phoenix.LiveComponent
  import JumpAgentWeb.CoreComponents
  alias Phoenix.LiveView.JS

  def load_context_modal(assigns) do
    ~H"""
    <.modal
      :if={@show_load_context_modal}
      id="load-context-modal"
      on_cancel={JS.push("close_load_context_modal")}
      show={@show_load_context_modal}
    >
      <div class="p-6 w-full bg-white rounded-lg">
        <h2 class="text-xl font-semibold text-gray-900 mb-2 flex items-center gap-2">
          <.icon name="hero-light-bulb" class="w-5 h-5 text-yellow-500" />
          Load Context for Better AI Results
        </h2>
        <p class="text-sm text-gray-600 mb-4">
          Loading your Gmail, Calendar, and HubSpot data helps the AI provide better insights and personalized responses.
        </p>
        <div class="flex justify-end gap-2">
          <.button
            class="bg-gray-300 text-gray-800 hover:bg-gray-300"
            phx-click="close_load_context_modal"
          >
            Not Now
          </.button>
          <.button class="bg-green-600 text-white hover:bg-green-700" phx-click="confirm_load_context">
            Load Context
          </.button>
        </div>
      </div>
    </.modal>
    """
  end
end
