defmodule JumpAgent.Integrations.Gmail do
  alias JumpAgent.Accounts
  alias JumpAgent.Knowledge
  alias GoogleApi.Gmail.V1.Api.Users
  alias GoogleApi.Gmail.V1.Connection
  require Logger

  def fetch_recent_emails(user, max_results \\ 500) do
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
    headers = message.payload.headers

    subject = get_header(headers, "Subject")
    from = get_header(headers, "From")
    to = get_header(headers, "To")
    internal_date = message.internalDate
    snippet = message.snippet || ""

    body = extract_body(message.payload)
    normalized_from_name = normalize_name(from)

    content = """
    Email from: #{from}
    Email to: #{to}
    Subject: #{subject}
    Message ID: #{message.id}
    Date: #{format_internal_date(internal_date)}

    Body:
    #{body}

    Snippet:
    #{snippet}
    """

    Knowledge.create_context(%{
      source: "gmail",
      source_id: message.id,
      content: content,
      metadata: %{
        from: from,
        to: to,
        subject: subject,
        thread_id: message.threadId,
        internal_date: internal_date,
        normalized_from_name: normalized_from_name,
        message_id: message.id
      },
      user_id: user.id
    })
  end

  defp get_header(headers, key) do
    headers
    |> Enum.find(fn h -> h.name == key end)
    |> case do
      nil -> ""
      header -> header.value
    end
  end

  # Main body extraction: tries text first, then HTML fallback
  defp extract_body(%{mimeType: "text/plain", body: body}) do
    decode_body(body)
  end

  defp extract_body(%{parts: parts}) when is_list(parts) do
    parts
    |> Enum.map(&extract_body/1)
    |> Enum.find(&(&1 != "")) || ""
  end

  defp extract_body(%{mimeType: "text/html", body: body}) do
    decode_body(body)
    |> strip_tags()
  end

  defp extract_body(_), do: ""

  defp decode_body(%{data: data}) when is_binary(data) do
    data
    |> String.replace("-", "+")
    |> String.replace("_", "/")
    |> Base.decode64(padding: false)
    |> case do
      {:ok, decoded} -> decoded
      _ -> ""
    end
  end

  defp decode_body(_), do: ""

  defp strip_tags(html) do
    html
    |> Floki.parse_document!()
    |> Floki.text(sep: "\n")
    |> String.trim()
  end

  defp format_internal_date(nil), do: "unknown"

  defp format_internal_date(ms) do
    ms
    |> String.to_integer()
    |> DateTime.from_unix!(:millisecond)
    |> DateTime.to_string()
  end

  defp normalize_name(nil), do: nil

  defp normalize_name(from_header) do
    regex = ~r/^(?<name>.+?)\s*<.+?>$/

    case Regex.named_captures(regex, from_header) do
      %{"name" => name} -> String.trim(name)
      _ -> from_header
    end
  end

  defp get_google_token(user) do
    case Accounts.get_user!(user.id) do
      %{token: token, refresh_token: refresh_token, expires_at: expires_at} ->
        if expired?(expires_at) do
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

  def send_email(user, to, subject, body) do
    refresh_token = user.refresh_token
    {:ok, access_token} = JumpAgent.OAuth.Google.refresh_token(refresh_token)

    raw =
      %{
        to: to,
        subject: subject,
        body: body
      }
      |> encode_mime()

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    payload =
      Jason.encode!(%{
        "raw" => Base.encode64(raw, padding: false)
      })

    HTTPoison.post(
      "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
      payload,
      headers
    )
    |> case do
      {:ok, %HTTPoison.Response{status_code: 200}} -> :ok
      error -> {:error, error}
    end
  end

  defp encode_mime(%{to: to, subject: subject, body: body}) do
    """
    To: #{to}
    Subject: #{subject}
    Content-Type: text/plain; charset="UTF-8"

    #{body}
    """
  end

  def move_email(user, message_id, add_label_id, remove_label_id \\ "INBOX") do
    with {:ok, token} <- get_google_token(user) do
      url = "https://gmail.googleapis.com/gmail/v1/users/me/messages/#{message_id}/modify"

      body =
        %{
          "addLabelIds" => List.wrap(add_label_id),
          "removeLabelIds" => List.wrap(remove_label_id)
        }
        |> Jason.encode!()

      headers = [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ]

      case HTTPoison.post(url, body, headers) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          {:ok, "Email moved successfully"}

        {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
          {:error, IO.inspect(body, label: "Gmail error")}

        {:error, reason} ->
          {:error, IO.inspect(reason, label: "Gmail error")}
      end
    end
  end

  def reply_to_email(user, %{
        "thread_id" => thread_id,
        "to" => to,
        "subject" => subject,
        "message" => message
      }) do
    with {:ok, token} <- get_google_token(user) do
      raw =
        encode_reply_mime(%{
          to: to,
          subject: subject,
          message: message,
          thread_id: thread_id
        })

      payload =
        Jason.encode!(%{
          "raw" => Base.encode64(raw, padding: false),
          "threadId" => thread_id
        })

      headers = [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ]

      url = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send"

      case HTTPoison.post(url, payload, headers) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          {:ok, "Email reply sent successfully."}

        {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
          Logger.error("Failed to reply to email: #{code} #{body}")
          {:error, "Failed to send reply"}

        {:error, reason} ->
          Logger.error("HTTP error in reply_to_email: #{inspect(reason)}")
          {:error, "HTTP error"}
      end
    end
  end

  defp encode_reply_mime(%{to: to, subject: subject, message: message, thread_id: thread_id}) do
    """
    To: #{to}
    Subject: Re: #{subject}
    In-Reply-To: #{thread_id}
    References: #{thread_id}
    Content-Type: text/plain; charset="UTF-8"

    #{message}
    """
  end
end
