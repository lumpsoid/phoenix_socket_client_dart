defmodule TestServerWeb.Router do
  use TestServerWeb, :router

  # No pipelines needed
  # No routes needed
  # Channels are mounted on the socket in endpoint.ex directly

  scope "/", TestServerWeb do
    get "/health", HealthController, :check
  end
end
