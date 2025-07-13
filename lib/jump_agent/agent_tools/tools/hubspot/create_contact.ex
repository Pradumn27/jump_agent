defmodule JumpAgent.Tools.Hubspot.CreateContact do
  require Logger

  def spec do
    %{
      type: "function",
      function: %{
        name: "create_contact",
        description: "Creates a contact in HubSpot CRM",
        parameters: %{
          type: "object",
          properties: %{
            email: %{type: "string", description: "Email address of the contact"},
            first_name: %{type: "string", description: "First name of the contact"},
            last_name: %{type: "string", description: "Last name of the contact"},
            phone: %{type: "string", description: "Phone number of the contact"}
          },
          required: ["email"]
        }
      }
    }
  end

  def run(user, %{"email" => email} = attrs) do
    with {:ok, token} <- JumpAgent.Integrations.Hubspot.get_token(user) do
      body = %{
        properties: %{
          "email" => email,
          "firstname" => Map.get(attrs, "first_name", ""),
          "lastname" => Map.get(attrs, "last_name", ""),
          "phone" => Map.get(attrs, "phone", "")
        }
      }

      headers = [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ]

      url = "https://api.hubapi.com/crm/v3/objects/contacts"

      case HTTPoison.post(url, Jason.encode!(body), headers) do
        {:ok, %HTTPoison.Response{status_code: 201}} ->
          "✅ Contact #{email} created successfully"

        {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
          Logger.error("❌ Failed to create contact: #{body}")
          "❌ HubSpot error (#{status}): #{body}"

        {:error, reason} ->
          Logger.error("❌ HTTP error: #{inspect(reason)}")
          "❌ Failed to create contact: #{inspect(reason)}"
      end
    else
      {:error, :no_hubspot_auth} ->
        "❌ HubSpot not connected. Please authenticate first."
    end
  end
end
