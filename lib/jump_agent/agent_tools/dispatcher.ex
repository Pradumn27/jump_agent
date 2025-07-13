defmodule JumpAgent.AgentTools.Dispatcher do
  require Logger

  # Email

  def dispatch_tool("send_email", user, args) do
    JumpAgent.Tools.Email.SendEmail.run(user, args)
  end

  def dispatch_tool("move_email", user, args) do
    JumpAgent.Tools.Email.MoveEmail.run(user, args)
  end

  def dispatch_tool("reply_to_email", user, args) do
    JumpAgent.Tools.Email.ReplyToEmail.run(user, args)
  end

  # Calendar

  def dispatch_tool("create_meeting", user, args) do
    JumpAgent.Tools.Calendar.CreateMeeting.run(user, args)
  end

  def dispatch_tool("cancel_meeting", user, args) do
    JumpAgent.Tools.Calendar.CancelMeeting.run(user, args)
  end

  def dispatch_tool("reschedule_meeting", user, args) do
    JumpAgent.Tools.Calendar.RescheduleMeeting.run(user, args)
  end

  # Hubspot

  def dispatch_tool("create_contact", user, args) do
    JumpAgent.Tools.Hubspot.CreateContact.run(user, args)
  end

  def dispatch_tool("update_contact", user, args) do
    JumpAgent.Tools.Hubspot.UpdateContact.run(user, args)
  end

  def dispatch_tool("create_note", user, args) do
    JumpAgent.Tools.Hubspot.CreateNote.run(user, args)
  end

  def dispatch_tool("update_hubspot_note", user, args) do
    JumpAgent.Tools.Hubspot.UpdateNote.run(user, args)
  end

  # WatchInstructions

  def dispatch_tool("update_watch_instruction", user, args) do
    JumpAgent.Tools.WatchInstructions.UpdateWatchInstruction.run(user, args)
  end

  def dispatch_tool("create_watch_instruction", user, args) do
    JumpAgent.Tools.WatchInstructions.CreateWatchInstruction.run(user, args)
  end

  # Unknown

  def dispatch_tool(tool_name, _args, _user) do
    "Unknown tool called: #{tool_name}"
  end
end
