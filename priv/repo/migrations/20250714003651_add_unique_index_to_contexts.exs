defmodule JumpAgent.Repo.Migrations.AddUniqueIndexToContexts do
  use Ecto.Migration

  def change do
    create unique_index(:contexts, [:user_id, :source, :source_id])
  end
end
