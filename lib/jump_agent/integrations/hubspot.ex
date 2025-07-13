defmodule JumpAgent.Integrations.Hubspot do
  alias JumpAgent.Knowledge
  alias JumpAgent.Accounts
  alias JumpAgent.Knowledge.Context
  import Ecto.Query, warn: false
  require Logger

  @hubspot_base "https://api.hubapi.com"
  @contacts_endpoint "/crm/v3/objects/contacts"
  @notes_endpoint "/crm/v3/objects/notes"

  def sync_contacts(user, max_results \\ 100) do
    with {:ok, token} <- get_token(user),
         {:ok, contacts} <- fetch_contacts(token, max_results) do
      Enum.each(contacts, fn contact ->
        store_contact_context(user, contact)
      end)

      {:ok, :synced}
    else
      error -> {:error, error}
    end
  end

  def sync_notes(user, max_results \\ 100) do
    with {:ok, token} <- get_token(user),
         {:ok, notes} <- fetch_notes(token, max_results) do
      Enum.each(notes, fn note ->
        store_note_context(user, note)
      end)

      {:ok, :synced}
    else
      error -> {:error, error}
    end
  end

  def get_token(user) do
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

  defp fetch_contacts(token, max_results) do
    url =
      @hubspot_base <>
        @contacts_endpoint <> "?limit=#{max_results}&properties=firstname,lastname,email,phone"

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

  defp fetch_notes(token, max_results) do
    url = @hubspot_base <> @notes_endpoint <> "?limit=#{max_results}&properties=hs_note_body"

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
end
