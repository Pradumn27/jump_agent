defmodule JumpAgent.Tools.Calendar.CreateMeeting do
  require Logger

  def spec do
    %{
      type: "function",
      function: %{
        name: "create_meeting",
        description: "Creates a Google Calendar event/meeting for the user",
        parameters: %{
          type: "object",
          properties: %{
            summary: %{type: "string", description: "Title of the meeting"},
            description: %{type: "string", description: "Meeting description"},
            location: %{type: "string", description: "Where the meeting takes place"},
            start_time: %{type: "string", description: "Start time in ISO8601 format"},
            end_time: %{type: "string", description: "End time in ISO8601 format"},
            attendees: %{
              type: "array",
              items: %{type: "string"},
              description: "List of attendee email addresses"
            }
          },
          required: ["summary", "start_time", "end_time"]
        }
      }
    }
  end

  def run(user, args) do
    case JumpAgent.Integrations.Calendar.create_meeting(user, args) do
      {:ok, _message} ->
        "✅ Meeting created successfully"

      {:error, reason} ->
        Logger.error("❌ Calendar API error while creating meeting: #{inspect(reason)}")
        "❌ Failed to create meeting: #{inspect(reason)}"
    end
  end
end
