defmodule JumpAgent.Repo.Migrations.CreateIntegrationStatuses do
  use Ecto.Migration

  def change do
    create table(:integration_statuses) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :integration, :string, null: false
      add :status, :string, default: "idle", null: false
      add :last_synced_at, :utc_datetime_usec
      add :last_error, :text

      timestamps()
    end

    create unique_index(:integration_statuses, [:user_id, :integration])
  end
end
