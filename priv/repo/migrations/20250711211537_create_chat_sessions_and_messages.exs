defmodule JumpAgent.Repo.Migrations.CreateChatSessionsAndMessages do
  use Ecto.Migration

  def change do
    create table(:chat_sessions) do
      add :title, :string
      add :started_at, :utc_datetime
      add :last_active_at, :utc_datetime

      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:chat_sessions, [:user_id])

    create table(:messages) do
      add :role, :string
      add :content, :text
      add :timestamp, :utc_datetime
      add :metadata, :map

      add :chat_session_id, references(:chat_sessions, on_delete: :delete_all)

      timestamps()
    end

    create index(:messages, [:chat_session_id])
  end
end
