defmodule HexWeb.API.OwnerController do
  use HexWeb.Web, :controller

  plug :fetch_package
  plug :authorize, fun: &package_owner?/2

  def index(conn, _params) do
    owners = assoc(conn.assigns.package, :owners) |> HexWeb.Repo.all
    conn
    |> api_cache(:private)
    |> render(:index, owners: owners)
  end

  def show(conn, %{"email" => email}) do
    email = URI.decode_www_form(email)
    owner = HexWeb.Repo.get_by!(User, email: email)

    if package_owner?(conn.assigns.package, owner) do
      conn
      |> api_cache(:private)
      |> send_resp(204, "")
    else
      not_found(conn)
    end
  end

  def create(conn, %{"email" => email}) do
    email = URI.decode_www_form(email)
    user = HexWeb.Repo.get_by!(User, email: email)
    package = conn.assigns.package

    Package.create_owner(package, user) |> HexWeb.Repo.insert!
    owners = assoc(package, :owners) |> HexWeb.Repo.all

    HexWeb.Mailer.send(
      "owner_add.html",
      "Hex.pm - Owner added",
      Enum.map(owners, fn owner -> owner.email end),
      username: user.username,
      email: email,
      package: package.name)

    conn
    |> api_cache(:private)
    |> send_resp(204, "")
  end

  def delete(conn, %{"email" => email}) do
    email = URI.decode_www_form(email)
    owner = HexWeb.Repo.get_by!(User, email: email)
    package = conn.assigns.package
    owners = assoc(package, :owners) |> HexWeb.Repo.all

    if length(owners) == 1 do
      conn
      |> api_cache(:private)
      |> send_resp(403, "")
    else
      Package.owner(package, owner)
      |> HexWeb.Repo.delete_all

      HexWeb.Mailer.send(
        "owner_remove.html",
        "Hex.pm - Owner removed",
        Enum.map(owners, fn owner -> owner.email end),
        username: owner.username,
        email: email,
        package: package.name)

      conn
      |> api_cache(:private)
      |> send_resp(204, "")
    end
  end
end
