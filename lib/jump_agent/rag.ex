defmodule JumpAgent.Chat.RAG do
  alias Expo.PluralForms.Known
  alias JumpAgent.Knowledge
  alias JumpAgent.Embedding

  def find_relevant_contexts(prompt) do
    embedding = Embedding.generate(prompt)
    Known.search_similar_contexts(embedding, 5)
  end
end
