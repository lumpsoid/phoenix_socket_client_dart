# lib/test_server_web/channels/reject_channel.ex
defmodule TestServerWeb.RejectChannel do
  use Phoenix.Channel

  def join("reject:forbidden", _params, _socket) do
    {:error, %{reason: "forbidden"}}
  end

  def join("reject:" <> _room, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end
end
