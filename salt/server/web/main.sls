# Main site

{% set masto_user = salt['pillar.get']('server:web:app:mastodon:username', 'mastodon') %}
{% set masto_home_dir = '/srv' | path_join(masto_user) %}
{% set masto_work_dir = masto_home_dir | path_join('mastodon_root') %}
{% set masto_repo_parent_dir = masto_work_dir | path_join('masto') %}
{% set masto_repo_dir = masto_repo_parent_dir | path_join('mastodon') %}
# This ALSO applies to web/app/mastodon.sls!

include:
  # Require webserver, etc to be installed first
  - .webserver
  # Ensure deploy hook is created before certbot deploys
  - .certbot

web.main.nginx.config.site:
  file.managed:
    - name: /etc/nginx/sites-available/main
    - source: salt://files/server/web/main/nginx/sites/main
    - template: jinja
    - context:
        masto_repo_dir: "{{ masto_repo_dir }}"
    - makedirs: True
    - watch_in:
      - service: nginx

web.main.nginx.config.enable:
  file.symlink:
    - name: /etc/nginx/sites-enabled/main
    - target: /etc/nginx/sites-available/main
    - makedirs: True
    # Install nginx first
    - require:
      - pkg: nginx
    - watch_in:
      - service: nginx

web.main.nginx.config.includes:
  file.recurse:
    - name: /etc/nginx/includes/main
    - source: salt://files/server/web/main/nginx/includes
    # Templating is needed for domains
    - template: jinja
    - makedirs: True
    - clean: True
    - watch_in:
      - service: nginx

# Set up nginx cache path
web.main.nginx.config.cache.parent:
  file.directory:
    - name: /var/cache/nginx/
    # Don't allow global access to cache
    - user: root
    - group: www-data
    - mode: 750
    - watch_in:
      - service: nginx

web.main.nginx.config.cache.dir:
  file.directory:
    - name: /var/cache/nginx/masto-main
    # Read/write, don't allow global access to cache
    - user: www-data
    - group: www-data
    - mode: 750
    - watch_in:
      - service: nginx

# Ensure SSL dhparams exists
web.main.nginx.config.dhparams:
  file.directory:
    - name: /etc/nginx/dhparam
    # Don't allow global access to the DH params
    - user: root
    - group: www-data
    - mode: 750
  cmd.run:
    - name: openssl dhparam -out /etc/nginx/dhparam/cert-primary.pem 2048
    - creates: /etc/nginx/dhparam/cert-primary.pem
    - require:
      - file: web.main.nginx.config.dhparams
    - watch_in:
      - service: nginx

# ---
# Ensure there's some form of SSL certificate in place
# This will get replaced when certbot is set up
# Disable replacing existing files, don't overwrite a potentially-valid cert
#
# Only if dummy certs are added, store an indication that these are the dummy certificates.
web.main.nginx.config.dummy_certs.marker:
  file.managed:
    - name: /etc/letsencrypt/live/cert-primary/is_dummy_certs
    - replace: False
    - makedirs: True
    # Only add if changes are made, and set in place first
    # Avoids race condition with certbot-setup running on dummy certs
    - prereq:
      - file: web.main.nginx.config.dummy_certs.cert
      - file: web.main.nginx.config.dummy_certs.fullcert
      - file: web.main.nginx.config.dummy_certs.privkey
web.main.nginx.config.dummy_certs.cert:
  file.managed:
    - name: /etc/letsencrypt/live/cert-primary/chain.pem
    - source: salt://files/server/certbot/dummy_certs/cert.pem
    - replace: False
    - makedirs: True
    - require_in:
      - service: nginx
web.main.nginx.config.dummy_certs.fullcert:
  file.managed:
    - name: /etc/letsencrypt/live/cert-primary/fullchain.pem
    - source: salt://files/server/certbot/dummy_certs/cert.pem
    - replace: False
    - makedirs: True
    - require_in:
      - service: nginx
web.main.nginx.config.dummy_certs.privkey:
  file.managed:
    - name: /etc/letsencrypt/live/cert-primary/privkey.pem
    - source: salt://files/server/certbot/dummy_certs/privkey.pem
    - replace: False
    - makedirs: True
    - require_in:
      - service: nginx

# Don't try to clean these up!  Let's Encrypt may put other files in these
# folders and automatically removing private keys is asking for trouble.
# ---
#
# Set up deploy hook to reload on changes
{% if salt['pillar.get']('certbot:enable', False) == True %}
web.main.nginx.config.certbot:
  file.managed:
    - name: /root/salt/certbot/cert/cert-primary/renewal-hooks-deploy/nginx-reload
    - source: salt://files/server/web/nginx-reload
    - makedirs: True
    # Mark as executable
    - mode: 755
    - watch_in:
      - cmd: certbot.configure
{% endif %}

# Set up main site
# [no local files]
