defmodule JumpAgent.Accounts.AuthIdentity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "auth_identities" do
    field :token, :string
    field :uid, :string
    field :provider, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(auth_identity, attrs) do
    auth_identity
    |> cast(attrs, [:provider, :uid, :token, :refresh_token, :expires_at])
    |> validate_required([:provider, :uid, :token, :refresh_token, :expires_at])
  end
end
