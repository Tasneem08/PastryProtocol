defmodule Project3.UserController do
  use Project3.Web, :controller

  def index(conn, _params) do
  users = Repo.all(Project3.User)
    json conn, users
  end

    def show(conn, %{"id" => id}) do
  users = Repo.get(Project3.User, String.to_integer(id))
    json conn, users
  end
end
