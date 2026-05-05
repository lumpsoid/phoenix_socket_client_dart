defmodule TestServerWeb.HealthController do
  use TestServerWeb, :controller
  def check(conn, _), do: json(conn, %{status: "ok"})
end
