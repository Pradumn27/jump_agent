defmodule JumpAgent.Automations.Triggers.HubspotTrigger do
  alias JumpAgent.Automations.WatchInstruction
  require Logger

  def handle(%WatchInstruction{} = watch_instruction) do
    user = watch_instruction.user
    prompt = watch_instruction.instruction
    last_executed_at = watch_instruction.last_executed_at || DateTime.utc_now()

    case JumpAgent.Integrations.Hubspot.sync_contacts(user, 10) do
      {:ok, _} ->
        JumpAgent.Integrations.Hubspot.sync_notes(user, 10)

      {:error, err} ->
        Logger.error("HubSpot sync failed: #{inspect(err)}")
    end

    # TODO: Conditionally Trigger based on whether new info is there or not

    case JumpAgent.OpenAI.chat_completion_for_triggers(prompt, user, last_executed_at) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
