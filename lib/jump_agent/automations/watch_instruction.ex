defmodule JumpAgent.Automations.WatchInstruction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "watch_instructions" do
    field :trigger, :string
    field :instruction, :string
    field :last_executed_at, :utc_datetime_usec
    field :is_active, :boolean, default: true
    # or "once"
    field :frequency, :string, default: "always"

    belongs_to :user, JumpAgent.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(watch_instruction, attrs) do
    watch_instruction
    |> cast(attrs, [:trigger, :instruction, :user_id, :last_executed_at, :is_active, :frequency])
    |> validate_required([:trigger, :instruction, :user_id])
    |> validate_inclusion(:trigger, ["gmail", "calendar", "hubspot"])
    |> validate_inclusion(:frequency, ["always", "once"])
  end
end
