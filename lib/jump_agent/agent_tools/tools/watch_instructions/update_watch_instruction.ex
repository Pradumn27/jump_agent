defmodule JumpAgent.Tools.WatchInstructions.UpdateWatchInstruction do
  alias JumpAgent.Repo
  alias JumpAgent.Automations.WatchInstruction

  def spec do
    %{
      type: "function",
      function: %{
        name: "update_watch_instruction",
        description:
          "Update an existing WatchInstruction's trigger, filter, instruction or frequency",
        parameters: %{
          type: :object,
          properties: %{
            id: %{type: :integer, description: "The ID of the WatchInstruction to update"},
            trigger: %{type: :string, description: "The updated trigger (optional)"},
            instruction: %{type: :string, description: "The updated instruction (optional)"},
            frequency: %{
              type: :string,
              enum: ["once", "always"],
              description: "The updated frequency (optional)"
            }
          },
          required: ["id"]
        }
      }
    }
  end

  def run(user, %{"id" => id} = attrs) do
    with %WatchInstruction{} = instruction <-
           Repo.get_by(WatchInstruction, id: id, user_id: user.id),
         {:ok, updated} <-
           JumpAgent.WatchInstructions.do_update(instruction, Map.drop(attrs, ["id"])) do
      {:ok, "Updated WatchInstruction ##{updated.id} successfully"}
    else
      nil -> {:error, "WatchInstruction not found"}
      {:error, changeset} -> {:error, inspect(changeset.errors)}
    end
  end
end
