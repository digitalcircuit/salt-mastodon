# Media proxy site

include:
  # Require webserver, etc to be installed first
  - .webserver
  # Ensure deploy hook is created before certbot deploys
  - .certbot

web.files.nginx.config.site:
  file.managed:
    - name: /etc/nginx/sites-available/files
    - source: salt://files/server/web/files/nginx/sites/files
    - template: jinja
    - makedirs: True
    - watch_in:
      - service: nginx

web.files.nginx.config.enable:
  file.symlink:
    - name: /etc/nginx/sites-enabled/files
    - target: /etc/nginx/sites-available/files
    - makedirs: True
    # Install nginx first
    - require:
      - pkg: nginx
    - watch_in:
      - service: nginx

web.files.nginx.config.includes:
  file.recurse:
    - name: /etc/nginx/includes/files
    - source: salt://files/server/web/files/nginx/includes
    # Templating is needed for domains
    - template: jinja
    - makedirs: True
    - clean: True
    - watch_in:
      - service: nginx

# Set up nginx cache path
web.files.nginx.config.cache.parent:
  file.directory:
    - name: /var/cache/nginx/
    # Don't allow global access to cache
    - user: root
    - group: www-data
    - mode: 750
    - watch_in:
      - service: nginx

web.files.nginx.config.cache.dir:
  file.directory:
    - name: /var/cache/nginx/masto-files
    # Read/write, don't allow global access to cache
    - user: www-data
    - group: www-data
    - mode: 750
    - watch_in:
      - service: nginx

web.files.nginx.config.cache.enable:
  file.symlink:
    - name: /etc/nginx/conf.d/files-masto_s3_media-cache.conf
    - target: /etc/nginx/includes/files/proxy/masto_s3_media/cache
    - makedirs: True
    # Install nginx first
    - require:
      - pkg: nginx
    - watch_in:
      - service: nginx

# Ensure SSL dhparams exists
web.files.nginx.config.dhparams:
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
      - file: web.files.nginx.config.dhparams
    - watch_in:
      - service: nginx

# ---
# Ensure there's some form of SSL certificate in place
# This will get replaced when certbot is set up
# Disable replacing existing files, don't overwrite a potentially-valid cert
#
# Only if dummy certs are added, store an indication that these are the dummy certificates.
web.files.nginx.config.dummy_certs.marker:
  file.managed:
    - name: /etc/letsencrypt/live/cert-primary/is_dummy_certs
    - replace: False
    - makedirs: True
    # Only add if changes are made, and set in place first
    # Avoids race condition with certbot-setup running on dummy certs
    - prereq:
      - file: web.files.nginx.config.dummy_certs.cert
      - file: web.files.nginx.config.dummy_certs.fullcert
      - file: web.files.nginx.config.dummy_certs.privkey
web.files.nginx.config.dummy_certs.cert:
  file.managed:
    - name: /etc/letsencrypt/live/cert-primary/chain.pem
    - source: salt://files/server/certbot/dummy_certs/cert.pem
    - replace: False
    - makedirs: True
    - require_in:
      - service: nginx
web.files.nginx.config.dummy_certs.fullcert:
  file.managed:
    - name: /etc/letsencrypt/live/cert-primary/fullchain.pem
    - source: salt://files/server/certbot/dummy_certs/cert.pem
    - replace: False
    - makedirs: True
    - require_in:
      - service: nginx
web.files.nginx.config.dummy_certs.privkey:
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
web.files.nginx.config.certbot:
  file.managed:
    - name: /root/salt/certbot/cert/cert-primary/renewal-hooks-deploy/nginx-reload
    - source: salt://files/server/web/nginx-reload
    - makedirs: True
    # Mark as executable
    - mode: 755
    - watch_in:
      - cmd: certbot.configure
{% endif %}

# Set up files site
# [no local files]
