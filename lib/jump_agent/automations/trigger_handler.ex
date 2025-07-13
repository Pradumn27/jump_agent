defmodule JumpAgent.Automations.TriggerHandlers do
  require Logger
  alias JumpAgent.Automations.Triggers.{GmailTrigger, CalendarTrigger, HubspotTrigger}
  alias JumpAgent.WatchInstructions

  def process_trigger(watch_instruction) do
    case handle(watch_instruction.trigger, watch_instruction) do
      :ok ->
        Logger.info("✅ Executed WatchInstruction: #{watch_instruction.instruction}")

        # Mark as executed
        now = DateTime.utc_now()

        WatchInstructions.update_watch_instruction(watch_instruction, %{
          last_executed_at: now
        })

        :ok

      {:error, reason} ->
        Logger.error("❌ Failed to execute WatchInstruction: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle("gmail", watch_instruction), do: GmailTrigger.handle(watch_instruction)
  def handle("calendar", watch_instruction), do: CalendarTrigger.handle(watch_instruction)
  def handle("hubspot", watch_instruction), do: HubspotTrigger.handle(watch_instruction)

  def handle(trigger, _) do
    {:error, "Unknown trigger: #{trigger}"}
  end
end
