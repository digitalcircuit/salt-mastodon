# Hostname details
server:
  # Hostnames
  hostnames:
    # Domains by certificate chain
    # Main domain
    cert-primary:
      # Hostname visible to the world, used in SSL certs and branding
      # /!\ ---------------------------
      # WARNING: This identifies your server and cannot be changed safely later
      # See Mastodon documentation on "LOCAL_DOMAIN"
      # -------------------------------
      root: public.domain.here.example.com
      # Hostname used for files/proxying S3 object storage
      # /!\ ---------------------------
      # WARNING: This identifies media on your server and changing it will break past uploads
      # See Mastodon documentation on "S3_ALIAS_HOST"
      # -------------------------------
      files: files.public.domain.here.example.com
      # Additional domains may be added like this
      # friendly-name: subdomain.example.com
      # friendly-name-2: other.domain.invalid
    # Additional certificate chains may be added like this
    #cert-additional:
    #  root: example.invalid
