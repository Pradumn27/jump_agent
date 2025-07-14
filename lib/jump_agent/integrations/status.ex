defmodule JumpAgent.Integrations.Status do
  @moduledoc """
  Manages sync status and last synced info for integrations like Gmail, Calendar, HubSpot.
  """

  import Ecto.Query, warn: false
  alias JumpAgent.Repo
  alias JumpAgent.Integrations.IntegrationStatus
  alias JumpAgent.Accounts.User

  @type integration_name :: String.t()
  @valid_integrations ["Gmail", "Calendar", "HubSpot"]

  @doc """
  Gets or initializes a status entry for a given user and integration.
  """
  def get_or_create_status(%User{id: user_id}, integration)
      when integration in @valid_integrations do
    Repo.get_by(IntegrationStatus, user_id: user_id, integration: integration) ||
      create_status(user_id, integration)
  end

  defp create_status(user_id, integration) do
    %IntegrationStatus{}
    |> IntegrationStatus.changeset(%{
      user_id: user_id,
      integration: integration,
      status: "idle"
    })
    |> Repo.insert!()
  end

  @doc """
  Updates the status for a given user + integration (e.g., "syncing", "idle", "error").
  """
  def update_status(%User{id: user_id}, integration, status, opts \\ [])
      when integration in @valid_integrations do
    status_record = get_or_create_status(%User{id: user_id}, integration)

    changes =
      %{
        status: status
      }
      |> maybe_put(:last_synced_at, opts[:last_synced_at])
      |> maybe_put(:last_error, opts[:last_error])

    status_record
    |> IntegrationStatus.changeset(changes)
    |> Repo.update()
  end

  @doc """
  Lists all sync statuses for a given user.
  """
  def list_statuses_for_user(%User{id: user_id}) do
    from(s in IntegrationStatus, where: s.user_id == ^user_id)
    |> Repo.all()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  def ensure_integration_statuses_exist(user) do
    integrations = ["Gmail", "Calendar", "HubSpot"]

    Enum.each(integrations, fn integration ->
      attrs = %{user_id: user.id, integration: integration}

      Repo.insert!(
        %JumpAgent.Integrations.IntegrationStatus{}
        |> JumpAgent.Integrations.IntegrationStatus.changeset(attrs),
        on_conflict: :nothing,
        conflict_target: [:user_id, :integration]
      )
    end)
  end

  def list_integration_statuses(user) do
    from(s in IntegrationStatus, where: s.user_id == ^user.id)
    |> Repo.all()
  end

  def update_or_create_status(user, integration, status) do
    now = DateTime.utc_now()

    %{
      user_id: user.id,
      integration: integration,
      status: status,
      last_synced_at: if(status == "syncing", do: nil, else: now)
    }
    |> then(fn attrs ->
      Repo.insert!(
        struct(IntegrationStatus, attrs),
        on_conflict: [set: [status: status, updated_at: now]],
        conflict_target: [:user_id, :integration]
      )
    end)
  end
end
