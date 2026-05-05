defmodule TestServerWeb.UserSocket do
  use Phoenix.Socket

  channel "ok:*",     TestServerWeb.OkChannel
  channel "reject:*", TestServerWeb.RejectChannel
  channel "error:*",  TestServerWeb.ErrorChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
