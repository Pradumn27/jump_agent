defmodule JumpAgentWeb.ChatLive do
  use JumpAgentWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    chat_sessions = JumpAgent.Chat.list_chat_sessions()

    {:ok,
     socket
     |> assign(:chat_session_id, nil)
     |> assign(:chat_sessions, chat_sessions)
     |> assign(:messages, [])
     |> assign(:current_message, "")
     |> assign(:is_thinking, false)
     |> assign(:current_tab, "chat")}
  end

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
      case JumpAgent.OpenAI.chat_completion(message, socket.assigns.current_user) do
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

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end

  def handle_event("change_tab", %{"tab" => "chat"}, socket) do
    {:noreply, assign(socket, current_tab: "chat")}
  end

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

  def handle_event("sync_gmail", _params, socket) do
    user = socket.assigns.current_user

    case JumpAgent.Integrations.Gmail.fetch_recent_emails(user) do
      {:error, err} ->
        Logger.error("Gmail sync failed: #{inspect(err)}")
        {:noreply, put_flash(socket, :error, "Failed to sync Gmail.")}

      _ ->
        {:noreply, put_flash(socket, :info, "Gmail synced successfully.")}
    end
  end

  def handle_event("sync_calendar", _params, socket) do
    user = socket.assigns.current_user

    case JumpAgent.Integrations.Calendar.sync_upcoming_events(user) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Calendar synced successfully.")}

      {:error, err} ->
        Logger.error("Calendar sync failed: #{inspect(err)}")
        {:noreply, put_flash(socket, :error, "Failed to sync Calendar.")}
    end
  end

  def handle_event("sync_hubspot", _params, socket) do
    user = socket.assigns.current_user

    case JumpAgent.Integrations.Hubspot.sync_contacts(user) do
      {:ok, _} ->
        JumpAgent.Integrations.Hubspot.sync_notes(user)
        {:noreply, put_flash(socket, :info, "HubSpot synced successfully.")}

      {:error, err} ->
        {:noreply, put_flash(socket, :error, "Failed to sync HubSpot: #{inspect(err)}")}
    end
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
    <div class="w-full p-4 rounded-lg">
      {@content}
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
    <div  class="flex h-full relative flex-col overflow-auto">
      <div id="chat-scroll" phx-hook="ScrollBottom"  class="flex-1 overflow-auto px-4 py-6 space-y-6">
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col bg-white p-4">
      <.button phx-click={show_modal("my-modal")}>Open Modal</.button>
      <button
        phx-click="sync_gmail"
        class="px-3 py-1 text-sm bg-blue-600 text-white rounded hover:bg-blue-700"
      >
        Sync Gmail
      </button>
      <button
        phx-click="sync_calendar"
        class="px-3 py-1 text-sm bg-green-600 text-white rounded hover:bg-green-700"
      >
       Sync Calendar
      </button>
       <button
        phx-click="sync_hubspot"
        class="px-3 py-1 text-sm bg-yellow-600 text-white rounded hover:bg-yellow-700"
      >
       Sync Hubspot
      </button>
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
