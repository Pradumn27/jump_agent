defmodule JumpAgent.Tools.WatchInstructions.CreateWatchInstruction do
  @moduledoc """
  Allows the assistant to create a watch instruction for automating workflows based on triggers like Gmail, Calendar, or HubSpot events.
  """

  alias JumpAgent.Automations.WatchInstruction
  alias JumpAgent.Repo

  def spec do
    %{
      type: "function",
      function: %{
        name: "create_watch_instruction",
        description: """
        Create a watch instruction to automate tasks based on a trigger.
        This tells the system to monitor a specific type of event ("gmail", "calendar", "hubspot") and run the given instruction when it happens.
        Use this to register automation rules (watch instructions) that define what should happen when a specific trigger (gmail, calendar, hubspot) occurs. These instructions are not executed now but saved for future use.
        """,
        parameters: %{
          type: "object",
          properties: %{
            trigger: %{
              type: "string",
              enum: ["gmail", "calendar", "hubspot"],
              description:
                "The type of trigger for the automation. One of: 'gmail', 'calendar', 'hubspot'"
            },
            instruction: %{
              type: "string",
              description:
                "The instruction to execute when the trigger fires. This will be interpreted and executed by the AI."
            },
            frequency: %{
              type: "string",
              enum: ["once", "always"],
              description:
                "Whether this instruction should execute only once or every time the condition is met."
            }
          },
          required: ["trigger", "instruction", "frequency"]
        }
      }
    }
  end

  @doc """
  Creates a watch instruction. Triggers can be one of:
  - "gmail": For email-based triggers
  - "calendar": For calendar events
  - "hubspot": For HubSpot contact or note events

  Frequency options:
  - "once": Execute the instruction only once
  - "always": Execute it every time the condition is met
  """
  def run(
        user,
        %{
          "trigger" => trigger,
          "instruction" => instruction,
          "frequency" => frequency
        } = _attrs
      ) do
    valid_triggers = ["gmail", "calendar", "hubspot"]
    valid_freqs = ["once", "always"]

    cond do
      trigger not in valid_triggers ->
        {:error, "Invalid trigger. Must be one of: #{Enum.join(valid_triggers, ", ")}"}

      frequency not in valid_freqs ->
        {:error, "Invalid frequency. Must be one of: #{Enum.join(valid_freqs, ", ")}"}

      true ->
        %WatchInstruction{}
        |> WatchInstruction.changeset(%{
          trigger: trigger,
          instruction: instruction,
          user_id: user.id,
          frequency: frequency
        })
        |> Repo.insert()
    end
  end
end
