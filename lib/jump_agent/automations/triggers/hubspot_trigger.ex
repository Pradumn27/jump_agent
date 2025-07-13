defmodule JumpAgent.Automations.Triggers.HubspotTrigger do
  def handle(%{instruction: instruction_text} = instruction) do
    case Regex.run(~r/create a new note with the following content: (.*)/, instruction_text) do
      [_, content] ->
        {:ok, content}

      _ ->
        {:error, "Failed to parse instruction"}
    end
  end
end
