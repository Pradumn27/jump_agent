defmodule JumpAgent.Automations.Triggers.CalendarTrigger do
  def handle(%{instruction: instruction_text} = instruction) do
    case Regex.run(~r/free slot in (.*)/, instruction_text) do
      [_, summary] ->
        {:ok, summary}

      _ ->
        {:error, "Failed to parse instruction"}
    end
  end
end
