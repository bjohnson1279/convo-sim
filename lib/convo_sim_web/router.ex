defmodule ConvoSimWeb.Router do
  use ConvoSimWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ConvoSimWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self' ws: wss:;"
    }
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ConvoSimWeb do
    pipe_through :browser

    live "/", DashboardLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", ConvoSimWeb do
  #   pipe_through :api
  # end
end
