defmodule JumpAgent.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias JumpAgent.Repo

  alias JumpAgent.Chat.ChatSession

  @doc """
  Returns the list of chat_sessions.

  ## Examples

      iex> list_chat_sessions()
      [%ChatSession{}, ...]

  """
  def list_chat_sessions do
    ChatSession
    |> order_by(desc: :last_active_at)
    |> Repo.all()
  end

  @doc """
  Gets a single chat_session.

  Raises `Ecto.NoResultsError` if the Chat session does not exist.

  ## Examples

      iex> get_chat_session!(123)
      %ChatSession{}

      iex> get_chat_session!(456)
      ** (Ecto.NoResultsError)

  """
  def get_chat_session!(id), do: Repo.get!(ChatSession, id) |> Repo.preload(:messages)

  @doc """
  Creates a chat_session.

  ## Examples

      iex> create_chat_session(%{field: value})
      {:ok, %ChatSession{}}

      iex> create_chat_session(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_chat_session(attrs \\ %{}) do
    %ChatSession{}
    |> ChatSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a chat_session.

  ## Examples

      iex> update_chat_session(chat_session, %{field: new_value})
      {:ok, %ChatSession{}}

      iex> update_chat_session(chat_session, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_chat_session(%ChatSession{} = chat_session, attrs) do
    chat_session
    |> ChatSession.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a chat_session.

  ## Examples

      iex> delete_chat_session(chat_session)
      {:ok, %ChatSession{}}

      iex> delete_chat_session(chat_session)
      {:error, %Ecto.Changeset{}}

  """
  def delete_chat_session(%ChatSession{} = chat_session) do
    Repo.delete(chat_session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking chat_session changes.

  ## Examples

      iex> change_chat_session(chat_session)
      %Ecto.Changeset{data: %ChatSession{}}

  """
  def change_chat_session(%ChatSession{} = chat_session, attrs \\ %{}) do
    ChatSession.changeset(chat_session, attrs)
  end

  alias JumpAgent.Chat.Message

  @doc """
  Returns the list of chat_messages.

  ## Examples

      iex> list_chat_messages()
      [%Message{}, ...]

  """
  def list_chat_messages do
    Repo.all(Message)
  end

  @doc """
  Gets a single message.

  Raises `Ecto.NoResultsError` if the Message does not exist.

  ## Examples

      iex> get_message!(123)
      %Message{}

      iex> get_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Creates a message.

  ## Examples

      iex> create_message(%{field: value})
      {:ok, %Message{}}

      iex> create_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a message.

  ## Examples

      iex> update_message(message, %{field: new_value})
      {:ok, %Message{}}

      iex> update_message(message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a message.

  ## Examples

      iex> delete_message(message)
      {:ok, %Message{}}

      iex> delete_message(message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.

  ## Examples

      iex> change_message(message)
      %Ecto.Changeset{data: %Message{}}

  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  # Additional functions

  def get_chat_session_with_messages!(id) do
    ChatSession
    |> Repo.get!(id)
    |> Repo.preload(:messages)
  end

  def list_user_chat_sessions(user_id) do
    from(cs in ChatSession, where: cs.user_id == ^user_id, order_by: [desc: cs.inserted_at])
    |> Repo.all()
  end

  def start_new_chat_session(user_id, title \\ "New Chat") do
    now = DateTime.utc_now()

    create_chat_session(%{
      title: title,
      user_id: user_id,
      started_at: now,
      last_active_at: now
    })
  end

  def append_message_to_session(chat_session_id, role, content, metadata \\ %{}) do
    timestamp = DateTime.utc_now()

    Repo.transaction(fn ->
      message_result =
        create_message(%{
          chat_session_id: chat_session_id,
          role: role,
          content: content,
          metadata: metadata,
          timestamp: timestamp
        })

      # update session last active time
      update_chat_session(
        get_chat_session!(chat_session_id),
        %{last_active_at: timestamp}
      )

      message_result
    end)
  end

  def search_messages(query, user_id) do
    from(m in Message,
      join: cs in ChatSession,
      on: cs.id == m.chat_session_id,
      where: ilike(m.content, ^"%#{query}%") and cs.user_id == ^user_id,
      preload: [:chat_session],
      order_by: [desc: m.timestamp]
    )
    |> Repo.all()
  end

  def delete_chat_session_with_messages(%ChatSession{} = chat_session) do
    Repo.transaction(fn ->
      from(m in Message, where: m.chat_session_id == ^chat_session.id) |> Repo.delete_all()
      delete_chat_session(chat_session)
    end)
  end
end
