defmodule JumpAgent.Knowledge.Context do
  use Ecto.Schema
  import Ecto.Changeset

  schema "contexts" do
    field :metadata, :map
    field :source, :string
    field :source_id, :string
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(context, attrs) do
    context
    |> cast(attrs, [:source, :source_id, :content, :metadata, :embedding])
    |> validate_required([:source, :source_id, :content])
  end
end
