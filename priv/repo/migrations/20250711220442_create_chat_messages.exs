defmodule JumpAgent.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :content, :text
      add :role, :string
      add :timestamp, :naive_datetime
      add :chat_session_id, references(:chat_sessions, on_delete: :delete_all)

      timestamps()
    end

    create index(:chat_messages, [:chat_session_id])
  end
end
