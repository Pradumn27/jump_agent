defmodule JumpAgent.Integrations.Hubspot do
  alias JumpAgent.Knowledge
  alias JumpAgent.Accounts
  alias JumpAgent.Knowledge.Context
  import Ecto.Query, warn: false
  require Logger

  @hubspot_base "https://api.hubapi.com"
  @contacts_endpoint "/crm/v3/objects/contacts"
  @notes_endpoint "/crm/v3/objects/notes"

  def sync_contacts(user) do
    with {:ok, token} <- get_token(user),
         {:ok, contacts} <- fetch_contacts(token) do
      Enum.each(contacts, fn contact ->
        store_contact_context(user, contact)
      end)

      {:ok, :synced}
    else
      error -> {:error, error}
    end
  end

  def sync_notes(user) do
    with {:ok, token} <- get_token(user),
         {:ok, notes} <- fetch_notes(token) do
      Enum.each(notes, fn note ->
        store_note_context(user, note)
      end)

      {:ok, :synced}
    else
      error -> {:error, error}
    end
  end

  defp get_token(user) do
    case Accounts.get_auth_identity(user, "hubspot") do
      %{token: token, refresh_token: refresh_token, expires_at: expires_at} = identity ->
        if expired?(expires_at) do
          case JumpAgent.OAuth.Hubspot.refresh_token(refresh_token) do
            {:ok,
             %{
               "access_token" => new_token,
               "expires_in" => expires_in,
               "refresh_token" => new_refresh_token,
               "token_type" => _token_type
             }} ->
              new_expires_at = DateTime.add(DateTime.utc_now(), expires_in)
              # Update the stored token
              Accounts.update_auth_identity(identity, %{
                token: new_token,
                expires_at: new_expires_at,
                refresh_token: new_refresh_token
              })

              {:ok, new_token}

            {:error, reason} ->
              Logger.error("Failed to refresh HubSpot token: #{inspect(reason)}")
              {:error, :token_refresh_failed}
          end
        else
          {:ok, token}
        end

      _ ->
        {:error, :no_hubspot_auth}
    end
  end

  defp expired?(datetime) do
    DateTime.compare(datetime, DateTime.utc_now()) == :lt
  end

  defp fetch_contacts(token) do
    url =
      @hubspot_base <>
        @contacts_endpoint <> "?limit=100&properties=firstname,lastname,email,phone"

    headers = [{"Authorization", "Bearer #{token}"}, {"Content-Type", "application/json"}]

    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        %{"results" => results} = Jason.decode!(body)
        {:ok, results}

      {:ok, %{status_code: code, body: body}} ->
        {:error, {code, body}}

      {:error, err} ->
        {:error, err}
    end
  end

  defp fetch_notes(token) do
    url = @hubspot_base <> @notes_endpoint <> "?limit=100&properties=hs_note_body"

    headers = [{"Authorization", "Bearer #{token}"}, {"Content-Type", "application/json"}]

    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        %{"results" => results} = Jason.decode!(body)
        {:ok, results}

      {:ok, %{status_code: code, body: body}} ->
        {:error, {code, body}}

      {:error, err} ->
        {:error, err}
    end
  end

  defp store_contact_context(user, contact) do
    props = contact["properties"] || %{}

    content = """
    Contact Name: #{props["firstname"]} #{props["lastname"]}
    Email: #{props["email"]}
    Phone: #{props["phone"]}
    Contact ID: #{contact["id"]}
    """

    Knowledge.create_context(%{
      source: "hubspot_contact",
      source_id: contact["id"],
      content: content,
      metadata: props,
      user_id: user.id
    })
  end

  defp store_note_context(user, note) do
    content = """
    Note ID: #{note["id"]}
    Note:
    #{note["properties"]["hs_note_body"]}
    """

    Knowledge.create_context(%{
      source: "hubspot_note",
      source_id: note["id"],
      content: content,
      metadata: note["properties"],
      user_id: user.id
    })
  end

  def disconnect_hubspot(user) do
    with {:ok, _} <- Accounts.disconnect_auth_identity(user, "hubspot"),
         {:ok, _} <- delete_hubspot_contexts(user) do
      {:ok, :disconnected}
    else
      error -> {:error, error}
    end
  end

  defp delete_hubspot_contexts(user) do
    sources = ["hubspot_contact", "hubspot_note"]

    from(c in Context, where: c.user_id == ^user.id and c.source in ^sources)
    |> JumpAgent.Repo.delete_all()
    |> case do
      {count, _} -> {:ok, count}
      _ -> {:error, :deletion_failed}
    end
  end

  def create_contact(user, %{"email" => email} = attrs) do
    with {:ok, token} <- get_token(user) do
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

  def update_contact(user, %{"contact_id" => contact_id} = attrs) do
    with {:ok, token} <- get_token(user) do
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

  def create_note(user, %{"contact_id" => contact_id, "note" => note_content}) do
    with {:ok, token} <- get_token(user) do
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

  def update_note(user, %{"note_id" => note_id, "body" => new_body}) do
    with {:ok, token} <- get_token(user) do
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
