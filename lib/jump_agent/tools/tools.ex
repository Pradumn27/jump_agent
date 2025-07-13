defmodule JumpAgent.Tools do
  alias JumpAgent.Integrations.Gmail
  require Logger

  def send_email(user, %{"to" => to, "subject" => subject, "body" => body}) do
    case Gmail.send_email(user, to, subject, body) do
      :ok ->
        "✅ Email sent successfully to #{to}"

      {:error, reason} ->
        Logger.error("❌ Gmail API error while sending email: #{inspect(reason)}")
        "❌ Failed to send email to #{to}: #{inspect(reason)}"
    end
  end

  def move_email(user, %{"message_id" => msg_id, "label_id" => label_id}) do
    case JumpAgent.Integrations.Gmail.move_email(user, msg_id, label_id) do
      {:ok, _resp} -> "Email moved to label #{label_id}."
      {:error, reason} -> "Failed to move email: #{inspect(reason)}"
    end
  end

  def get_tools() do
    [
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
      },
      %{
        type: "function",
        function: %{
          name: "move_email",
          description: "Move an email to a different Gmail label",
          parameters: %{
            type: "object",
            properties: %{
              message_id: %{type: "string", description: "The Gmail message ID"},
              label_id: %{type: "string", description: "The Gmail label ID to move the email to"}
            },
            required: ["message_id", "label_id"]
          }
        }
      }
    ]
  end

  def dispatch_tool("send_email", user, args) do
    send_email(user, args)
  end

  def dispatch_tool("move_email", user, args) do
    move_email(user, args)
  end

  def dispatch_tool(tool_name, _args, _user) do
    "Unknown tool called: #{tool_name}"
  end
end
