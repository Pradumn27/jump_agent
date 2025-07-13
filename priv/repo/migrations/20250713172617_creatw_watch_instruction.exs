defmodule JumpAgent.Repo.Migrations.CreatwWatchInstruction do
  use Ecto.Migration

  def change do
    create table(:watch_instructions) do
      add :trigger, :string, null: false
      add :instruction, :text, null: false
      add :last_executed_at, :utc_datetime_usec
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :isActive, :boolean, default: true

      timestamps()
    end

    create index(:watch_instructions, [:user_id])
    create index(:watch_instructions, [:trigger])
  end
end
