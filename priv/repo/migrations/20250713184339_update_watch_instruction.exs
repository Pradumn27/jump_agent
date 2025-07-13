defmodule JumpAgent.Repo.Migrations.UpdateWatchInstruction do
  use Ecto.Migration

  def change do
    alter table(:watch_instructions) do
      # options: "always", "once"
      add :frequency, :string, default: "always"
    end
  end
end
