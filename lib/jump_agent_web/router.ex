defmodule JumpAgentWeb.Router do
  use JumpAgentWeb, :router

  import JumpAgentWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {JumpAgentWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :fetch_current_user
  end

  scope "/", JumpAgentWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/", PageController, :home
  end

  scope "/", JumpAgentWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{JumpAgentWeb.UserAuth, :ensure_authenticated}] do
      live "/chat", ChatLive, :new
      get "/logout", UserSessionController, :delete
    end
  end

  scope "/auth", JumpAgentWeb do
    pipe_through :api

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end
end
