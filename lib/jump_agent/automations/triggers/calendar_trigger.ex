defmodule JumpAgent.Automations.Triggers.CalendarTrigger do
  alias JumpAgent.Automations.WatchInstruction

  def handle(%WatchInstruction{} = watch_instruction) do
    user = watch_instruction.user
    prompt = watch_instruction.instruction

    # TODO: Conditionally Trigger based on whether new info is there or not - also sync

    case JumpAgent.OpenAI.chat_completion_for_triggers(prompt, user) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
