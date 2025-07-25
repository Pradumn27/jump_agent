defmodule JumpAgent.Chat.ChatSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_sessions" do
    field :started_at, :utc_datetime
    field :title, :string
    field :last_active_at, :utc_datetime
    field :user_id, :id

    has_many :messages, JumpAgent.Chat.Message, foreign_key: :chat_session_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat_session, attrs) do
    chat_session
    |> cast(attrs, [:title, :started_at, :last_active_at, :user_id])
    |> validate_required([:title, :started_at, :last_active_at, :user_id])
  end
end
