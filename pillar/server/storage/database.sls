# Database details
server:
  storage:
    database:
      # PostgreSQL settings
      postgres:
        # Maximum number of clients at once
        # Mastodon backend uses scales connections with backend processes.
        # See https://docs.joinmastodon.org/admin/scaling/
        - max_connections: 100
        # Get values from https://pgtune.leopard.in.ua/
        - shared_buffers: 512MB
        - effective_cache_size: 1536MB
        - work_mem: 2621kB
        - maintenance_work_mem: 128MB
