defmodule JumpAgent.ChatTest do
  use JumpAgent.DataCase

  alias JumpAgent.Chat

  describe "chat_sessions" do
    alias JumpAgent.Chat.ChatSession

    import JumpAgent.ChatFixtures

    @invalid_attrs %{started_at: nil, title: nil, last_active_at: nil}

    test "list_chat_sessions/0 returns all chat_sessions" do
      chat_session = chat_session_fixture()
      assert Chat.list_chat_sessions() == [chat_session]
    end

    test "get_chat_session!/1 returns the chat_session with given id" do
      chat_session = chat_session_fixture()
      assert Chat.get_chat_session!(chat_session.id) == chat_session
    end

    test "create_chat_session/1 with valid data creates a chat_session" do
      valid_attrs = %{
        started_at: ~U[2025-07-10 21:17:00Z],
        title: "some title",
        last_active_at: ~U[2025-07-10 21:17:00Z]
      }

      assert {:ok, %ChatSession{} = chat_session} = Chat.create_chat_session(valid_attrs)
      assert chat_session.started_at == ~U[2025-07-10 21:17:00Z]
      assert chat_session.title == "some title"
      assert chat_session.last_active_at == ~U[2025-07-10 21:17:00Z]
    end

    test "create_chat_session/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_chat_session(@invalid_attrs)
    end

    test "update_chat_session/2 with valid data updates the chat_session" do
      chat_session = chat_session_fixture()

      update_attrs = %{
        started_at: ~U[2025-07-11 21:17:00Z],
        title: "some updated title",
        last_active_at: ~U[2025-07-11 21:17:00Z]
      }

      assert {:ok, %ChatSession{} = chat_session} =
               Chat.update_chat_session(chat_session, update_attrs)

      assert chat_session.started_at == ~U[2025-07-11 21:17:00Z]
      assert chat_session.title == "some updated title"
      assert chat_session.last_active_at == ~U[2025-07-11 21:17:00Z]
    end

    test "update_chat_session/2 with invalid data returns error changeset" do
      chat_session = chat_session_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.update_chat_session(chat_session, @invalid_attrs)
      assert chat_session == Chat.get_chat_session!(chat_session.id)
    end

    test "change_chat_session/1 returns a chat_session changeset" do
      chat_session = chat_session_fixture()
      assert %Ecto.Changeset{} = Chat.change_chat_session(chat_session)
    end
  end

  describe "chat_messages" do
    alias JumpAgent.Chat.Chat.Message

    import JumpAgent.ChatFixtures

    @invalid_attrs %{timestamp: nil, metadata: nil, role: nil, content: nil}

    test "list_chat_messages/0 returns all chat_messages" do
      message = message_fixture()
      assert Chat.list_chat_messages() == [message]
    end

    test "get_message!/1 returns the message with given id" do
      message = message_fixture()
      assert Chat.get_message!(message.id) == message
    end

    test "create_message/1 with valid data creates a message" do
      valid_attrs = %{
        timestamp: ~U[2025-07-10 21:22:00Z],
        metadata: %{},
        role: "some role",
        content: "some content"
      }

      assert {:ok, %Message{} = message} = Chat.create_message(valid_attrs)
      assert message.timestamp == ~U[2025-07-10 21:22:00Z]
      assert message.metadata == %{}
      assert message.role == "some role"
      assert message.content == "some content"
    end

    test "create_message/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_message(@invalid_attrs)
    end

    test "update_message/2 with valid data updates the message" do
      message = message_fixture()

      update_attrs = %{
        timestamp: ~U[2025-07-11 21:22:00Z],
        metadata: %{},
        role: "some updated role",
        content: "some updated content"
      }

      assert {:ok, %Message{} = message} = Chat.update_message(message, update_attrs)
      assert message.timestamp == ~U[2025-07-11 21:22:00Z]
      assert message.metadata == %{}
      assert message.role == "some updated role"
      assert message.content == "some updated content"
    end

    test "update_message/2 with invalid data returns error changeset" do
      message = message_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.update_message(message, @invalid_attrs)
      assert message == Chat.get_message!(message.id)
    end

    test "delete_message/1 deletes the message" do
      message = message_fixture()
      assert {:ok, %Message{}} = Chat.delete_message(message)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_message!(message.id) end
    end

    test "change_message/1 returns a message changeset" do
      message = message_fixture()
      assert %Ecto.Changeset{} = Chat.change_message(message)
    end
  end

  describe "chat_messages" do
    alias JumpAgent.Chat.Message

    import JumpAgent.ChatFixtures

    @invalid_attrs %{timestamp: nil, metadata: nil, role: nil, content: nil}

    test "list_chat_messages/0 returns all chat_messages" do
      message = message_fixture()
      assert Chat.list_chat_messages() == [message]
    end

    test "get_message!/1 returns the message with given id" do
      message = message_fixture()
      assert Chat.get_message!(message.id) == message
    end

    test "create_message/1 with valid data creates a message" do
      valid_attrs = %{
        timestamp: ~U[2025-07-10 21:23:00Z],
        metadata: %{},
        role: "some role",
        content: "some content"
      }

      assert {:ok, %Message{} = message} = Chat.create_message(valid_attrs)
      assert message.timestamp == ~U[2025-07-10 21:23:00Z]
      assert message.metadata == %{}
      assert message.role == "some role"
      assert message.content == "some content"
    end

    test "create_message/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_message(@invalid_attrs)
    end

    test "update_message/2 with valid data updates the message" do
      message = message_fixture()

      update_attrs = %{
        timestamp: ~U[2025-07-11 21:23:00Z],
        metadata: %{},
        role: "some updated role",
        content: "some updated content"
      }

      assert {:ok, %Message{} = message} = Chat.update_message(message, update_attrs)
      assert message.timestamp == ~U[2025-07-11 21:23:00Z]
      assert message.metadata == %{}
      assert message.role == "some updated role"
      assert message.content == "some updated content"
    end

    test "update_message/2 with invalid data returns error changeset" do
      message = message_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.update_message(message, @invalid_attrs)
      assert message == Chat.get_message!(message.id)
    end

    test "delete_message/1 deletes the message" do
      message = message_fixture()
      assert {:ok, %Message{}} = Chat.delete_message(message)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_message!(message.id) end
    end

    test "change_message/1 returns a message changeset" do
      message = message_fixture()
      assert %Ecto.Changeset{} = Chat.change_message(message)
    end
  end
end
