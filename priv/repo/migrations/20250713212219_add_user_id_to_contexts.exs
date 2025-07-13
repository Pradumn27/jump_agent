defmodule JumpAgent.Repo.Migrations.AddUserIdToContexts do
  use Ecto.Migration

  def change do
    alter table(:contexts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    create index(:contexts, [:user_id])
  end
end
