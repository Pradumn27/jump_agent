defmodule JumpAgent.Integrations.IntegrationStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_integrations ["Gmail", "Calendar", "HubSpot"]
  @valid_statuses ["idle", "syncing", "error", "completed"]

  schema "integration_statuses" do
    field :integration, :string
    field :status, :string, default: "idle"
    field :last_synced_at, :utc_datetime_usec
    field :last_error, :string

    belongs_to :user, JumpAgent.Accounts.User

    timestamps()
  end

  def changeset(status, attrs) do
    status
    |> cast(attrs, [:integration, :status, :last_synced_at, :last_error, :user_id])
    |> validate_required([:integration, :status, :user_id])
    |> validate_inclusion(:integration, @valid_integrations)
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint([:user_id, :integration])
  end
end
