defmodule JumpAgent.KnowledgeTest do
  use JumpAgent.DataCase

  alias JumpAgent.Knowledge

  describe "contexts" do
    alias JumpAgent.Knowledge.Knowledge.Context

    import JumpAgent.KnowledgeFixtures

    @invalid_attrs %{metadata: nil, source: nil, source_id: nil, content: nil, embedding: nil}

    test "list_contexts/0 returns all contexts" do
      context = context_fixture()
      assert Knowledge.list_contexts() == [context]
    end

    test "get_context!/1 returns the context with given id" do
      context = context_fixture()
      assert Knowledge.get_context!(context.id) == context
    end

    test "create_context/1 with valid data creates a context" do
      valid_attrs = %{metadata: %{}, source: "some source", source_id: "some source_id", content: "some content", embedding: %{}}

      assert {:ok, %Context{} = context} = Knowledge.create_context(valid_attrs)
      assert context.metadata == %{}
      assert context.source == "some source"
      assert context.source_id == "some source_id"
      assert context.content == "some content"
      assert context.embedding == %{}
    end

    test "create_context/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Knowledge.create_context(@invalid_attrs)
    end

    test "update_context/2 with valid data updates the context" do
      context = context_fixture()
      update_attrs = %{metadata: %{}, source: "some updated source", source_id: "some updated source_id", content: "some updated content", embedding: %{}}

      assert {:ok, %Context{} = context} = Knowledge.update_context(context, update_attrs)
      assert context.metadata == %{}
      assert context.source == "some updated source"
      assert context.source_id == "some updated source_id"
      assert context.content == "some updated content"
      assert context.embedding == %{}
    end

    test "update_context/2 with invalid data returns error changeset" do
      context = context_fixture()
      assert {:error, %Ecto.Changeset{}} = Knowledge.update_context(context, @invalid_attrs)
      assert context == Knowledge.get_context!(context.id)
    end

    test "delete_context/1 deletes the context" do
      context = context_fixture()
      assert {:ok, %Context{}} = Knowledge.delete_context(context)
      assert_raise Ecto.NoResultsError, fn -> Knowledge.get_context!(context.id) end
    end

    test "change_context/1 returns a context changeset" do
      context = context_fixture()
      assert %Ecto.Changeset{} = Knowledge.change_context(context)
    end
  end
end
