defmodule JumpAgent.Tools.Email.MoveEmail do
  def spec do
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
  end

  def run(user, %{"message_id" => msg_id, "label_id" => label_id}) do
    case JumpAgent.Integrations.Gmail.move_email(user, msg_id, label_id) do
      {:ok, _resp} -> "Email moved to label #{label_id}."
      {:error, reason} -> "Failed to move email: #{inspect(reason)}"
    end
  end
end
