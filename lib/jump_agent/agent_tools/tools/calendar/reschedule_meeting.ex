defmodule JumpAgent.Tools.Calendar.RescheduleMeeting do
  def spec do
    %{
      type: "function",
      function: %{
        name: "reschedule_meeting",
        description:
          "Reschedules an existing Google Calendar event by updating its start and end time.",
        parameters: %{
          type: "object",
          properties: %{
            event_id: %{type: "string", description: "The ID of the event to reschedule"},
            new_start_time: %{type: "string", description: "New start time in ISO8601 format"},
            new_end_time: %{type: "string", description: "New end time in ISO8601 format"}
          },
          required: ["event_id", "new_start_time", "new_end_time"]
        }
      }
    }
  end

  def run(user, %{
        "event_id" => event_id,
        "new_start_time" => new_start_time,
        "new_end_time" => new_end_time
      }) do
    case JumpAgent.Integrations.Calendar.reschedule_meeting(
           user,
           event_id,
           new_start_time,
           new_end_time
         ) do
      {:ok, _event} ->
        "✅ Meeting #{event_id} has been rescheduled to start at #{new_start_time}"

      {:error, reason} ->
        "❌ Failed to reschedule meeting: #{inspect(reason)}"
    end
  end
end
