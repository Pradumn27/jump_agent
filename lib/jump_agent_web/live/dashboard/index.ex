defmodule JumpAgentWeb.DashboardLive do
  use JumpAgentWeb, :live_view

  require Logger

  import JumpAgentWeb.Dashboard.Components.{
    Chatbot,
    Header,
    Integrations,
    OngoingInstructions
  }

  @impl true
  def mount(_params, _session, socket) do
    chat_sessions = JumpAgent.Chat.list_chat_sessions(socket.assigns.current_user.id)

    integrations = JumpAgent.Integrations.get_integrations(socket.assigns.current_user)

    ongoing_instructions =
      JumpAgent.WatchInstructions.list_watch_instructions(socket.assigns.current_user)

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
    chat_sessions = JumpAgent.Chat.list_chat_sessions(socket.assigns.current_user.id)
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
  def handle_event("sync_integration", %{"name" => "Calendar"}, socket) do
    user = socket.assigns.current_user

    Task.start(fn ->
      try do
        case JumpAgent.Integrations.Calendar.sync_upcoming_events(user) do
          {:ok, _} ->
            Logger.info("Google Calendar synced successfully for user #{user.id}")

          {:error, err} ->
            Logger.error("Google Calendar sync failed for user #{user.id}: #{inspect(err)}")
        end
      rescue
        e -> Logger.error("Exception syncing Google Calendar for user #{user.id}: #{inspect(e)}")
      end
    end)

    {:noreply, put_flash(socket, :info, "Google Calendar sync started in background.")}
  end

  @impl true
  def handle_event("sync_integration", %{"name" => "Gmail"}, socket) do
    user = socket.assigns.current_user

    Task.start(fn ->
      try do
        case JumpAgent.Integrations.Gmail.fetch_recent_emails(user) do
          {:error, err} ->
            Logger.error("Gmail sync failed for user #{user.id}: #{inspect(err)}")

          _ ->
            Logger.info("Gmail synced successfully for user #{user.id}")
        end
      rescue
        e -> Logger.error("Exception during Gmail sync for user #{user.id}: #{inspect(e)}")
      end
    end)

    {:noreply, put_flash(socket, :info, "Gmail sync started in background.")}
  end

  @impl true
  def handle_event("sync_integration", %{"name" => "HubSpot"}, socket) do
    user = socket.assigns.current_user

    Task.start(fn ->
      try do
        case JumpAgent.Integrations.Hubspot.sync_contacts(user) do
          {:ok, _} ->
            JumpAgent.Integrations.Hubspot.sync_notes(user)
            Logger.info("HubSpot synced successfully for user #{user.id}")

          {:error, err} ->
            Logger.error("HubSpot sync failed for user #{user.id}: #{inspect(err)}")
        end
      rescue
        e -> Logger.error("Exception syncing HubSpot for user #{user.id}: #{inspect(e)}")
      end
    end)

    {:noreply, put_flash(socket, :info, "HubSpot sync started in background.")}
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

    watch_instruction = JumpAgent.WatchInstructions.get_watch_instruction!(id)

    JumpAgent.WatchInstructions.update_watch_instruction(watch_instruction, %{
      is_active: !JumpAgent.WatchInstructions.get_watch_instruction!(id).is_active
    })

    {:noreply,
     assign(
       socket,
       :ongoing_instructions,
       JumpAgent.WatchInstructions.list_watch_instructions(socket.assigns.current_user)
     )}
  end

  @impl true
  def handle_event("delete_session", %{"id" => id}, socket) do
    id = String.to_integer(id)
    JumpAgent.Chat.delete_chat_session(id)

    socket =
      if socket.assigns.chat_session_id == id do
        socket
        |> assign(:chat_session_id, nil)
        |> assign(:messages, [])
      else
        socket
      end

    {:noreply,
     assign(
       socket,
       :chat_sessions,
       JumpAgent.Chat.list_chat_sessions(socket.assigns.current_user.id)
     )}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gray-200 min-h-screen">
      <.main_header id="main-header" current_user={@current_user} show_dropdown={@show_dropdown} />
      <div class="p-6 space-y-6">
        <div class="max-w-7xl mx-auto">
          <div class="space-y-6">
            <.integrations
              id="integrations"
              integrations={@integrations}
              current_user={@current_user}
            />
            <.ongoing_instructions
              id="ongoing-instructions"
              ongoing_instructions={@ongoing_instructions}
            />
          </div>
        </div>
      </div>
      <.chatbot
        id="chat-bot"
        current_tab={@current_tab}
        messages={@messages}
        is_thinking={@is_thinking}
        current_message={@current_message}
        chat_sessions={@chat_sessions}
        chat_session_id={@chat_session_id}
      />
    </div>
    """
  end
end
