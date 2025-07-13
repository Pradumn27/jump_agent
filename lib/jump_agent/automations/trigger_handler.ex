defmodule JumpAgent.Automations.TriggerHandlers do
  require Logger
  alias JumpAgent.Automations.Triggers.{GmailTrigger, CalendarTrigger, HubspotTrigger}

  def process_trigger(watch_instruction) do
    case handle(watch_instruction.trigger, watch_instruction.instruction) do
      :ok -> "Executed Instruction #{watch_instruction.instruction.id}"
      {:error, reason} -> Logger.error("Failed to execute: #{inspect(reason)}")
    end
  end

  def handle("gmail.new_email", instruction), do: GmailTrigger.handle(instruction)
  def handle("calendar.free_slot", instruction), do: CalendarTrigger.handle(instruction)
  def handle("hubspot.new_note", instruction), do: HubspotTrigger.handle(instruction)

  def handle(trigger, _) do
    {:error, "Unknown trigger #{trigger}"}
  end
end
