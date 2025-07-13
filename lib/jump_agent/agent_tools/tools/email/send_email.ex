defmodule JumpAgent.Tools.Email.SendEmail do
  alias JumpAgent.Integrations.Gmail
  require Logger

  def spec do
    %{
      type: "function",
      function: %{
        name: "send_email",
        description: "Send an email via Gmail on behalf of the user",
        parameters: %{
          type: "object",
          properties: %{
            to: %{type: "string", description: "Recipient email address"},
            subject: %{type: "string", description: "Subject of the email"},
            body: %{type: "string", description: "Body of the email"}
          },
          required: ["to", "subject", "body"]
        }
      }
    }
  end

  def run(user, %{"to" => to, "subject" => subject, "body" => body}) do
    case Gmail.send_email(user, to, subject, body) do
      :ok ->
        "✅ Email sent successfully to #{to}"

      {:error, reason} ->
        Logger.error("❌ Gmail API error while sending email: #{inspect(reason)}")
        "❌ Failed to send email to #{to}: #{inspect(reason)}"
    end
  end
end
