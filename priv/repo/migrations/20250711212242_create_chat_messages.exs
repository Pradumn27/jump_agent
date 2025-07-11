defmodule JumpAgent.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :role, :string
      add :content, :text
      add :timestamp, :utc_datetime
      add :metadata, :map
      add :chat_session_id, references(:chat_sessions, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:chat_session_id])
  end
end
