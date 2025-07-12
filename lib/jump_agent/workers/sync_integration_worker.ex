defmodule JumpAgent.Workers.SyncIntegrationsWorker do
  use Oban.Worker,
    queue: :default,
    max_attempts: 1,
    tags: ["sync", "integrations"]

  alias JumpAgent.Accounts
  alias JumpAgent.Integrations
  require Logger

  def perform(_job) do
    logged_in_user_ids = Accounts.get_users_with_valid_sessions()

    Enum.each(logged_in_user_ids, fn user_id ->
      case Accounts.get_user!(user_id) do
        %{} = user ->
          Task.start(fn ->
            try do
              Integrations.sync_integrations(user)
            rescue
              e -> Logger.error("Cron sync failed for user #{user.id}: #{inspect(e)}")
            end
          end)

        _ ->
          :noop
      end
    end)

    :ok
  end
end
