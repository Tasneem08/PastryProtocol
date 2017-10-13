# web/models/user.ex
defmodule Project3.User do
    use Project3.Web, :model
  schema "users" do
    field :name, :string
    field :email, :string
    field :password, :string
    field :stooge, :string
    timestamps
  end
end