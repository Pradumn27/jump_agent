defmodule JumpAgent.Automations.WatchInstruction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "watch_instructions" do
    field :trigger, :string
    field :instruction, :string
    field :last_executed_at, :utc_datetime_usec
    field :isActive, :boolean, default: true
    field :frequency, :string, default: "always"

    belongs_to :user, JumpAgent.Accounts.User

    timestamps()
  end

  def changeset(watch_instruction, attrs) do
    watch_instruction
    |> cast(attrs, [:trigger, :instruction, :user_id, :last_executed_at, :isActive])
    |> validate_required([:trigger, :instruction, :user_id])
  end
end
