defmodule JumpAgent.WatchEngine do
  @moduledoc """
  Handles dynamic WatchInstructions triggered by Gmail, Calendar, or HubSpot.
  Each instruction is interpreted by GPT in real-time.
  """

  require Logger
  alias JumpAgent.WatchInstructions
  alias JumpAgent.OpenAI

  def handle_trigger(trigger, user, context) do
    Logger.info("⏳ Executing trigger: #{trigger} for user #{user.email}")

    WatchInstructions.get_by_trigger(trigger)
    |> Enum.each(fn instruction ->
      execute_instruction(user, instruction, context)
    end)
  end

  defp execute_instruction(user, %{instruction: instruction_text}, context) do
    Logger.info("🤖 Evaluating instruction: #{instruction_text}")

    user_prompt = """
    Triggered automation instruction:
    #{instruction_text}

    Event context:
    #{inspect(context)}
    """

    case OpenAI.chat_completion(user_prompt, user, nil) do
      {:ok, reply} ->
        Logger.info("✅ Instruction executed: #{inspect(reply)}")

      {:error, reason} ->
        Logger.error("❌ GPT failed to execute instruction: #{inspect(reason)}")
    end
  end
end
