defmodule JumpAgent.Integrations.Gmail do
  alias JumpAgent.Accounts
  alias JumpAgent.Knowledge
  alias GoogleApi.Gmail.V1.Api.Users
  alias GoogleApi.Gmail.V1.Connection

  def fetch_recent_emails(user, max_results \\ 10) do
    with {:ok, token} <- get_google_token(user),
         conn <- Connection.new(token),
         {:ok, %GoogleApi.Gmail.V1.Model.ListMessagesResponse{messages: messages}} <-
           Users.gmail_users_messages_list(conn, "me", [], maxResults: max_results) do
      messages
      |> Enum.map(& &1.id)
      |> Enum.map(&fetch_email(conn, &1))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, mail} -> parse_and_store(user, mail) end)
    else
      err -> {:error, err}
    end
  end

  defp fetch_email(conn, message_id) do
    Users.gmail_users_messages_get(conn, "me", message_id, format: "full")
  end

  defp parse_and_store(user, message) do
    subject =
      message.payload.headers
      |> Enum.find(fn h -> h.name == "Subject" end)
      |> Map.get(:value, "")

    snippet = message.snippet || ""

    content = """
    Subject: #{subject}
    Snippet: #{snippet}
    """

    Knowledge.create_context(%{
      source: "gmail",
      source_id: message.id,
      content: content,
      metadata: %{
        subject: subject,
        internal_date: message.internalDate,
        thread_id: message.threadId
      },
      user_id: user.id
    })
  end

  defp get_google_token(user) do
    user = Accounts.get_user!(user.id)

    case Accounts.get_user!(user.id) do
      %{token: token, refresh_token: refresh_token, expires_at: expires_at} ->
        if expired?(expires_at) do
          # Refresh the access token using the refresh token
          JumpAgent.OAuth.Google.refresh_token(refresh_token)
        else
          {:ok, token}
        end

      _ ->
        {:error, :no_google_auth}
    end
  end

  defp expired?(datetime) do
    DateTime.compare(datetime, DateTime.utc_now()) == :lt
  end
end
