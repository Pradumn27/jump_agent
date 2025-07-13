defmodule JumpAgent.Repo.Migrations.RenameIsActiveToIsActiveInWatchInstructions do
  use Ecto.Migration

  def change do
    rename table(:watch_instructions), :isActive, to: :is_active
  end
end
