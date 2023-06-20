# Apply to all (since we only have one machine)
base:
  '*':
    # Activate swap first if enabled to avoid out-of-memory conditions
    - common.swapfile
    # Run backups
    - common.backup.rclone-archive
    - common.backup.system
    # Interactive administration
    - server.admin.tools
    # Remote administration
    - server.remote.mosh
    - server.remote.ssh
    # Optional status reporting
    - server.metrics.top
    # Mastodon
    - server.web.app.mastodon
    # Certbot
    - server.web.certbot
    # Website
    - server.web.files
    - server.web.main
