defmodule TestServerWeb.OkChannel do
  use Phoenix.Channel

  def join("ok:" <> _room, _params, socket) do
    {:ok, %{status: "joined"}, socket}
  end

  def handle_in("event:ok", payload, socket) do
    {:reply, {:ok, %{echo: payload}}, socket}
  end

  def handle_in("event:no_reply", _payload, socket) do
    {:noreply, socket}
  end

  def handle_in("event:error", _payload, socket) do
    {:reply, {:error, %{reason: "something_wrong"}}, socket}
  end

  def handle_in("event:raise", _payload, _socket) do
    raise "intentional channel crash"
  end

  def handle_in("event:server_push", _payload, socket) do
    push(socket, "server:event", %{message: "pushed from server"})
    {:noreply, socket}
  end
end
