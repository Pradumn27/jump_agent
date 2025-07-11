defmodule JumpAgent.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    field :timestamp, :utc_datetime
    field :metadata, :map
    field :role, :string
    field :content, :string
    field :chat_session_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :timestamp, :metadata, :chat_session_id])
    |> validate_required([:role, :content, :timestamp, :chat_session_id])
  end
end
