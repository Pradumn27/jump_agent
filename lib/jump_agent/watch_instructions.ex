defmodule JumpAgent.WatchInstructions do
  @moduledoc """
  Context for handling WatchInstructions.
  """

  import Ecto.Query, warn: false
  alias JumpAgent.Repo

  alias JumpAgent.Automations.WatchInstruction

  def list_watch_instructions(user) do
    Repo.all(from w in WatchInstruction, where: w.user_id == ^user.id)
  end

  def list_watch_instructions_by_trigger(user, trigger) do
    Repo.all(from w in WatchInstruction, where: w.user_id == ^user.id and w.trigger == ^trigger)
  end

  def get_watch_instruction!(id), do: Repo.get!(WatchInstruction, id)

  def create_watch_instruction(attrs) do
    %WatchInstruction{}
    |> WatchInstruction.changeset(attrs)
    |> Repo.insert()
  end

  def delete_watch_instruction(%WatchInstruction{} = wi) do
    Repo.delete(wi)
  end

  def change_watch_instruction(%WatchInstruction{} = wi, attrs \\ %{}) do
    WatchInstruction.changeset(wi, attrs)
  end

  def get_due_instructions(cutoff_dt) do
    from(w in WatchInstruction,
      where: w.is_active == true,
      where:
        (is_nil(w.last_executed_at) or w.last_executed_at < ^cutoff_dt) and
          (w.frequency != "once" or is_nil(w.last_executed_at)),
      preload: [:user]
    )
    |> Repo.all()
  end

  def update_watch_instruction(user, %{"id" => id} = attrs) do
    with %WatchInstruction{} = instruction <-
           Repo.get_by(WatchInstruction, id: id, user_id: user.id),
         {:ok, updated} <- do_update(instruction, Map.drop(attrs, ["id"])) do
      {:ok, "Updated WatchInstruction ##{updated.id} successfully"}
    else
      nil -> {:error, "WatchInstruction not found"}
      {:error, changeset} -> {:error, inspect(changeset.errors)}
    end
  end

  defp do_update(instruction, updates) do
    instruction
    |> WatchInstruction.changeset(updates)
    |> Repo.update()
  end
end
