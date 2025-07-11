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
     |> assign(:message_id_counter, 0)}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col bg-gray-50 p-4">
      <%= if @messages == [] and not @is_thinking do %>
        <div class="flex-1 flex flex-col">
          <header class="flex justify-center py-6">
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-black rounded-full flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z" />
                </svg>
              </div>
              <h1 class="text-xl font-medium">AI Assistant</h1>
            </div>
          </header>

          <div class="flex-1 flex flex-col justify-center items-center px-4">
            <div class="max-w-2xl w-full text-center mb-8">
              <h2 class="text-3xl font-medium mb-8 text-gray-700">How can I help you today?</h2>
            </div>

            <div class="w-full max-w-2xl">
              <form phx-submit="send_message" class="relative">
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
                  disabled={@current_message == ""}
                  class={[
                    "absolute right-2 top-1/2 transform -translate-y-1/2 w-8 h-8 rounded-full flex items-center justify-center transition-colors",
                    if(@current_message == "",
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
          </div>
        </div>
      <% else %>
        <div class="flex flex-col h-full">
          <header class="flex justify-between items-center p-4 border-b border-gray-200">
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-black rounded-full flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z" />
                </svg>
              </div>
              <h1 class="text-xl font-medium">AI Assistant</h1>
            </div>
            <button
              phx-click="clear_chat"
              class="p-2 hover:bg-gray-100 rounded-lg transition-colors"
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
            </button>
          </header>

          <div class="flex-1 overflow-y-auto">
            <div class="max-w-3xl mx-auto px-4 py-6 space-y-6">
              <%= for message <- @messages do %>
                <div class="flex items-start space-x-4">
                  <!-- Avatar -->
                  <div class={[
                    "w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0",
                    if(message.role == "user", do: "bg-blue-500", else: "bg-green-500")
                  ]}>
                    <%= if message.role == "user" do %>
                      <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
                      </svg>
                    <% else %>
                      <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z" />
                      </svg>
                    <% end %>
                  </div>

                  <div class="flex-1 min-w-0">
                    <div class="flex items-center space-x-2 mb-1">
                      <span class="text-sm font-medium">
                        {if message.role == "user", do: "You", else: "ChatGPT"}
                      </span>
                      <span class="text-xs text-gray-500">
                        <%= if timestamp = Map.get(message, :timestamp) do %>
                          <span class="text-xs text-gray-500">
                            {Calendar.strftime(timestamp, "%I:%M %p")}
                          </span>
                        <% end %>
                      </span>
                    </div>
                    <div class="prose prose-sm max-w-none">
                      <p class="text-gray-800 leading-relaxed mb-0">{message.content}</p>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if @is_thinking do %>
                <div class="flex items-start space-x-4">
                  <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center flex-shrink-0">
                    <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.6069 1.4998-2.602-1.4998z" />
                    </svg>
                  </div>

                  <div class="flex-1">
                    <div class="bg-gray-100 rounded-lg p-4">
                      <div class="flex items-center space-x-2">
                        <span class="text-gray-600 text-sm">Thinking</span>
                        <div class="flex space-x-1">
                          <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
                          <div
                            class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"
                            style="animation-delay: 0.1s"
                          >
                          </div>
                          <div
                            class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"
                            style="animation-delay: 0.2s"
                          >
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <div class="w-full max-w-2xl">
                <form phx-submit="send_message" class="relative">
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
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
