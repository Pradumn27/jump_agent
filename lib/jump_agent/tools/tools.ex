defmodule JumpAgent.Tools do
  alias JumpAgent.Integrations.{Gmail, Calendar}
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

  def create_meeting(user, args) do
    case Calendar.create_meeting(user, args) do
      {:ok, _message} ->
        "✅ Meeting created successfully"

      {:error, reason} ->
        Logger.error("❌ Calendar API error while creating meeting: #{inspect(reason)}")
        "❌ Failed to create meeting: #{inspect(reason)}"
    end
  end

  def cancel_meeting(user, %{"event_id" => event_id}) do
    case JumpAgent.Integrations.Calendar.cancel_meeting(user, event_id) do
      :ok -> "✅ Meeting with ID #{event_id} has been cancelled."
      {:error, reason} -> "❌ Failed to cancel meeting: #{inspect(reason)}"
    end
  end

  def reschedule_meeting(user, %{
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
      },
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
      },
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
      },
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
      },
      %{
        type: "function",
        function: %{
          name: "create_contact",
          description: "Creates a contact in HubSpot CRM",
          parameters: %{
            type: "object",
            properties: %{
              email: %{type: "string", description: "Email address of the contact"},
              first_name: %{type: "string", description: "First name of the contact"},
              last_name: %{type: "string", description: "Last name of the contact"},
              phone: %{type: "string", description: "Phone number of the contact"}
            },
            required: ["email"]
          }
        }
      },
      %{
        type: "function",
        function: %{
          name: "update_contact",
          description: "Update an existing HubSpot contact",
          parameters: %{
            type: "object",
            properties: %{
              contact_id: %{type: "string", description: "The unique HubSpot contact ID"},
              email: %{type: "string", description: "Updated email address"},
              first_name: %{type: "string", description: "Updated first name"},
              last_name: %{type: "string", description: "Updated last name"},
              phone: %{type: "string", description: "Updated phone number"}
            },
            required: ["contact_id"]
          }
        }
      },
      %{
        type: "function",
        function: %{
          name: "create_note",
          description: "Create a note associated with a HubSpot contact",
          parameters: %{
            type: "object",
            properties: %{
              contact_id: %{
                type: "string",
                description: "HubSpot contact ID to attach the note to"
              },
              note: %{type: "string", description: "The note content to attach"}
            },
            required: ["contact_id", "note"]
          }
        }
      },
      %{
        type: "function",
        function: %{
          name: "update_hubspot_note",
          description: "Update a note in HubSpot by ID",
          parameters: %{
            type: "object",
            properties: %{
              note_id: %{type: "string", description: "The ID of the HubSpot note"},
              body: %{type: "string", description: "The new content of the note"}
            },
            required: ["note_id", "body"]
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

  def dispatch_tool("create_meeting", user, args) do
    create_meeting(user, args)
  end

  def dispatch_tool("cancel_meeting", user, args) do
    cancel_meeting(user, args)
  end

  def dispatch_tool("reschedule_meeting", user, args) do
    reschedule_meeting(user, args)
  end

  def dispatch_tool("create_contact", user, args) do
    JumpAgent.Integrations.Hubspot.create_contact(user, args)
  end

  def dispatch_tool("update_contact", user, args) do
    JumpAgent.Integrations.Hubspot.update_contact(user, args)
  end

  def dispatch_tool("create_note", user, args) do
    JumpAgent.Integrations.Hubspot.create_note(user, args)
  end

  def dispatch_tool("update_hubspot_note", user, args) do
    JumpAgent.Integrations.Hubspot.update_note(user, args)
  end

  def dispatch_tool(tool_name, _args, _user) do
    "Unknown tool called: #{tool_name}"
  end
end
