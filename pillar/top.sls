# Apply to all (since we only have one machine)
base:
  '*':
    - common.backup.rclone-archive
    - common.backup.system
    - server.hostnames
    - server.metrics
    - server.remote.ssh
    - server.storage.database
    - server.system
    - server.web.app.mastodon
    - server.web.certbot
    - server.web.well-known-aliases
