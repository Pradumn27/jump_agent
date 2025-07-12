defmodule JumpAgent.Integrations.Hubspot do
  alias JumpAgent.Knowledge
  alias JumpAgent.Accounts
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
      %{token: token} ->
        {:ok, token}

      _ ->
        {:error, :no_hubspot_auth}
    end
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
end
