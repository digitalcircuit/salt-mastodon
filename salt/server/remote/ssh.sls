# SSH customization

# Always provide the only-data-allowed-commands script

ssh.restrict_cmds:
  file.managed:
    - name: /usr/share/sys-scripts/only-data-allowed-commands.sh
    - source: salt://files/server/remote/ssh/only-data-allowed-commands.sh
    - makedirs: True
    - mode: 755

# Only apply configuration if enabled
{% if salt['pillar.get']('server:remote:ssh:allow-configuring-this-is-correct', False) == True %}

ssh.config.passwd_auth:
  file.line:
    - name: /etc/ssh/sshd_config
    - mode: replace
{% if salt['pillar.get']('server:remote:ssh:allow-pass', True) == True %}
    # Enable password auth
    - content: "PasswordAuthentication yes # Edited by SaltStack"
{% else %}
    # Disable password auth
    - content: "PasswordAuthentication no # Edited by SaltStack"
{% endif %}
    - match: .?PasswordAuthentication\s.*
    - watch_in:
      - service: ssh

{% if salt['pillar.get']('server:remote:ssh:custom-port:enable', False) == True %}
ssh.config.port:
  file.line:
    - name: /etc/ssh/sshd_config
    - mode: replace
    - content: "Port {{ salt['pillar.get']('server:remote:ssh:custom-port:port', '22') }} # Edited by SaltStack"
    - match: .?Port\s.*
    - watch_in:
      - service: ssh
{% endif %}

{% set SSH_AUTH_DIR = '/etc/ssh/authorized_keys' %}

ssh.config.authorized_keys.location:
  file.line:
    - name: /etc/ssh/sshd_config
    - mode: replace
    - content: "AuthorizedKeysFile {{ SSH_AUTH_DIR }}/%u # Edited by SaltStack"
    # Default is #AuthorizedKeysFile	.ssh/authorized_keys .ssh/authorized_keys2
    - match: .?AuthorizedKeysFile\s.*
    - require:
      - file: ssh.data.authorized_keys.storage
    - watch_in:
      - service: ssh

ssh.data.authorized_keys.storage:
  # Create SSH directory
  file.directory:
    - name: {{ SSH_AUTH_DIR }}
    - user: root
    - group: root
    # SSH user needs access for SSH to read authorized keys
    - dir_mode: 755

{% for ACCOUNT, args in salt['pillar.get']('server:remote:ssh:additional-accounts', {}).items() %}

{% set SSH_USER_NAME = args.username %}

ssh.data.authorized_keys.{{ ACCOUNT }}.keys:
  # Manage SSH directory
  file.managed:
    - name: {{ SSH_AUTH_DIR | path_join(SSH_USER_NAME) }}
    - source: salt://files/server/remote/ssh/authorized_keys_template
    # Templating is needed for SSH key manipulation
    - template: jinja
    - context:
        restrict_transfer_only: {{ args.get('restrict_transfer_only', False) }}
        ssh_keys:
{% for key in args.ssh_keys %}
          - "{{ key }}"
{% endfor %}
    # SSH user needs access for SSH to read authorized keys
    - user: {{ SSH_USER_NAME }}
    - group: root
    - mode: 440

{% endfor %}

{% endif %}

ssh:
  service.running:
    - name: sshd
    - enable: True
    ## Reloading is okay
    #- reload_ True
    # Reloading actually seems to not apply all changes
