Mastodon via Salt
=================

This takes a stock Ubuntu 22.04 system and an S3-compatible object storage provider, and with Salt, turns this into a Mastodon federated social media instance, including Let's Encrypt certificates for encrypted connections and optional GPG-encrypted offsite backup.

Currently, this requires two main deployment steps due to the complications around automating version-dependent Mastodon migrations.

*This is not endorsed by the official [Mastodon project](https://joinmastodon.org/)*

***Work in progress:** features may change without warning.  Please read the commit log before updating production systems.*

## Deployment

* Customize the files in `pillar` to suit your environment
  * See below for the minimum viable setup (e.g. local development)
* Apply the salt state via `salt-call`
  * Works with a [masterless minion Salt setup](https://docs.saltproject.io/en/latest/topics/tutorials/quickstart.html ), no need for master
* Log in to the Mastodon service user (default: `mastodon`), and run the deployment
```sh
sudo --user mastodon --login
bash
./setup-mastodon.sh
# The setup script will guide you on the interactive steps needed to configure Mastodon
```
* Copy newly generated secrets/keys into the [`pillar/server/web/app/mastodon.sls`](pillar/server/web/app/mastodon.sls) pillar file
  * These should be specific to each instance and not reused
* Re-apply the salt state via `salt-call`
  * This ensures services that could not start before are restarted

On new Mastodon releases, re-run `setup-mastodon.sh`, run migration steps [as shared on the Mastodon release notes](https://github.com/mastodon/mastodon/releases ), and restart services.

### Minimum viable setup (local development)

1. Set your server hostnames

[`pillar/server/hostnames.sls`](pillar/server/hostnames.sls):
```yaml
# Hostname details (optional/default configuration removed)
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
```

2. Set up `certbot` for Let's Encrypt certificates, or disable it

[`pillar/server/web/certbot.sls`](pillar/server/web/certbot.sls):
```yaml
# Certificate details for Let's Encrypt (optional/default configuration removed)
certbot:
  # Replace dummy certificates with certificates from Let's Encrypt?
  #
  # NOTE - enabling certbot implies you agree to the Let's Encrypt
  # Terms of Service (subscriber agreement).  Please read it first.
  # https://letsencrypt.org/repository/#let-s-encrypt-subscriber-agreement
  enable: True
  # Use staging/test server to avoid rate-limit issues?
  testing: False
  # Account details
  account:
    # Email address for recovery
    email: real-email-address@example.com
```

3. Set initial configuration for the Mastodon instance

[`pillar/server/web/app/mastodon.sls`](pillar/server/web/app/mastodon.sls):
```yaml
# Mastodon configuration (optional/default configuration removed)
server:
  web:
    app:
      # Mastodon instance configuration
      mastodon:
        # Run in single user mode?
        # See https://docs.joinmastodon.org/admin/config/#single_user_mode
        single_user_mode: False
        # Secret keys
        # Make sure to use `rake secret` to generate secrets
        secrets:
          secret_key_base: GENERATE_KEY_AFTER_DEPLOY
          otp_secret: GENERATE_OTP_AFTER_DEPLOY
        # Web push setup
        # Generate with `rake mastodon:webpush:generate_vapid_key`
        web_push:
          vapid_private_key: GENERATE_VAPID_PRIVATE_AFTER_DEPLOY
          vapid_public_key: GENERATE_VAPID_PUBLIC_AFTER_DEPLOY
        # PostgreSQL database setup
        database:
          # NOTE: Changing database username will make prior backups fail to restore
          # If database username and system username match, no password is needed, empty string ("") is fine
          password: ""
        # S3 object storage
        # See https://docs.joinmastodon.org/admin/optional/object-storage/
        object_storage:
          hostname: S3_HOSTNAME_HERE
          region: S3_REGION_HERE
          endpoint: S3_ENDPOINT_HERE
          name: mastodon-media
          access_key_id: S3_ACCESS_KEY_ID_HERE
          secret_access_key: S3_SECRET_ACCESS_KEY_HERE
        # Email notifications
        mail:
          smtp_server: mail-provider.example.com
          smtp_port: 587
          smtp_username: EXAMPLE_USER
          smtp_password: EXAMPLE_PASSWORD
          smtp_from_address: notifications@example.com

# Check the full "pillar/server/web/app/mastodon.sls" file for maintenance and further customization
```

## Usage

### Default setup

* [Mastodon](https://joinmastodon.org/) running via HTTPS on your own domain
* Connection to S3-compatible object storage with local nginx caching to reduce API calls
* Let's Encrypt for certificates with automated deployment and renewal, including reloading services
* 2 GB swapfile for low-memory systems (e.g. 1 GB RAM)
  * Initial deploy of Mastodon with asset compilation spikes memory usage

### Configuration

* Tune PostgreSQL performance (**recommended**)
  * Modify [`pillar/server/storage/database.sls`](pillar/server/storage/database.sls) according to your system specifications.

* Enable automatic Mastodon maintenance tasks (**recommended**)
  * Modify [`pillar/server/web/app/mastodon.sls`](pillar/server/web/app/mastodon.sls) to enable the various tasks underneath `maintenance:`
  * Set your `Media cache retention period` in your Mastodon server's Administration interface

### Extra features

#### Increase post and/or profile bio length limits
* Allows for writing long posts and descriptions on your bio
* Might break with Mastodon updates

[`pillar/server/web/app/mastodon.sls`](pillar/server/web/app/mastodon.sls):
```yaml
# Mastodon configuration
server:
  web:
    app:
      # Mastodon instance configuration
      mastodon:
        # [...existing configuration here...]
        #
        # Advanced instance customization
        instance_config:
          accounts:
            max_bio_characters: 500
            # Max characters for user profile bio (remove this for upstream default)
          statuses:
            max_characters: 500
            # Max characters per post (remove this for upstream default)
```

#### Report system status via Telegraf to a remote metrics server
* Configure [`pillar/server/metrics.sls`](pillar/server/metrics.sls) with metrics server details
* Example receiving setup: Grafana + Telegraf HTTP Listener + InfluxDB

#### Set up daily automatic, PGP-encrypted backups
* Configure [`pillar/common/backup/system.sls`](pillar/common/backup/system.sls) and (optionally) [`rclone-archive.sls`](pillar/common/backup/rclone-archive.sls) with upload script and encryption settings
  * Example script given for use with [rclone](https://rclone.org/), enabling backup to many cloud/self-hosted services

## Credits

* [Mastodon](https://github.com/mastodon/mastodon) for the federated social media server
* Inspiration from the [Mastodon Ansible playbook](https://github.com/mastodon/mastodon-ansible ) and the [Terraform/Ansible setup for Oracle Cloud](https://github.com/faevourite/mastodon-oracle-cloud-free-tier )
* *Some credits in the individual files, too*
* *If you're missing, let me know, and I'll fix it as soon as I can!*
