defmodule JumpAgent.Tools.Email.ReplyToEmail do
  require Logger

  def spec do
    %{
      type: "function",
      function: %{
        name: "reply_to_email",
        description: "Reply to an existing email thread in Gmail.",
        parameters: %{
          type: :object,
          properties: %{
            thread_id: %{type: :string, description: "Gmail thread ID of the original email"},
            to: %{type: :string, description: "Email address of the recipient"},
            subject: %{type: :string, description: "Subject of the reply"},
            message: %{type: :string, description: "The body of the reply email"}
          },
          required: ["thread_id", "to", "subject", "message"]
        }
      }
    }
  end

  def run(user, %{
        "thread_id" => thread_id,
        "to" => to,
        "subject" => subject,
        "message" => message
      }) do
    with {:ok, token} <- JumpAgent.Integrations.Gmail.get_google_token(user) do
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
