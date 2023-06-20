# Remote details
server:
  remote:
    ssh:
      # Set to true to allow configuring SSH.  Disabled by default to avoid
      # unintentionally locking oneself out.
      allow-configuring-this-is-correct: False
      # Allow password authentication
      allow-pass: False
      # Custom SSH port
      custom-port:
        enable: False
        port: 1234
      # Additional authorized accounts
      #
      # NOTE - Removing accounts from this list does not deauthorize them.
      # Clear ssh_keys to disable an account.
      #
      # NOTE - This does not create any account.  It merely adds additional
      # authorized_keys.  Additional users with keys may be added by other
      # pillar files.
      additional-accounts:
        # User account
        example-user:
          # User name
          username: example
          # Whether or not to restrict to file transfers only (no commands)
          restrict_transfer_only: False
          # SSH keys
          ssh_keys:
            - "ssh-rsa [example]== user@host # comment"
