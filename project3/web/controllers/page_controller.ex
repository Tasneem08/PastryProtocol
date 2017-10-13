defmodule Project3.PageController do
  use Project3.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
