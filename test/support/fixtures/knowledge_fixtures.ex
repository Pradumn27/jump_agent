defmodule JumpAgent.KnowledgeFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `JumpAgent.Knowledge` context.
  """

  @doc """
  Generate a context.
  """
  def context_fixture(attrs \\ %{}) do
    {:ok, context} =
      attrs
      |> Enum.into(%{
        content: "some content",
        embedding: %{},
        metadata: %{},
        source: "some source",
        source_id: "some source_id"
      })
      |> JumpAgent.Knowledge.create_context()

    context
  end
end
