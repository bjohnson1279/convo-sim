FROM elixir:1.18

# Install hex and rebar (Elixir's package manager and build tool)
RUN mix local.hex --force && \
    mix local.rebar --force

# Install the Phoenix project generator
RUN mix archive.install hex phx_new --force

# inotify-tools for live reload in the dev server
RUN apt-get update && apt-get install -y inotify-tools && rm -rf /var/lib/apt/lists/*

WORKDIR /app

EXPOSE 4000

# Default command: start Phoenix dev server, binding to 0.0.0.0 so it's
# accessible from the host through the Docker port mapping
CMD ["mix", "phx.server"]
