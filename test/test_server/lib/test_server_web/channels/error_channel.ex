defmodule TestServerWeb.ErrorChannel do
  use Phoenix.Channel

  def join("error:crash", _params, _socket) do
    raise "crash on join"
  end

  def join("error:slow", _params, socket) do
    Process.sleep(5_000)
    {:ok, socket}
  end
end
