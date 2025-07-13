defmodule JumpAgent.AgentTools do
  def get_tools() do
    [
      JumpAgent.Tools.Email.SendEmail.spec(),
      JumpAgent.Tools.Email.MoveEmail.spec(),
      JumpAgent.Tools.Email.ReplyToEmail.spec(),
      JumpAgent.Tools.Calendar.CreateMeeting.spec(),
      JumpAgent.Tools.Calendar.CancelMeeting.spec(),
      JumpAgent.Tools.Calendar.RescheduleMeeting.spec(),
      JumpAgent.Tools.Hubspot.CreateContact.spec(),
      JumpAgent.Tools.Hubspot.UpdateContact.spec(),
      JumpAgent.Tools.Hubspot.CreateNote.spec(),
      JumpAgent.Tools.Hubspot.UpdateNote.spec(),
      JumpAgent.Tools.WatchInstructions.UpdateWatchInstruction.spec(),
      JumpAgent.Tools.WatchInstructions.CreateWatchInstruction.spec()
    ]
  end
end
