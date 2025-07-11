defmodule JumpAgentWeb.AuthController do
  use JumpAgentWeb, :controller
  plug Ueberauth

  require Logger
  alias JumpAgentWeb.UserAuth
  alias JumpAgent.Accounts

  def request(%{path_params: %{"provider" => "hubspot"}} = conn, _params) do
    config = Application.get_env(:jump_agent, :hubspot)

    url =
      "https://app.hubspot.com/oauth/authorize?" <>
        URI.encode_query(%{
          client_id: config[:client_id],
          redirect_uri: config[:redirect_uri],
          scope: "oauth crm.objects.contacts.read crm.objects.contacts.write",
          response_type: "code"
        })

    redirect(conn, external: url)
  end

  # Default for Ueberauth (Google etc.)
  def request(conn, _params), do: conn

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    email = auth.info.email

    case Accounts.get_user_by_email(email) do
      nil ->
        # User does not exist, so create a new user
        user_params = %{
          token: auth.credentials.token,
          refresh_token: auth.credentials.refresh_token,
          email: auth.info.email,
          name: auth.info.first_name <> " " <> auth.info.last_name,
          expires_at: DateTime.from_unix!(auth.credentials.expires_at)
        }

        case Accounts.register_oauth_user(user_params) do
          {:ok, user} ->
            UserAuth.log_in_user(conn, user)

          {:error, changeset} ->
            Logger.error("Failed to create user #{inspect(changeset)}.")

            conn
            |> redirect(to: ~p"/")
        end

      user ->
        # User exists, update session or other details if necessary
        UserAuth.log_in_user(conn, user)
    end
  end

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, _params) do
    IO.inspect(fails)

    conn
    |> put_flash(:error, "Google Auth failed")
    |> redirect(to: "/")
  end

  def callback(
        %{params: %{"code" => code}, path_params: %{"provider" => "hubspot"}} = conn,
        _params
      ) do
    config = Application.get_env(:jump_agent, :hubspot)

    body =
      URI.encode_query(%{
        grant_type: "authorization_code",
        client_id: config[:client_id],
        client_secret: config[:client_secret],
        redirect_uri: config[:redirect_uri],
        code: code
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://api.hubapi.com/oauth/v1/token", body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: raw_body}} ->
        with {:ok,
              %{
                "access_token" => access_token,
                "refresh_token" => refresh_token,
                "expires_in" => expires
              }} <- Jason.decode(raw_body) do
          expires_at = DateTime.utc_now() |> DateTime.add(expires)

          current_user = conn.assigns.current_user

          JumpAgent.Accounts.link_auth_identity(current_user, %{
            token: access_token,
            refresh_token: refresh_token,
            expires_at: expires_at,
            provider: "hubspot",
            user_id: current_user.email
          })

          conn
          |> put_flash(:info, "Connected to HubSpot!")
          |> redirect(to: "/")
        else
          _ ->
            conn |> put_flash(:error, "Failed to decode token response") |> redirect(to: "/")
        end

      {:ok, resp} ->
        IO.inspect(resp, label: "Unexpected HubSpot response")
        conn |> put_flash(:error, "HubSpot login failed") |> redirect(to: "/")

      {:error, err} ->
        IO.inspect(err, label: "HTTP error")
        conn |> put_flash(:error, "HubSpot login failed") |> redirect(to: "/")
    end
  end
end
