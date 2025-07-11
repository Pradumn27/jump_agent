defmodule JumpAgentWeb.ChatLive do
  use JumpAgentWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:current_message, "")
     |> assign(:is_thinking, false)
     |> assign(:message_id_counter, 0)
     |> assign(:current_tab, "chat")}
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :current_message, message)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    now = NaiveDateTime.utc_now()
    # capture LiveView process PID
    caller = self()

    spawn(fn ->
      case JumpAgent.OpenAI.chat_completion(message) do
        {:ok, reply} ->
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
           %{role: "ai", content: "", timestamp: now}
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
     |> assign(:current_message, "")
     |> assign(:is_thinking, false)
     |> assign(:message_id_counter, 0)}
  end

  @impl true
  def handle_event("open_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: true)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, current_tab: tab)}
  end

  @impl true
  def handle_info({:ai_response, reply}, socket) do
    updated_messages =
      List.update_at(socket.assigns.messages, -1, fn msg ->
        if msg.role == "ai" or msg.role == :ai do
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
  def handle_info(:generate_response, socket) do
    # Simulate AI response
    ai_response = generate_ai_response(socket.assigns.messages)

    ai_message = %{
      id: socket.assigns.message_id_counter,
      role: "assistant",
      content: ai_response,
      timestamp: DateTime.utc_now()
    }

    messages = socket.assigns.messages ++ [ai_message]

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:is_thinking, false)
     |> assign(:message_id_counter, socket.assigns.message_id_counter + 1)}
  end

  @impl true
  def handle_info({:stream_chunk, chunk}, socket) do
    updated_messages =
      List.update_at(socket.assigns.messages, -1, fn msg ->
        if msg.role == :ai do
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
         if msg.role == :ai do
           %{msg | content: "⚠️ Error: #{inspect(reason)}"}
         else
           msg
         end
       end)
     end)}
  end

  defp generate_ai_response(messages) do
    # Simple AI response simulation
    responses = [
      "That's an interesting question! Let me think about that...",
      "I understand what you're asking. Here's my perspective on that topic.",
      "Great question! Based on what you've shared, I think...",
      "Thanks for sharing that with me. I'd be happy to help you with this.",
      "That's a thoughtful observation. Let me provide some insights.",
      "I can see why you'd want to know about that. Here's what I think...",
      "Excellent point! This is something I've been thinking about too.",
      "That's a complex topic, but I'll do my best to explain it clearly."
    ]

    base_response = Enum.random(responses)

    # Add some context based on recent messages
    recent_message = List.last(messages)

    if recent_message &&
         String.contains?(String.downcase(recent_message.content), ["code", "programming"]) do
      base_response <>
        " When it comes to programming, I always recommend starting with the fundamentals and building up from there. Would you like me to elaborate on any specific aspect?"
    else
      base_response <>
        " I'm here to help with any questions you might have. Feel free to ask me anything!"
    end
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
    <div class="flex h-full relative flex-col overflow-auto">
      <div class="flex-1 overflow-auto px-4 py-6 space-y-6">
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
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col bg-white p-4">
      <.button phx-click={show_modal("my-modal")}>Open Modal</.button>
      <.modal id="my-modal" on_cancel={JS.push("close_modal")} show={true}>
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
              <.chat_history />
            <% end %>
          </div>
        </div>
      </.modal>
    </div>
    """
  end
end
