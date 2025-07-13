defmodule JumpAgent.Automations.WatchEngine do
  @moduledoc """
  Handles dynamic WatchInstructions triggered by Gmail, Calendar, or HubSpot.
  Each instruction is interpreted by GPT in real-time.
  """

  alias JumpAgent.Automations.TriggerHandlers
  alias JumpAgent.WatchInstructions
  require Logger

  use Oban.Worker, queue: :default, max_attempts: 1

  @interval_minutes 5

  def perform(_job) do
    now = DateTime.utc_now()
    cutoff = DateTime.add(now, -@interval_minutes * 60, :second)
    Logger.info("[WatchEngine] Running trigger evaluation at #{now}")

    WatchInstructions.get_due_instructions(cutoff)
    |> Enum.each(fn watch_instruction ->
      try do
        TriggerHandlers.process_trigger(watch_instruction)
      rescue
        e ->
          Logger.error(
            "[WatchEngine] Failed for instruction #{watch_instruction.id}: #{inspect(e)}"
          )
      end
    end)

    :ok
  end
end
