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

  def update_watch_instruction(%WatchInstruction{} = wi, attrs) do
    wi
    |> WatchInstruction.changeset(attrs)
    |> Repo.update()
  end

  def delete_watch_instruction(%WatchInstruction{} = wi) do
    Repo.delete(wi)
  end

  def change_watch_instruction(%WatchInstruction{} = wi, attrs \\ %{}) do
    WatchInstruction.changeset(wi, attrs)
  end

  def get_by_trigger(trigger) when is_binary(trigger) do
    from(wi in WatchInstruction,
      where: wi.trigger == ^trigger,
      join: u in assoc(wi, :user),
      preload: [user: u]
    )
    |> Repo.all()
  end
end
