defmodule Neo4jExplayground.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      Neo4jExplaygroundWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Neo4jExplayground.PubSub},
      # Start the Endpoint (http/https)
      Neo4jExplaygroundWeb.Endpoint
      # Start a worker by calling: Neo4jExplayground.Worker.start_link(arg)
      # {Neo4jExplayground.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Neo4jExplayground.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Neo4jExplaygroundWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
