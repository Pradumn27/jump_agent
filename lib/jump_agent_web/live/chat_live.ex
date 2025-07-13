defmodule JumpAgentWeb.ChatLive do
  use JumpAgentWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    chat_sessions = JumpAgent.Chat.list_chat_sessions()

    integrations = JumpAgent.Integrations.get_integrations(socket.assigns.current_user)

    ongoing_instructions = [
      %{
        "id" => 1,
        "instruction" => "Instruction 1",
        "active" => true
      },
      %{
        "id" => 2,
        "instruction" => "Instruction 2",
        "active" => false
      }
    ]

    {:ok,
     socket
     |> assign(:chat_session_id, nil)
     |> assign(:chat_sessions, chat_sessions)
     |> assign(:messages, [])
     |> assign(:current_message, "")
     |> assign(:is_thinking, false)
     |> assign(:current_tab, "chat")
     |> assign(:show_dropdown, false)
     |> assign(:integrations, integrations)
     |> assign(:ongoing_instructions, ongoing_instructions)}
  end

  # Events

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :current_message, message)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    now = NaiveDateTime.utc_now()

    caller = self()

    {chat_session_id, socket} =
      case socket.assigns.chat_session_id do
        nil ->
          {:ok, session} =
            JumpAgent.Chat.create_chat_session(%{
              title: message,
              started_at: now,
              last_active_at: now,
              user_id: socket.assigns.current_user.id
            })

          {session.id, assign(socket, :chat_session_id, session.id)}

        id ->
          {id, socket}
      end

    {:ok, _user_msg} =
      JumpAgent.Chat.create_message(%{
        role: "user",
        content: message,
        timestamp: now,
        chat_session_id: chat_session_id
      })

    spawn(fn ->
      case JumpAgent.OpenAI.chat_completion(message, socket.assigns.current_user, chat_session_id) do
        {:ok, reply} ->
          JumpAgent.Chat.create_message(%{
            role: "assistant",
            content: reply,
            timestamp: NaiveDateTime.utc_now(),
            chat_session_id: chat_session_id
          })

          send(caller, {:ai_response, reply})

        {:error, reason} ->
          send(caller, {:ai_response, "⚠️ Error: #{inspect(reason)}"})
      end
    end)

    {:noreply,
     socket
     |> assign(:loading, true)
     |> assign(:is_thinking, true)
     |> update(:messages, fn msgs ->
       msgs ++
         [
           %{role: "user", content: message, timestamp: now},
           %{role: "assistant", content: "", timestamp: now}
         ]
     end)
     |> assign(:current_message, "")}
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_chat", _params, socket) do
    {:noreply,
     socket
     |> assign(:messages, [])
     |> assign(:chat_session_id, nil)
     |> assign(:current_message, "")
     |> assign(:is_thinking, false)}
  end

  @impl true
  def handle_event("open_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => "chat"}, socket) do
    {:noreply, assign(socket, current_tab: "chat")}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => "history"}, socket) do
    chat_sessions = JumpAgent.Chat.list_chat_sessions()
    {:noreply, assign(socket, current_tab: "history", chat_sessions: chat_sessions)}
  end

  @impl true
  def handle_event("load_chat_session", %{"id" => session_id}, socket) do
    session = JumpAgent.Chat.get_chat_session!(session_id)

    messages =
      Enum.map(session.messages, fn msg ->
        %{
          role: msg.role,
          content: msg.content,
          timestamp: msg.timestamp
        }
      end)

    {:noreply,
     socket
     |> assign(:chat_session, session)
     |> assign(:messages, messages)
     |> assign(:current_tab, "chat")}
  end

  @impl true
  def handle_event("select_session", %{"id" => id}, socket) do
    session_id = String.to_integer(id)

    messages =
      JumpAgent.Chat.get_chat_session_with_messages!(session_id)
      |> Map.get(:messages)
      |> Enum.sort_by(& &1.inserted_at)

    {:noreply,
     socket
     |> assign(:chat_session_id, session_id)
     |> assign(:messages, messages)
     |> assign(:current_tab, "chat")}
  end

  @impl true
  def handle_event("sync_integration", %{"name" => "Google Calendar"}, socket) do
    user = socket.assigns.current_user

    case JumpAgent.Integrations.Calendar.sync_upcoming_events(user) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Calendar synced successfully.")}

      {:error, err} ->
        Logger.error("Calendar sync failed: #{inspect(err)}")
        {:noreply, put_flash(socket, :error, "Failed to sync Calendar.")}
    end
  end

  @impl true
  def handle_event("sync_integration", %{"name" => "Gmail"}, socket) do
    user = socket.assigns.current_user

    case JumpAgent.Integrations.Gmail.fetch_recent_emails(user) do
      {:error, err} ->
        Logger.error("Gmail sync failed: #{inspect(err)}")
        {:noreply, put_flash(socket, :error, "Failed to sync Gmail.")}

      _ ->
        {:noreply, put_flash(socket, :info, "Gmail synced successfully.")}
    end
  end

  @impl true
  def handle_event("sync_integration", %{"name" => "HubSpot"}, socket) do
    user = socket.assigns.current_user

    case JumpAgent.Integrations.Hubspot.sync_contacts(user) do
      {:ok, _} ->
        JumpAgent.Integrations.Hubspot.sync_notes(user)
        {:noreply, put_flash(socket, :info, "HubSpot synced successfully.")}

      {:error, err} ->
        {:noreply, put_flash(socket, :error, "Failed to sync HubSpot: #{inspect(err)}")}
    end
  end

  def handle_event("disconnect_integration", %{"name" => "HubSpot"}, socket) do
    case JumpAgent.Integrations.Hubspot.disconnect_hubspot(socket.assigns.current_user) do
      {:ok, _} ->
        integrations = JumpAgent.Integrations.get_integrations(socket.assigns.current_user)
        {:noreply, assign(socket, integrations: integrations)}

      {:error, reason} ->
        Logger.error("Failed to disconnect HubSpot: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    {:noreply, assign(socket, show_dropdown: &(!&1))}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, show_dropdown: false)}
  end

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

  @impl true
  def handle_info({:ai_response, reply}, socket) do
    updated_messages =
      List.update_at(socket.assigns.messages, -1, fn msg ->
        if msg.role == "assistant" or msg.role == :assistant do
          %{msg | content: reply}
        else
          msg
        end
      end)

    {:noreply,
     socket
     |> assign(messages: updated_messages, loading: false, is_thinking: false)}
  end

  @impl true
  def handle_info({:stream_chunk, chunk}, socket) do
    updated_messages =
      List.update_at(socket.assigns.messages, -1, fn msg ->
        if msg.role == :assistant do
          %{msg | content: msg.content <> chunk}
        else
          msg
        end
      end)

    {:noreply, assign(socket, :messages, updated_messages)}
  end

  @impl true
  def handle_info(:done, socket) do
    {:noreply, assign(socket, :loading, false)}
  end

  @impl true
  def handle_info({:error, reason}, socket) do
    Logger.error("OpenAI stream error: #{inspect(reason)}")

    {:noreply,
     socket
     |> assign(:loading, false)
     |> update(:messages, fn msgs ->
       List.update_at(msgs, -1, fn msg ->
         if msg.role == :assistant do
           %{msg | content: "⚠️ Error: #{inspect(reason)}"}
         else
           msg
         end
       end)
     end)}
  end

  # Components

  def user_input(assigns) do
    ~H"""
    <div>
      <form phx-submit="send_message" class="relative w-full">
        <input
          type="text"
          name="message"
          value={@current_message}
          phx-change="update_message"
          placeholder="Write your message"
          class="w-full px-4 py-3 pr-12 border border-gray-300 rounded-lg focus:outline-none focus:ring-1 focus:ring-gray-300 focus:border-gray-400 resize-none"
        />
        <button
          type="submit"
          disabled={@current_message == "" || @is_thinking}
          class={[
            "absolute right-2 top-1/2 transform -translate-y-1/2 w-8 h-8 rounded-full flex items-center justify-center transition-colors",
            if(@current_message == "" || @is_thinking,
              do: "bg-gray-200 text-gray-400 cursor-not-allowed",
              else: "bg-gray-800 text-white hover:bg-gray-700"
            )
          ]}
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"
            />
          </svg>
        </button>
      </form>
    </div>
    """
  end

  def thinking_indicator(assigns) do
    ~H"""
    <%= if @is_thinking do %>
      <div class="p-4 flex items-center space-x-2 max-w-max">
        <span class="text-gray-600 text-sm">Thinking</span>
        <div class="flex space-x-1">
          <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
          <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.1s">
          </div>
          <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s">
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @spec user_message(any()) :: Phoenix.LiveView.Rendered.t()
  def user_message(assigns) do
    ~H"""
    <div class="w-full flex justify-end">
      <div class="p-4 bg-gray-100 rounded-lg">
        {@content}
      </div>
    </div>
    """
  end

  def agent_message(assigns) do
    ~H"""
    <div class="w-full p-4 rounded-lg prose max-w-none prose-invert">
      {raw(Earmark.as_html!(@content))}
    </div>
    """
  end

  def empty_message_state(assigns) do
    ~H"""
    <%= if @messages == [] do %>
      <div class="w-full h-full flex flex-col text-xl font-semibold justify-center items-center">
        <div>Hi, I am your AI Helper</div>
        <div>Ask anything that comes to your mind</div>
      </div>
    <% end %>
    """
  end

  @spec chat_component(any()) :: Phoenix.LiveView.Rendered.t()
  def chat_component(assigns) do
    ~H"""
    <div class="flex h-full relative flex-col overflow-auto">
      <div id="chat-scroll" phx-hook="ScrollBottom" class="flex-1 overflow-auto px-4 py-6 space-y-6">
        <%= for message <- @messages do %>
          <%= if message.role == "user" do %>
            <.user_message content={message.content} />
          <% else %>
            <.agent_message content={message.content} />
          <% end %>
        <% end %>
        <.empty_message_state messages={@messages} />
        <.thinking_indicator is_thinking={@is_thinking} />
      </div>

      <.user_input current_message={@current_message} is_thinking={@is_thinking} />
    </div>
    """
  end

  def chat_header(assigns) do
    ~H"""
    <header class="border-b border-gray-200 p-4">
      <div class="flex justify-between items-center">
        <div class="flex items-center space-x-3">
          <h1 class="text-xl font-medium">Ask Anything</h1>
        </div>
        <button
          phx-click={JS.exec("data-cancel", to: "#my-modal")}
          type="button"
          class="hover:opacity-40"
          aria-label={gettext("close")}
        >
          <.icon name="hero-x-mark-solid" class="h-5 w-5" />
        </button>
      </div>
      <div class="flex justify-between items-center mt-2">
        <div id="tabs" class="flex gap-2">
          <button
            phx-click={JS.push("change_tab", value: %{tab: "chat"})}
            title="Chat"
            class={"p-2 rounded-lg hover:bg-gray-100 #{ @current_tab === "chat" && "bg-gray-100 font-medium"}"}
          >
            Chat
          </button>
          <button
            phx-click={JS.push("change_tab", value: %{tab: "history"})}
            title="History"
            class={"p-2 rounded-lg hover:bg-gray-100 #{ @current_tab === "history" && "bg-gray-100 font-medium"}"}
          >
            History
          </button>
        </div>
        <button
          phx-click="clear_chat"
          class="hover:bg-gray-100 rounded-lg transition-colors flex items-center justify-center gap-1 p-1"
          title="New chat"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 6v6m0 0v6m0-6h6m-6 0H6"
            />
          </svg>
          <div>New Thread</div>
        </button>
      </div>
    </header>
    """
  end

  def chat_history(assigns) do
    ~H"""
    <div class="p-4 space-y-4">
      <%= if @chat_sessions == [] do %>
        <div class="text-gray-500">No previous chats</div>
      <% else %>
        <ul class="divide-y divide-gray-200">
          <%= for session <- @chat_sessions do %>
            <li class="py-2">
              <button
                phx-click="select_session"
                phx-value-id={session.id}
                class={"text-left w-full hover:bg-gray-100 px-2 py-1 rounded-lg #{session.id == @chat_session_id && "bg-gray-100"}"}
              >
                <div class="text-sm font-medium">
                  {session.title || "Chat #{session.id}"}
                </div>
              </button>
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  def main_header(assigns) do
    ~H"""
    <header class="bg-white border-b border-gray-200">
      <div class="flex items-center justify-between px-6 py-4">
        <div class="flex items-center space-x-3">
          <div class="p-2 bg-green-100 rounded-lg">
            <.icon name="hero-chat-bubble-left-right" class="h-6 w-6 text-green-600" />
          </div>
          <div>
            <h1 class="text-xl font-semibold text-gray-900">Financial Advisor AI</h1>
            <p class="text-sm text-gray-600">Intelligent Client Management Dashboard</p>
          </div>
        </div>
        <div class="flex items-center space-x-4">
          <.button
            phx-click={show_modal("my-modal")}
            class="bg-green-600 hover:bg-green-700 text-white px-6"
          >
            <.icon name="hero-envelope" class="mr-2 h-5 w-5" /> Ask AI Assistant
          </.button>
          <.profile_menu current_user={@current_user} show_dropdown={@show_dropdown} />
        </div>
      </div>
    </header>
    """
  end

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
            <button
              class="w-full flex items-center px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 cursor-pointer"
              phx-click="logout"
            >
              Log out
            </button>
          </.link>
        </div>
      <% end %>
    </div>
    """
  end

  def integrations(assigns) do
    ~H"""
    <div class="rounded-lg border bg-card text-card-foreground shadow-sm border border-gray-200 shadow-sm">
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
    <div class="rounded-lg border bg-card text-card-foreground shadow-sm border-gray-200">
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
            Add Instruction
          </button>
        </div>
      </div>

      <div class="p-6 pt-0">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <%= for instruction <- @ongoing_instructions do %>
            <div class="p-4 rounded-lg border border-gray-200 bg-gray-50">
              <div class="flex items-start justify-between mb-3">
                <p class="text-sm text-gray-900 flex-1 pr-2">
                  {instruction["instruction"]}
                </p>
                <.switch
                  id={"instruction-#{instruction["id"]}"}
                  checked={instruction["active"]}
                  id={instruction["id"]}
                />
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gray-50 min-h-screen">
      <.main_header current_user={@current_user} show_dropdown={@show_dropdown} />
      <div class="p-6 space-y-6">
        <div class="max-w-7xl mx-auto">
          <div class="space-y-6">
            <.integrations integrations={@integrations} />
            <.ongoing_instructions ongoing_instructions={@ongoing_instructions} />
          </div>
        </div>
      </div>
      <.modal id="my-modal" on_cancel={JS.push("close_modal")}>
        <div class="h-[90vh] w-full overflow-auto">
          <div class="flex flex-col overflow-hidden h-[90vh]">
            <.chat_header current_tab={@current_tab} />
            <%= if @current_tab == "chat" do %>
              <.chat_component
                messages={@messages}
                is_thinking={@is_thinking}
                current_message={@current_message}
              />
            <% else %>
              <.chat_history chat_sessions={@chat_sessions} chat_session_id={@chat_session_id} />
            <% end %>
          </div>
        </div>
      </.modal>
    </div>
    """
  end
end
