defmodule JumpAgentWeb.Dashboard.Components.OngoingInstructions do
  use Phoenix.LiveComponent
  import JumpAgentWeb.CoreComponents

  @impl true
  def handle_event("toggle_instruction", %{"id" => id}, socket) do
    id = String.to_integer(id)

    updated_instructions =
      Enum.map(socket.assigns.ongoing_instructions, fn instruction ->
        if instruction["id"] == id do
          Map.put(instruction, "active", !instruction["active"])
        else
          instruction
        end
      end)

    {:noreply, assign(socket, :ongoing_instructions, updated_instructions)}
  end

  def switch(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div
        phx-click="toggle_instruction"
        phx-value-id={@id}
        class={[
          "peer inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full border-2 transition-colors duration-200",
          @checked && "bg-green-100",
          !@checked && "bg-gray-100",
          "focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
        ]}
        role="switch"
        aria-checked={@checked}
        tabindex="0"
      >
        <span class={[
          "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow-lg ring-0 transition duration-200",
          @checked && "translate-x-5",
          !@checked && "translate-x-0"
        ]} />
      </div>
    </div>
    """
  end

  def ongoing_instructions(assigns) do
    ~H"""
    <div class="rounded-lg border bg-white text-card-foreground shadow-sm border-gray-200">
      <div class="flex flex-col space-y-1.5 p-6">
        <div class="flex items-center justify-between">
          <div>
            <div class="font-semibold leading-none tracking-tight text-lg text-gray-900 flex items-center">
              <.icon name="hero-bolt" class="mr-2 h-5 w-5" /> Ongoing Instructions
            </div>
            <div class="text-sm mt-2 text-muted-foreground text-gray-600">
              Automated rules that guide your AI assistant's behavior
            </div>
          </div>
          <button
            phx-click={show_modal("my-modal")}
            class="bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded-md"
          >
            New Automation
          </button>
        </div>
      </div>

      <div class="p-6 pt-0">
        <%= if @ongoing_instructions == [] do %>
          <div class="flex flex-col items-center justify-center text-center text-gray-500 py-12">
            <.icon name="hero-light-bulb" class="w-10 h-10 mb-4 text-yellow-400" />
            <h2 class="text-lg font-semibold text-gray-700">No Automations Yet</h2>
            <p class="mt-2 max-w-md text-sm">
              Automations let the AI monitor your Gmail, Calendar, and HubSpot to act on your behalf — like replying to emails, scheduling meetings, or updating contacts.
            </p>
            <p class="mt-2 text-sm">
              Click “+ New Automation” to create your first Watch Instruction.
            </p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for instruction <- @ongoing_instructions do %>
              <div class="p-4 rounded-lg border border-gray-200 bg-gray-50">
                <div class="flex items-start justify-between mb-3">
                  <p class="text-sm text-gray-900 font-medium flex-1 pr-2">
                    {instruction.instruction}
                  </p>
                  <.switch checked={instruction.is_active} id={instruction.id} />
                </div>
                <%= if instruction.last_executed_at do %>
                  <p class="text-xs text-gray-500">
                    Last executed at: {Calendar.strftime(
                      instruction.last_executed_at,
                      "%a, %b %d, %Y at %I:%M %p"
                    )} UTC
                  </p>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
