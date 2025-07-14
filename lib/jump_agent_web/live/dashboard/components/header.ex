defmodule JumpAgentWeb.Dashboard.Components.Header do
  use Phoenix.LiveComponent
  import JumpAgentWeb.CoreComponents

  def profile_menu(assigns) do
    ~H"""
    <div id="user-dropdown" class="relative" phx-click-away="close">
      <button
        type="button"
        phx-click="toggle"
        class="flex items-center space-x-3 text-gray-700 hover:bg-gray-100 rounded-md px-3 py-2 w-full"
      >
        <div class="relative w-8 h-8 rounded-full overflow-hidden bg-gray-200">
          <img
            src={@current_user.avatar || "/placeholder.svg"}
            alt="avatar"
            class="object-cover w-full h-full"
          />
        </div>
        <div class="text-left">
          <p class="text-sm font-medium text-gray-900">{@current_user.name}</p>
          <p class="text-xs text-gray-500">{@current_user.email}</p>
        </div>
      </button>

      <%= if @show_dropdown do %>
        <div class="absolute right-0 z-50 mt-2 w-56 bg-white border border-gray-200 rounded-md shadow-lg">
          <div class="px-4 py-2 text-sm font-medium text-gray-900">
            My Account
          </div>
          <div class="border-t border-gray-200 my-1"></div>

          <.link href="/logout">
            <button class="w-full flex items-center px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 cursor-pointer">
              Log out
            </button>
          </.link>
        </div>
      <% end %>
    </div>
    """
  end

  def main_header(assigns) do
    ~H"""
    <header class="bg-white border-b border-gray-200">
      <div class="flex flex-col gap-4 px-4 py-4 md:flex-row md:items-center md:justify-between">
        
    <!-- Top row (title + avatar) -->
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="p-2 bg-green-100 rounded-lg">
              <.icon name="hero-chat-bubble-left-right" class="h-6 w-6 text-green-600" />
            </div>
            <div>
              <h1 class="text-lg md:text-xl font-semibold text-gray-900">Financial Advisor AI</h1>
              <p class="text-sm text-gray-600 hidden md:block">
                Intelligent Client Management Dashboard
              </p>
            </div>
          </div>
          
    <!-- Avatar shown only on mobile -->
          <div class="block md:hidden">
            <.profile_menu current_user={@current_user} show_dropdown={@show_dropdown} />
          </div>
        </div>
        
    <!-- Bottom row (button + avatar on desktop) -->
        <div class="flex justify-between items-center md:justify-end gap-2 md:gap-4">
          <.button
            phx-click={show_modal("my-modal")}
            class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 w-full md:w-auto"
          >
            <.icon name="hero-envelope" class="mr-2 h-5 w-5" /> Ask AI Assistant
          </.button>
          
    <!-- Avatar on desktop -->
          <div class="hidden md:block">
            <.profile_menu current_user={@current_user} show_dropdown={@show_dropdown} />
          </div>
        </div>
      </div>
    </header>
    """
  end
end
