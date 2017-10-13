defmodule Project3.Router do
  use Project3.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # scope "/", Project3 do
  #   pipe_through :browser # Use the default browser stack

  #   get "/", PageController, :index
  # end

  # Other scopes may use custom stacks.
  scope "/api", Project3 do
    pipe_through :api
    get "/users", UserController, :index
    get "/user/:id", UserController, :show
  end
end
