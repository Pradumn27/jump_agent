defmodule JumpAgent.Tools.Hubspot.UpdateContact do
  require Logger

  def spec do
    %{
      type: "function",
      function: %{
        name: "update_contact",
        description: "Update an existing HubSpot contact",
        parameters: %{
          type: "object",
          properties: %{
            contact_id: %{type: "string", description: "The unique HubSpot contact ID"},
            email: %{type: "string", description: "Updated email address"},
            first_name: %{type: "string", description: "Updated first name"},
            last_name: %{type: "string", description: "Updated last name"},
            phone: %{type: "string", description: "Updated phone number"}
          },
          required: ["contact_id"]
        }
      }
    }
  end

  def run(user, %{"contact_id" => contact_id} = attrs) do
    with {:ok, token} <- JumpAgent.Integrations.Hubspot.get_token(user) do
      body = %{
        properties: %{}
      }

      # Optional fields to update
      maybe_put = fn key, hs_key ->
        case Map.get(attrs, key) do
          nil -> fn b -> b end
          val -> fn b -> Map.update!(b, :properties, &Map.put(&1, hs_key, val)) end
        end
      end

      update_body =
        body
        |> maybe_put.("email", "email").()
        |> maybe_put.("first_name", "firstname").()
        |> maybe_put.("last_name", "lastname").()
        |> maybe_put.("phone", "phone").()

      headers = [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ]

      url = "https://api.hubapi.com/crm/v3/objects/contacts/#{contact_id}"

      case HTTPoison.patch(url, Jason.encode!(update_body), headers) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          "✅ Contact updated successfully"

        {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
          Logger.error("❌ Failed to update contact: #{body}")
          "❌ HubSpot error (#{status}): #{body}"

        {:error, reason} ->
          Logger.error("❌ HTTP error: #{inspect(reason)}")
          "❌ Failed to update contact: #{inspect(reason)}"
      end
    else
      {:error, :no_hubspot_auth} -> "❌ HubSpot not connected. Please authenticate first."
    end
  end
end
