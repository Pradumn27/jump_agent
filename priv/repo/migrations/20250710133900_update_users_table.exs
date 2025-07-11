defmodule JumpAgent.Repo.Migrations.UpdateUsersTable do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :provider, :string
      add :uid, :string
      add :token, :string
      add :refresh_token, :string
      add :expires_at, :utc_datetime
      add :name, :string
      modify :hashed_password, :string, null: true
    end
  end
end
