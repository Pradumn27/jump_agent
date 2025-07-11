defmodule JumpAgent.Repo.Migrations.CreateAuthIdentities do
  use Ecto.Migration

  def change do
    create table(:auth_identities) do
      add :provider, :string
      add :uid, :string
      add :token, :string
      add :refresh_token, :string
      add :expires_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:auth_identities, [:provider, :uid])
  end
end
