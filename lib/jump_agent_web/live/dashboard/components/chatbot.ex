defmodule JumpAgentWeb.Dashboard.Components.Chatbot do
  use Phoenix.LiveComponent
  import JumpAgentWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]
  alias Phoenix.LiveView.JS

  require Logger

  def user_input(assigns) do
    ~H"""
    <div>
      <form phx-submit="send_message" class="relative w-full">
        <.input
          type="text"
          name="message"
          value={@current_message}
          id="chat-input"
          phx-mounted={JS.focus()}
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

  def empty_message_state(assigns) do
    ~H"""
    <%= if @messages == [] do %>
      <div class="w-full h-full flex flex-col items-center justify-center text-center text-gray-700 px-4 py-12 space-y-4">
        <div class="bg-green-100 text-green-700 rounded-full p-3">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-8 w-8"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M8 10h.01M12 14h.01M16 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
        </div>
        <div>
          <h2 class="text-2xl font-semibold">Hello, I'm your AI Assistant</h2>
          <p class="mt-1 text-gray-500 text-base">
            I can help you draft emails, find client insights, summarize notes, and more.
          </p>
          <p class="text-gray-400 text-sm mt-2">Try asking something like:</p>
          <div class="text-sm text-gray-600 italic mt-1">
            “Summarize my latest client meeting”<br /> “Draft a follow-up email for Rajiv”<br />
            “What are my tasks for today?”
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def user_message(assigns) do
    ~H"""
    <div class="w-full flex justify-end">
      <div class="max-w-[80%] p-4 bg-gray-100 rounded-lg">
        {@content}
      </div>
    </div>
    """
  end

  def agent_message(assigns) do
    ~H"""
    <div class="w-full max-w-full p-4 rounded-lg prose prose-invert overflow-x-auto">
      {raw(Earmark.as_html!(@content))}
    </div>
    """
  end

  def chat_history(assigns) do
    ~H"""
    <div class="p-4 space-y-4 overflow-scroll">
      <%= if @chat_sessions == [] do %>
        <div class="text-gray-500">No previous chats</div>
      <% else %>
        <ul class="divide-y divide-gray-200">
          <%= for session <- @chat_sessions do %>
            <li class="py-2 flex items-center">
              <button
                phx-click="select_session"
                phx-value-id={session.id}
                class={"text-left flex-1 w-full hover:bg-gray-100 px-2 py-1 rounded-lg #{session.id == @chat_session_id && "bg-gray-100"}"}
              >
                <div class="text-sm font-medium">
                  {session.title || "Chat #{session.id}"}
                </div>
              </button>
              <button phx-click="delete_session" phx-value-id={session.id} class="ml-1 p-1">
                <.icon name="hero-trash" class="h-5 w-5 text-gray-400 hover:text-red-500" />
              </button>
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

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

  def chatbot(assigns) do
    ~H"""
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
    """
  end
end
