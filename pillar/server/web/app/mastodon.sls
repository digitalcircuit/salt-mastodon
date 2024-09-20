# Mastodon configuration
server:
  web:
    app:
      # Mastodon instance configuration
      mastodon:
        # NOT USED - auto-upgrading Mastodon is complicated
        # See "setup-mastodon.sh" as deployed by "mastodon.sls"
        #version:
        #  revision: HEAD
        #  branch: main
        # ----

        # Deploy unstable, not-yet-finished releases of Mastodon?
        # Be ready for things to break!
        # Do not set to false if you are currently running a beta/release-candidate.
        use_unstable_versions: False
        # Configure your domain name (LOCAL_DOMAIN) in "hostnames.sls"
        #
        # System username Mastodon uses
        # This is NOT the Mastodon login username
        username: mastodon
        # Run in single user mode?
        # See https://docs.joinmastodon.org/admin/config/#single_user_mode
        single_user_mode: False
        # Secret keys
        # Make sure to use `bundle exec rails secret` to generate secrets
        secrets:
          secret_key_base: GENERATE_KEY_AFTER_DEPLOY
          otp_secret: GENERATE_OTP_AFTER_DEPLOY
          active_record:
            encryption_deterministic_key: GENERATE_AR_DETER_AFTER_DEPLOY
            encryption_key_derivation_salt: GENERATE_AR_KEYDERIV_AFTER_DEPLOY
            encryption_primary_key: GENERATE_AR_PRIMKEY_AFTER_DEPLOY
        # Web push setup
        # Generate with `bundle exec rails mastodon:webpush:generate_vapid_key`
        web_push:
          vapid_private_key: GENERATE_VAPID_PRIVATE_AFTER_DEPLOY
          vapid_public_key: GENERATE_VAPID_PUBLIC_AFTER_DEPLOY
        # PostgreSQL database setup
        database:
          name: mastodon_production
          username: mastodon
          # NOTE: Changing database username will make prior backups fail to restore
          # If database username and system username match, no password is needed, empty string ("") is fine
          password: CHANGE_THIS_DATABASE_PASSWORD
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
        # Advanced instance customization
        instance_config:
          accounts:
            max_bio_characters: 500
            # Max characters for user profile bio (remove this for upstream default)
          statuses:
            max_characters: 500
            # Max characters per post (remove this for upstream default)
        # Optional maintenance tasks
        maintenance:
          # weekly: Runs "tootctl accounts prune"
          # See https://docs.joinmastodon.org/admin/tootctl/#accounts-prune
          cleanup-accounts-prune: False
          # weekly: Runs "tootctl media remove --prune-profiles"
          # See https://docs.joinmastodon.org/admin/tootctl/#media-remove
          cleanup-media-profiles: False
          # monthly: Runs "tootctl media remove-orphans"
          # WARNING: This may be expensive due to object storage APIs used
          # See https://docs.joinmastodon.org/admin/tootctl/#media-remove-orphans
          cleanup-media-orphans: False
          # monthly: Runs "tootctl statuses remove"
          # NOTE: This is CPU intensive
          # See https://docs.joinmastodon.org/admin/tootctl/#statuses-remove
          cleanup-statuses-orphans: False
          # monthly: Runs "tootctl preview_cards remove"
          # WARNING: Preview cards will not be refetched once removed
          # See https://docs.joinmastodon.org/admin/tootctl/#preview_cards-remove
          cleanup-preview-cards: False
