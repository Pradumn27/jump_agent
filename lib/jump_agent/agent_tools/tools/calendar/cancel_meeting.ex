defmodule JumpAgent.Tools.Calendar.CancelMeeting do
  def spec do
    %{
      type: "function",
      function: %{
        name: "cancel_meeting",
        description: "Cancels (deletes) a Google Calendar event",
        parameters: %{
          type: "object",
          properties: %{
            event_id: %{
              type: "string",
              description: "The ID of the Google Calendar event to cancel"
            }
          },
          required: ["event_id"]
        }
      }
    }
  end

  def run(user, %{"event_id" => event_id}) do
    case JumpAgent.Integrations.Calendar.cancel_meeting(user, event_id) do
      :ok -> "✅ Meeting with ID #{event_id} has been cancelled."
      {:error, reason} -> "❌ Failed to cancel meeting: #{inspect(reason)}"
    end
  end
end
