defmodule JumpAgent.Automations.Triggers.CalendarTrigger do
  alias JumpAgent.Automations.WatchInstruction

  def handle(%WatchInstruction{} = watch_instruction) do
    user = watch_instruction.user
    prompt = watch_instruction.instruction
    last_executed_at = watch_instruction.last_executed_at || DateTime.utc_now()

    JumpAgent.Integrations.Calendar.sync_upcoming_events(user, 5)

    case JumpAgent.OpenAI.chat_completion_for_triggers(prompt, user, last_executed_at) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
