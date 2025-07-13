defmodule JumpAgent.Automations.WatchEngine do
  @moduledoc """
  Handles dynamic WatchInstructions triggered by Gmail, Calendar, or HubSpot.
  Each instruction is interpreted by GPT in real-time.
  """

  alias JumpAgent.Automations.TriggerHandlers
  alias JumpAgent.WatchInstructions

  use Oban.Worker, queue: :default, max_attempts: 1

  @interval_minutes 5

  def perform(_job) do
    now = DateTime.utc_now()
    cutoff = DateTime.add(now, -@interval_minutes * 60, :second)
    IO.inspect("Cutoff: #{inspect(cutoff)}")

    WatchInstructions.get_due_instructions(cutoff)
    |> Enum.each(fn instruction ->
      TriggerHandlers.process_trigger(instruction.trigger, instruction.instruction)
    end)

    :ok
  end
end
