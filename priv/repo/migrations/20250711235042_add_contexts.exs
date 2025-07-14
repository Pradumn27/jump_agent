defmodule JumpAgent.Repo.Migrations.AddContexts do
  use Ecto.Migration

  def change do
    # Ensure pgvector extension is available
    execute("CREATE EXTENSION IF NOT EXISTS vector")

    create table(:contexts) do
      # e.g. gmail, hubspot, etc.
      add :source, :string
      add :source_id, :string
      add :content, :text
      add :metadata, :map
      # OpenAI model vector size
      add :embedding, :vector, size: 1536
      timestamps()
    end

    create index(:contexts, [:source])
    create index(:contexts, [:source_id])

    # Vector index for similarity search
    execute("""
    CREATE INDEX contexts_embedding_vector_idx
    ON contexts
    USING ivfflat (embedding vector_l2_ops)
    """)
  end
end
