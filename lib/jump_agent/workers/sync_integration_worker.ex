defmodule JumpAgent.Workers.SyncIntegrationsWorker do
  use Oban.Worker,
    queue: :default,
    max_attempts: 1,
    tags: ["sync", "integrations"]

  alias JumpAgent.Accounts
  require Logger

  def perform(_job) do
    logged_in_users = Accounts.get_users_with_valid_sessions()
    Logger.info("[SyncWorker] Running sync evaluation")

    Task.Supervisor.async_stream(
      JumpAgent.SyncSupervisor,
      logged_in_users,
      fn user ->
        try do
          JumpAgent.Integrations.sync_integrations(user)
        rescue
          e -> Logger.error("Sync failed for user #{user.id}: #{inspect(e)}")
        end
      end,
      # or 5 depending on your resources
      max_concurrency: 3,
      timeout: :timer.minutes(5)
    )
    |> Stream.run()

    :ok
  end
end
