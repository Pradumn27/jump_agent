defmodule JumpAgent.ChatFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `JumpAgent.Chat` context.
  """

  @doc """
  Generate a chat_session.
  """
  def chat_session_fixture(attrs \\ %{}) do
    {:ok, chat_session} =
      attrs
      |> Enum.into(%{
        last_active_at: ~U[2025-07-10 21:17:00Z],
        started_at: ~U[2025-07-10 21:17:00Z],
        title: "some title"
      })
      |> JumpAgent.Chat.create_chat_session()

    chat_session
  end

  @doc """
  Generate a message.
  """
  def message_fixture(attrs \\ %{}) do
    {:ok, message} =
      attrs
      |> Enum.into(%{
        content: "some content",
        metadata: %{},
        role: "some role",
        timestamp: ~U[2025-07-10 21:22:00Z]
      })
      |> JumpAgent.Chat.create_message()

    message
  end
end
