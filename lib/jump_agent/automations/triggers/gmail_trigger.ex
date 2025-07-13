defmodule JumpAgent.Automations.Triggers.GmailTrigger do
  alias JumpAgent.Automations.WatchInstruction

  def handle(%WatchInstruction{} = watch_instruction) do
    user = watch_instruction.user
    prompt = watch_instruction.instruction
    last_executed_at = watch_instruction.last_executed_at || DateTime.utc_now()

    JumpAgent.Integrations.Gmail.fetch_recent_emails(user, 5)

    # TODO: Conditionally Trigger based on whether new info is there or not

    case JumpAgent.OpenAI.chat_completion_for_triggers(prompt, user, last_executed_at) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
