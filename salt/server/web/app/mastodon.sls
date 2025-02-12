# Mastodon

{% set masto_user = salt['pillar.get']('server:web:app:mastodon:username', 'mastodon') %}
{% set masto_home_dir = '/srv' | path_join(masto_user) %}
{% set masto_work_dir = masto_home_dir | path_join('mastodon_root') %}
{% set masto_repo_parent_dir = masto_work_dir | path_join('masto') %}
{% set masto_repo_dir = masto_repo_parent_dir | path_join('mastodon') %}
# This ALSO applies to web/main.sls!

{% set masto_status_char_limit_upstream = 500 %}
{% set masto_bio_char_limit_upstream = 500 %}
{% set masto_status_char_limit = salt['pillar.get']('server:web:app:mastodon:instance_config:statuses:max_characters', masto_status_char_limit_upstream) %}
{% set masto_bio_char_limit = salt['pillar.get']('server:web:app:mastodon:instance_config:accounts:max_bio_characters', masto_bio_char_limit_upstream) %}

{% set masto_libvips_minver = '8.13' %}
{% set masto_libvips_distver = salt['pkg.list_repo_pkgs']('libvips-tools')['libvips-tools'] |first() %}
{% set masto_libvips_distver_new_enough = (salt['pkg.version_cmp'](masto_libvips_distver, masto_libvips_minver) >= 0) %}

# Require NodeJS and database to be installed first
include:
  - common.nodejs
  - server.storage.database
{% if salt['pillar.get']('common:backup:system:enable', False) == True %}
  # For backup module
  - common.backup.system
{% endif %}

server.web.app.mastodon.dependencies:
  pkg.installed:
    - pkgs:
      # From https://docs.joinmastodon.org/admin/install/#system-repositories
      - curl
      - wget
      - gnupg
      - apt-transport-https
      - lsb-release
      - ca-certificates
      # From https://docs.joinmastodon.org/admin/install/#system-packages
      - imagemagick
      - ffmpeg
{% if masto_libvips_distver_new_enough == True %}
      - libvips-tools
{% endif %}
      - libpq-dev
      - libxml2-dev
      - libxslt1-dev
      - file
      #- git-core - virtual package, select "git" instead
      - git
      - g++
      - libprotobuf-dev
      - protobuf-compiler
      - pkg-config
      #- nodejs
      - gcc
      - autoconf
      - bison
      - build-essential
      - libssl-dev
      - libyaml-dev
      #- libreadline6-dev - virtual package, select "libreadline-dev" instead
      - libreadline-dev
      - zlib1g-dev
      - libncurses-dev
      - libffi-dev
      - libgdbm-dev
      #- nginx
      - redis-server
      - redis-tools
      #- postgresql
      #- postgresql-contrib
      #- certbot
      #- python3-certbot-nginx
      - libidn11-dev
      - libicu-dev
      - libjemalloc-dev
      # For Salt to download repo
      - python3-git
    - require:
      # Require NodeJS
      - sls: 'common.nodejs'

# Stop the service if running and changes will be made
server.web.app.mastodon.user-basic.stop-for-changes.web:
  service.dead:
    - name: mastodon-web
    - prereq:
      # Stop service before making changes
      - user: server.web.app.mastodon.user-basic
server.web.app.mastodon.user-basic.stop-for-changes.streaming:
  service.dead:
    - name: mastodon-streaming
    - prereq:
      # Stop service before making changes
      - user: server.web.app.mastodon.user-basic
server.web.app.mastodon.user-basic.stop-for-changes.sidekiq:
  service.dead:
    - name: mastodon-sidekiq
    - prereq:
      # Stop service before making changes
      - user: server.web.app.mastodon.user-basic

# Set up the user
server.web.app.mastodon.user-basic:
  user.present:
    - name: {{ masto_user }}
    - fullname: 'Mastodon server user'
    - system: True
    - createhome: False # Handled below
    - home: {{ masto_home_dir }}
  file.directory:
    - name: {{ masto_home_dir }}
    - user: root
    - group: {{ masto_user }}
    # World-wide access is needed for nginx to access public HTML files
    # Also, enforce read-only mode
    - mode: 555
    - makedirs: True
    - require:
      - user: server.web.app.mastodon.user-basic

server.web.app.mastodon.user-rw.public:
  file.directory:
    - user: {{ masto_user }}
    - group: {{ masto_user }}
    # Mastodon repository contains public web content
    - mode: 755
    # Specify all public read-write directories
    - names:
      - {{ masto_home_dir }}/mastodon_root
    - require:
      - file: server.web.app.mastodon.user-basic

server.web.app.mastodon.user-rw.private:
  file.directory:
    - user: {{ masto_user }}
    - group: {{ masto_user }}
    # Node, NPM, and Mastodon needs to modify some folders
    - mode: 750
    # Specify all private read-write directories
    - names:
      - {{ masto_home_dir }}/.npm
      - {{ masto_home_dir }}/.node-gyp
      # Ruby
      - {{ masto_home_dir }}/.rbenv
      - {{ masto_home_dir }}/.bundle
      # Yarn
      - {{ masto_home_dir }}/.cache
      - {{ masto_home_dir }}/.yarn
      # Git configuration
      - {{ masto_home_dir }}/.config
    - require:
      - file: server.web.app.mastodon.user-basic

server.web.app.mastodon.user-rw.private-yarnrc:
  file.managed:
    # Yarn needs to modify a file
    - name: {{ masto_home_dir }}/.yarnrc
    - replace: False
    - user: {{ masto_user }}
    - group: {{ masto_user }}
    - mode: 640
    - require:
      - file: server.web.app.mastodon.user-basic

server.web.app.mastodon.user-bash:
  file.managed:
    # Specify all private read-write directories
    # Basic configuration
    - name: {{ masto_home_dir }}/.bashrc
    - contents: |
        # Salt: include Ruby environment in path
        export PATH="$HOME/.rbenv/bin:$PATH"
        # Salt: initialize Ruby environment
        eval "$(rbenv init -)"
    - user: root
    - group: {{ masto_user }}
    # Enforce read-only mode
    - mode: 550
    - require:
      - file: server.web.app.mastodon.user-basic

server.web.app.mastodon.setup-script:
  file.managed:
    # Basic configuration
    - name: {{ masto_home_dir }}/setup-mastodon.sh
    - source: salt://files/server/web/app/mastodon/setup-mastodon.sh
    - user: root
    - group: {{ masto_user }}
    # Enforce read-only mode, allow running script, keep private
    - mode: 550
    - template: jinja
    - context:
        masto_repo_dir: "{{ masto_repo_dir }}"
        masto_status_char_limit_changed: "{{ masto_status_char_limit|int != masto_status_char_limit_upstream|int }}"
        masto_bio_char_limit_changed: "{{ masto_bio_char_limit|int != masto_bio_char_limit_upstream|int }}"
    # Set up after base directory
    - require:
      - file: server.web.app.mastodon.user-rw.public

server.web.app.mastodon.corepack:
  cmd.run:
    # Set up yarn
    - name: corepack enable && yarn set version classic
    - unless: command -v yarn >/dev/null
    - require:
      - pkg: server.web.app.mastodon.dependencies

# Set up Ruby environment repository (not a full setup)
server.web.app.mastodon.ruby.env.repo:
  git.latest:
    - name: 'https://github.com/rbenv/rbenv.git'
    - target: {{ masto_home_dir }}/.rbenv
    - user: {{ masto_user }}
    - force_clone: False
    - force_checkout: False
    - force_reset: False
    - require:
      # Require install for user to be available
      - file: server.web.app.mastodon.user-rw.private
      # Need git
      - pkg: server.web.app.mastodon.dependencies

#server.web.app.mastodon.ruby.env.build:
#  cmd.run:
#    # Set up rbenv
#    - name: src/configure && make -C src
#    - unless: command -v yarn >/dev/null
#    - cwd: {{ masto_home_dir }}/.rbenv
#    - runas: {{ masto_user }}
#    - require:
#      - git: server.web.app.mastodon.ruby.env.repo
#
# Warning: this Makefile is obsolete and kept only for backwards compatibility.
# You can remove the `configure && make ...' step from your rbenv setup.

server.web.app.mastodon.ruby.build.repo:
  git.latest:
    - name: 'https://github.com/rbenv/ruby-build.git'
    - target: {{ masto_home_dir }}/.rbenv/plugins/ruby-build
    - user: {{ masto_user }}
    - force_clone: False
    - force_checkout: False
    - force_reset: False
    - require:
      # Require Ruby environment
      - git: server.web.app.mastodon.ruby.env.repo
      # Require install for user to be available
      - file: server.web.app.mastodon.user-rw.private
      # Need git
      - pkg: server.web.app.mastodon.dependencies

# Set up Mastodon's repository
server.web.app.mastodon.repo:
  file.directory:
    - name: {{ masto_repo_parent_dir }}
    - user: {{ masto_user }}
    - group: {{ masto_user }}
    - makedirs: True
    - require:
      # Require install for user to be available
      - file: server.web.app.mastodon.user-rw.public
#  git.latest:
  git.cloned:
    - name: 'https://github.com/mastodon/mastodon.git'
    - target: {{ masto_repo_dir }}
    - user: {{ masto_user }}
#    - rev: {{ salt['pillar.get']('server:web:app:mastodon:version:revision', 'HEAD') }}
#    - branch: {{ salt['pillar.get']('server:web:app:mastodon::version:branch', 'main') }}
#    - force_clone: False
#    - force_checkout: False
#    - force_reset: False
    - require:
      # Need parent folder created
      - file: server.web.app.mastodon.repo
      # Need git
      - pkg: server.web.app.mastodon.dependencies

# Set up local Postgres user for Mastodon
server.web.web.mastodon.postgres.user:
  postgres_user.present:
    - name: {{ masto_user }}
    # Mastodon setup requires database creation privileges
    # Future improvement: instead of permitting database creation, manually create it below
    - createdb: True
    - superuser: False
#server.web.web.mastodon.postgres.database:
#  postgres_database.present:
#    - name: {{ salt['pillar.get']('server:web:app:mastodon:database:name', 'mastodon_production') }}
#    - owner: {{ masto_user }}
#    # Found via... select * from pg_database;

server.web.app.mastodon.config:
  file.managed:
    # Basic configuration
    - name: {{ masto_repo_dir }}/.env.production
    - source: salt://files/server/web/app/mastodon/mastodon-config.env.production
    - user: {{ masto_user }}
    - group: {{ masto_user }}
    # Make private
    - mode: 640
    - template: jinja
    - context:
        masto_libvips_distver_new_enough: {{ masto_libvips_distver_new_enough }}
    # Set up after repo
    - require:
      - git: server.web.app.mastodon.repo

server.web.app.mastodon.patch.character-limit.posts:
  file.managed:
    # Basic configuration
    - name: {{ masto_repo_dir }}/0001-Increase-character-limit-posts.patch
    - source: salt://files/server/web/app/mastodon/0001-Increase-character-limit-posts.patch
    - user: {{ masto_user }}
    - group: {{ masto_user }}
    - template: jinja
    - context:
        masto_status_char_limit: "{{ masto_status_char_limit }}"
    # NOTE: Changes to this require re-running "setup-mastodon.sh"
    # Set up after repo
    - require:
      - git: server.web.app.mastodon.repo

server.web.app.mastodon.patch.character-limit.bio:
  file.managed:
    # Basic configuration
    - name: {{ masto_repo_dir }}/0001-Increase-character-limit-bio.patch
    - source: salt://files/server/web/app/mastodon/0001-Increase-character-limit-bio.patch
    - user: {{ masto_user }}
    - group: {{ masto_user }}
    - template: jinja
    - context:
        masto_bio_char_limit: "{{ masto_bio_char_limit }}"
    # NOTE: Changes to this require re-running "setup-mastodon.sh"
    # Set up after repo
    - require:
      - git: server.web.app.mastodon.repo

# Manual steps
#
# Log in to Mastodon user
# (Assuming "{{ masto_user }}" is "mastodon")
# ----
# sudo --user mastodon --login
# bash
#
# Run setup and follow instructions
# ----
# ./mastodon-setup.sh

# Set up the systemd services
server.web.app.mastodon.service.web.unit:
  file.managed:
    - name: /etc/systemd/system/mastodon-web.service
    - source: salt://files/server/web/app/mastodon/service/mastodon-web.service
    - template: jinja
    - context:
        masto_user: "{{ masto_user }}"
        masto_home_dir: "{{ masto_home_dir }}"
        masto_repo_dir: "{{ masto_repo_dir }}"
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.service.web.unit
#    - require_in:
#      - service: server.web.app.mastodon.service.web
#server.web.app.mastodon.service.web:
#  service.running:
#    - name: mastodon-web
#    - enable: True
#    - watch:
#      # Restart service on changes, wait for service to be deployed before start
#      - file: server.web.app.mastodon.service.web.unit
#      # Restart on configuration changes
#      - file: server.web.app.mastodon.config
#    - require:
#      # Ensure deployed first
#      - file: server.web.app.mastodon.config

server.web.app.mastodon.service.streaming.unit:
  file.managed:
    - name: /etc/systemd/system/mastodon-streaming.service
    - source: salt://files/server/web/app/mastodon/service/mastodon-streaming.service
    - template: jinja
    - context:
        masto_user: "{{ masto_user }}"
        masto_home_dir: "{{ masto_home_dir }}"
        masto_repo_dir: "{{ masto_repo_dir }}"
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.service.streaming.unit
#    - require_in:
#      - service: server.web.app.mastodon.service.streaming
#server.web.app.mastodon.service.streaming:
#  service.running:
#    - name: mastodon-streaming
#    - enable: True
#    - watch:
#      # Restart service on changes, wait for service to be deployed before start
#      - file: server.web.app.mastodon.service.streaming.unit
#      # Restart on configuration changes
#      - file: server.web.app.mastodon.config
#    - require:
#      # Ensure deployed first
#      - file: server.web.app.mastodon.config

server.web.app.mastodon.service.streaming-template.unit:
  file.managed:
    - name: /etc/systemd/system/mastodon-streaming@.service
    - source: salt://files/server/web/app/mastodon/service/mastodon-streaming@.service
    - template: jinja
    - context:
        masto_user: "{{ masto_user }}"
        masto_home_dir: "{{ masto_home_dir }}"
        masto_repo_dir: "{{ masto_repo_dir }}"
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.service.streaming.unit
#    - require_in:
#      - service: server.web.app.mastodon.service.streaming

server.web.app.mastodon.service.sidekiq.unit:
  file.managed:
    - name: /etc/systemd/system/mastodon-sidekiq.service
    - source: salt://files/server/web/app/mastodon/service/mastodon-sidekiq.service
    - template: jinja
    - context:
        masto_user: "{{ masto_user }}"
        masto_home_dir: "{{ masto_home_dir }}"
        masto_repo_dir: "{{ masto_repo_dir }}"
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.service.sidekiq.unit
#    - require_in:
#      - service: server.web.app.mastodon.service.sidekiq
#server.web.app.mastodon.service.sidekiq:
#  service.running:
#    - name: mastodon-sidekiq
#    - enable: True
#    - watch:
#      # Restart service on changes, wait for service to be deployed before start
#      - file: server.web.app.mastodon.service.sidekiq.unit
#      # Restart on configuration changes
#      - file: server.web.app.mastodon.config
#    - require:
#      # Ensure deployed first
#      - file: server.web.app.mastodon.config

# Maintenance tasks

# > Account pruning
{% if salt['pillar.get']('server:web:app:mastodon:maintenance:cleanup-accounts-prune', False) == False %}
# Disable profile pruning
server.web.app.mastodon.maintenance.account-prune.cleanup.timer:
  service.dead:
    - name: tootctl-cleanup-accounts-prune.timer
    - enable: False
server.web.app.mastodon.maintenance.account-prune.cleanup.service.running:
  # Disable startup
  service.disabled:
    - name: tootctl-cleanup-accounts-prune
{% else %}
# Enable profile pruning
# server.web.app.mastodon.maintenance.account-prune.service.unit
server.web.app.mastodon.maintenance.account-prune.service.unit:
  # Unit for startup
  file.managed:
    - name: /etc/systemd/system/tootctl-cleanup-accounts-prune.service
    - source: salt://files/server/web/app/mastodon/service/maintenance/tootctl-cleanup-accounts-prune.service
    - template: jinja
    - context:
        masto_user: "{{ masto_user }}"
        masto_home_dir: "{{ masto_home_dir }}"
        masto_repo_dir: "{{ masto_repo_dir }}"
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.maintenance.account-prune.service.unit
server.web.app.mastodon.maintenance.account-prune.service.disabled:
  # Disable startup (only run on timer)
  service.disabled:
    - name: tootctl-cleanup-accounts-prune
    - require:
      - cmd: server.web.app.mastodon.maintenance.account-prune.service.unit
      - file: server.web.app.mastodon.maintenance.account-prune.service.unit
server.web.app.mastodon.maintenance.account-prune.timer.unit:
  # Unit for periodic refresh
  file.managed:
    - name: /etc/systemd/system/tootctl-cleanup-accounts-prune.timer
    - source: salt://files/server/web/app/mastodon/service/maintenance/tootctl-cleanup-accounts-prune.timer
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.maintenance.account-prune.timer.unit
server.web.app.mastodon.maintenance.account-prune.timer.running:
  # Enable periodic refresh
  service.running:
    - name: tootctl-cleanup-accounts-prune.timer
    - enable: True
    - require:
      - cmd: server.web.app.mastodon.maintenance.account-prune.service.unit
      - file: server.web.app.mastodon.maintenance.account-prune.service.unit
      - cmd: server.web.app.mastodon.maintenance.account-prune.timer.unit
    - watch:
      - file: server.web.app.mastodon.maintenance.account-prune.timer.unit
{% endif %}

# > Profile media pruning
{% if salt['pillar.get']('server:web:app:mastodon:maintenance:cleanup-media-profiles', False) == False %}
# Disable profile pruning
server.web.app.mastodon.maintenance.media-profile.cleanup.timer:
  service.dead:
    - name: tootctl-cleanup-media-profiles.timer
    - enable: False
server.web.app.mastodon.maintenance.media-profile.cleanup.service.running:
  # Disable startup
  service.disabled:
    - name: tootctl-cleanup-media-profiles
{% else %}
# Enable profile pruning
# server.web.app.mastodon.maintenance.media-profile.service.unit
server.web.app.mastodon.maintenance.media-profile.service.unit:
  # Unit for startup
  file.managed:
    - name: /etc/systemd/system/tootctl-cleanup-media-profiles.service
    - source: salt://files/server/web/app/mastodon/service/maintenance/tootctl-cleanup-media-profiles.service
    - template: jinja
    - context:
        masto_user: "{{ masto_user }}"
        masto_home_dir: "{{ masto_home_dir }}"
        masto_repo_dir: "{{ masto_repo_dir }}"
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.maintenance.media-profile.service.unit
server.web.app.mastodon.maintenance.media-profile.service.disabled:
  # Disable startup (only run on timer)
  service.disabled:
    - name: tootctl-cleanup-media-profiles
    - require:
      - cmd: server.web.app.mastodon.maintenance.media-profile.service.unit
      - file: server.web.app.mastodon.maintenance.media-profile.service.unit
server.web.app.mastodon.maintenance.media-profile.timer.unit:
  # Unit for periodic refresh
  file.managed:
    - name: /etc/systemd/system/tootctl-cleanup-media-profiles.timer
    - source: salt://files/server/web/app/mastodon/service/maintenance/tootctl-cleanup-media-profiles.timer
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.maintenance.media-profile.timer.unit
server.web.app.mastodon.maintenance.media-profile.timer.running:
  # Enable periodic refresh
  service.running:
    - name: tootctl-cleanup-media-profiles.timer
    - enable: True
    - require:
      - cmd: server.web.app.mastodon.maintenance.media-profile.service.unit
      - file: server.web.app.mastodon.maintenance.media-profile.service.unit
      - cmd: server.web.app.mastodon.maintenance.media-profile.timer.unit
    - watch:
      - file: server.web.app.mastodon.maintenance.media-profile.timer.unit
{% endif %}

# > Lost media attachments
{% if salt['pillar.get']('server:web:app:mastodon:maintenance:cleanup-media-orphans', False) == False %}
# Disable removing lost media attachments
server.web.app.mastodon.maintenance.media-orphan.cleanup.timer:
  service.dead:
    - name: tootctl-cleanup-media-orphans.timer
    - enable: False
server.web.app.mastodon.maintenance.media-orphan.cleanup.service.running:
  # Disable startup
  service.disabled:
    - name: tootctl-cleanup-media-orphans
{% else %}
# Enable removing lost media attachments
# server.web.app.mastodon.maintenance.media-orphan.service.unit
server.web.app.mastodon.maintenance.media-orphan.service.unit:
  # Unit for startup
  file.managed:
    - name: /etc/systemd/system/tootctl-cleanup-media-orphans.service
    - source: salt://files/server/web/app/mastodon/service/maintenance/tootctl-cleanup-media-orphans.service
    - template: jinja
    - context:
        masto_user: "{{ masto_user }}"
        masto_home_dir: "{{ masto_home_dir }}"
        masto_repo_dir: "{{ masto_repo_dir }}"
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.maintenance.media-orphan.service.unit
server.web.app.mastodon.maintenance.media-orphan.service.disabled:
  # Disable startup (only run on timer)
  service.disabled:
    - name: tootctl-cleanup-media-orphans
    - require:
      - cmd: server.web.app.mastodon.maintenance.media-orphan.service.unit
      - file: server.web.app.mastodon.maintenance.media-orphan.service.unit
server.web.app.mastodon.maintenance.media-orphan.timer.unit:
  # Unit for periodic refresh
  file.managed:
    - name: /etc/systemd/system/tootctl-cleanup-media-orphans.timer
    - source: salt://files/server/web/app/mastodon/service/maintenance/tootctl-cleanup-media-orphans.timer
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.maintenance.media-orphan.timer.unit
server.web.app.mastodon.maintenance.media-orphan.timer.running:
  # Enable periodic refresh
  service.running:
    - name: tootctl-cleanup-media-orphans.timer
    - enable: True
    - require:
      - cmd: server.web.app.mastodon.maintenance.media-orphan.service.unit
      - file: server.web.app.mastodon.maintenance.media-orphan.service.unit
      - cmd: server.web.app.mastodon.maintenance.media-orphan.timer.unit
    - watch:
      - file: server.web.app.mastodon.maintenance.media-orphan.timer.unit
{% endif %}

# > Unreferenced statuses
{% if salt['pillar.get']('server:web:app:mastodon:maintenance:cleanup-statuses-orphans', False) == False %}
# Disable removing unreferenced statuses
server.web.app.mastodon.maintenance.statuses-orphan.cleanup.timer:
  service.dead:
    - name: tootctl-cleanup-statuses-orphans.timer
    - enable: False
server.web.app.mastodon.maintenance.statuses-orphan.cleanup.service.running:
  # Disable startup
  service.disabled:
    - name: tootctl-cleanup-statuses-orphans
{% else %}
# Enable removing unreferenced statuses
# server.web.app.mastodon.maintenance.statuses-orphan.service.unit
server.web.app.mastodon.maintenance.statuses-orphan.service.unit:
  # Unit for startup
  file.managed:
    - name: /etc/systemd/system/tootctl-cleanup-statuses-orphans.service
    - source: salt://files/server/web/app/mastodon/service/maintenance/tootctl-cleanup-statuses-orphans.service
    - template: jinja
    - context:
        masto_user: "{{ masto_user }}"
        masto_home_dir: "{{ masto_home_dir }}"
        masto_repo_dir: "{{ masto_repo_dir }}"
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.maintenance.statuses-orphan.service.unit
server.web.app.mastodon.maintenance.statuses-orphan.service.disabled:
  # Disable startup (only run on timer)
  service.disabled:
    - name: tootctl-cleanup-statuses-orphans
    - require:
      - cmd: server.web.app.mastodon.maintenance.statuses-orphan.service.unit
      - file: server.web.app.mastodon.maintenance.statuses-orphan.service.unit
server.web.app.mastodon.maintenance.statuses-orphan.timer.unit:
  # Unit for periodic refresh
  file.managed:
    - name: /etc/systemd/system/tootctl-cleanup-statuses-orphans.timer
    - source: salt://files/server/web/app/mastodon/service/maintenance/tootctl-cleanup-statuses-orphans.timer
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.maintenance.statuses-orphan.timer.unit
server.web.app.mastodon.maintenance.statuses-orphan.timer.running:
  # Enable periodic refresh
  service.running:
    - name: tootctl-cleanup-statuses-orphans.timer
    - enable: True
    - require:
      - cmd: server.web.app.mastodon.maintenance.statuses-orphan.service.unit
      - file: server.web.app.mastodon.maintenance.statuses-orphan.service.unit
      - cmd: server.web.app.mastodon.maintenance.statuses-orphan.timer.unit
    - watch:
      - file: server.web.app.mastodon.maintenance.statuses-orphan.timer.unit
{% endif %}

# > Link preview cards
{% if salt['pillar.get']('server:web:app:mastodon:maintenance:cleanup-preview-cards', False) == False %}
# Disable removing link preview cards
server.web.app.mastodon.maintenance.preview-card.cleanup.timer:
  service.dead:
    - name: tootctl-cleanup-preview-cards.timer
    - enable: False
server.web.app.mastodon.maintenance.preview-card.cleanup.service.running:
  # Disable startup
  service.disabled:
    - name: tootctl-cleanup-preview-cards
{% else %}
# Enable removing link preview cards
# server.web.app.mastodon.maintenance.preview-card.service.unit
server.web.app.mastodon.maintenance.preview-card.service.unit:
  # Unit for startup
  file.managed:
    - name: /etc/systemd/system/tootctl-cleanup-preview-cards.service
    - source: salt://files/server/web/app/mastodon/service/maintenance/tootctl-cleanup-preview-cards.service
    - template: jinja
    - context:
        masto_user: "{{ masto_user }}"
        masto_home_dir: "{{ masto_home_dir }}"
        masto_repo_dir: "{{ masto_repo_dir }}"
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.maintenance.preview-card.service.unit
server.web.app.mastodon.maintenance.preview-card.service.disabled:
  # Disable startup (only run on timer)
  service.disabled:
    - name: tootctl-cleanup-preview-cards
    - require:
      - cmd: server.web.app.mastodon.maintenance.preview-card.service.unit
      - file: server.web.app.mastodon.maintenance.preview-card.service.unit
server.web.app.mastodon.maintenance.preview-card.timer.unit:
  # Unit for periodic refresh
  file.managed:
    - name: /etc/systemd/system/tootctl-cleanup-preview-cards.timer
    - source: salt://files/server/web/app/mastodon/service/maintenance/tootctl-cleanup-preview-cards.timer
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: server.web.app.mastodon.maintenance.preview-card.timer.unit
server.web.app.mastodon.maintenance.preview-card.timer.running:
  # Enable periodic refresh
  service.running:
    - name: tootctl-cleanup-preview-cards.timer
    - enable: True
    - require:
      - cmd: server.web.app.mastodon.maintenance.preview-card.service.unit
      - file: server.web.app.mastodon.maintenance.preview-card.service.unit
      - cmd: server.web.app.mastodon.maintenance.preview-card.timer.unit
    - watch:
      - file: server.web.app.mastodon.maintenance.preview-card.timer.unit
{% endif %}



# Backup module
# ####
{% if salt['pillar.get']('common:backup:system:enable', False) == True %}
# Set archive directory
{% set archive_configdir = salt['pillar.get']('common:backup:system:storage:datadir', '/root/salt/backup/system') %}
{% set archive_moduledir = archive_configdir | path_join('scripts.d') %}
web.app.mastodon.backupmgr:
  file.managed:
    - name: {{ archive_moduledir }}/web-app-mastodon-backup
    - source: salt://files/server/web/app/mastodon/web-app-mastodon-backup
    - makedirs: True
    # Specify database name
    - template: jinja
    - context:
        mastodon_db_name: "{{ salt['pillar.get']('server:web:app:mastodon:database:name', 'mastodon_production') }}"
        masto_repo_dir: "{{ masto_repo_dir }}"
    # Mark as executable
    - mode: 755
#    - require:
#      - service: server.web.app.mastodon.service.web
#      - service: server.web.app.mastodon.service.streaming
#      - service: server.web.app.mastodon.service.sidekiq
    - watch_in:
      - cmd: common.backup.system.configure
{% endif %}
# ####
