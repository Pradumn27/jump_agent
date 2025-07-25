defmodule JumpAgent.Knowledge.Context do
  use Ecto.Schema
  import Ecto.Changeset

  schema "contexts" do
    field :metadata, :map
    field :source, :string
    field :source_id, :string
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector

    belongs_to :user, JumpAgent.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(context, attrs) do
    context
    |> cast(attrs, [:source, :source_id, :content, :metadata, :embedding, :user_id])
    |> validate_required([:source, :source_id, :content, :user_id])
    |> unique_constraint([:user_id, :source, :source_id])
  end
end
