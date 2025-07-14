defmodule JumpAgent.Knowledge do
  @moduledoc """
  The Knowledge context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias JumpAgent.Repo

  alias JumpAgent.Knowledge.Context

  @doc """
  Returns the list of contexts.

  ## Examples

      iex> list_contexts()
      [%Context{}, ...]

  """
  def list_contexts do
    Repo.all(Context)
  end

  @doc """
  Gets a single context.

  Raises `Ecto.NoResultsError` if the Context does not exist.

  ## Examples

      iex> get_context!(123)
      %Context{}

      iex> get_context!(456)
      ** (Ecto.NoResultsError)

  """
  def get_context!(id), do: Repo.get!(Context, id)

  @doc """
  Creates a context.

  ## Examples

      iex> create_context(%{field: value})
      {:ok, %Context{}}

      iex> create_context(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_context(attrs \\ %{}) do
    try do
      %Context{}
      |> Context.changeset(attrs)
      |> maybe_embed_embedding()
      |> Repo.insert()
    rescue
      e in Ecto.ChangeError ->
        {:error, {:change_error, e.message}}

      e in DBConnection.ConnectionError ->
        {:error, {:db_connection_error, e.message}}

      e ->
        {:error, {:unknown_error, Exception.message(e)}}
    end
  end

  @doc """
  Updates a context.

  ## Examples

      iex> update_context(context, %{field: new_value})
      {:ok, %Context{}}

      iex> update_context(context, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_context(%Context{} = context, attrs) do
    context
    |> Context.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a context.

  ## Examples

      iex> delete_context(context)
      {:ok, %Context{}}

      iex> delete_context(context)
      {:error, %Ecto.Changeset{}}

  """
  def delete_context(%Context{} = context) do
    Repo.delete(context)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking context changes.

  ## Examples

      iex> change_context(context)
      %Ecto.Changeset{data: %Context{}}

  """
  def change_context(%Context{} = context, attrs \\ %{}) do
    Context.changeset(context, attrs)
  end

  defp maybe_embed_embedding(changeset) do
    if content = get_change(changeset, :content) do
      embedding = JumpAgent.Embedding.generate(content)
      put_change(changeset, :embedding, embedding)
    else
      changeset
    end
  end

  @doc """
  Finds top N similar context entries based on a given embedding.
  """
  def search_similar_contexts(embedding, user_id, limit \\ 5) do
    from(c in Context,
      where: c.user_id == ^user_id,
      order_by: fragment("embedding <#> ?", ^embedding),
      limit: ^limit
    )
    |> Repo.all()
  end

  def get_context_by_source_id(source, source_id, user_id) do
    Repo.get_by(JumpAgent.Knowledge.Context,
      source: source,
      source_id: source_id,
      user_id: user_id
    )
  end
end
