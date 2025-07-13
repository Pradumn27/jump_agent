defmodule JumpAgent.Tools.Hubspot.CreateNote do
  require Logger

  def spec do
    %{
      type: "function",
      function: %{
        name: "create_note",
        description: "Create a note associated with a HubSpot contact",
        parameters: %{
          type: "object",
          properties: %{
            contact_id: %{
              type: "string",
              description: "HubSpot contact ID to attach the note to"
            },
            note: %{type: "string", description: "The note content to attach"}
          },
          required: ["contact_id", "note"]
        }
      }
    }
  end

  def run(user, %{"contact_id" => contact_id, "note" => note_content}) do
    with {:ok, token} <- JumpAgent.Integrations.Hubspot.get_token(user) do
      url = "https://api.hubapi.com/crm/v3/objects/notes"
      timestamp_ms = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

      body = %{
        properties: %{
          hs_note_body: note_content,
          hs_timestamp: timestamp_ms
        },
        associations: [
          %{
            to: %{id: contact_id},
            types: [
              %{associationCategory: "HUBSPOT_DEFINED", associationTypeId: 202}
            ]
          }
        ]
      }

      headers = [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ]

      case HTTPoison.post(url, Jason.encode!(body), headers) do
        {:ok, %HTTPoison.Response{status_code: 201}} ->
          "✅ Note created and associated with contact #{contact_id}"

        {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
          Logger.error("❌ Failed to create note: #{body}")
          "❌ HubSpot error (#{code}): #{body}"

        {:error, reason} ->
          Logger.error("❌ HTTP error: #{inspect(reason)}")
          "❌ Failed to create note: #{inspect(reason)}"
      end
    else
      {:error, :no_hubspot_auth} -> "❌ HubSpot not connected. Please authenticate first."
    end
  end
end
