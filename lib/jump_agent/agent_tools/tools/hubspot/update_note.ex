defmodule JumpAgent.Tools.Hubspot.UpdateNote do
  require Logger

  def spec do
    %{
      type: "function",
      function: %{
        name: "update_hubspot_note",
        description: "Update a note in HubSpot by ID",
        parameters: %{
          type: "object",
          properties: %{
            note_id: %{type: "string", description: "The ID of the HubSpot note"},
            body: %{type: "string", description: "The new content of the note"}
          },
          required: ["note_id", "body"]
        }
      }
    }
  end

  def run(user, %{"note_id" => note_id, "body" => new_body}) do
    with {:ok, token} <- JumpAgent.Integrations.Hubspot.get_token(user) do
      timestamp_ms = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

      body = %{
        "properties" => %{
          "hs_note_body" => new_body,
          "hs_timestamp" => timestamp_ms
        }
      }

      headers = [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ]

      url = "https://api.hubapi.com/crm/v3/objects/notes/#{note_id}"

      case Req.patch(url, headers: headers, json: body) do
        {:ok, %Req.Response{status: 200, body: response}} ->
          {:ok, response}

        {:ok, %Req.Response{status: _status, body: error}} ->
          Logger.error("❌ Failed to update note: #{inspect(error)}")
          {:error, error}

        {:error, reason} ->
          Logger.error("❌ HTTP request failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
