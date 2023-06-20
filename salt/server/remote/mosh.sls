# Mosh

# Install Mosh
# Install the PPA version for updates
#
# Ubuntu 20.04+ - the Mosh PPA hasn't been updated yet
{% set mosh_minver = '1.3.2' %}
{% set mosh_distver = salt['pkg.list_repo_pkgs']('mosh')['mosh'] |first() %}
{% set mosh_distver_new_enough = (salt['pkg.version_cmp'](mosh_distver, mosh_minver) >= 0) %}

{% if mosh_distver_new_enough == False %}
mosh.ppa:
  pkgrepo.managed:
    - comments: Mosh stable PPA, managed by SaltStack
    - ppa: keithw/mosh
  pkg.uptodate:
    # Only update if changes are made
    - onchanges:
      - pkgrepo: mosh.ppa
{% endif %}

mosh:
  pkg.installed:
    - pkgs:
      - mosh
{% if mosh_distver_new_enough == False %}
    - refresh: True # Only needed when using PPA
    - require:
      - pkgrepo: mosh.ppa
{% endif %}

mosh.config.timeout:
  file.managed:
    - name: /etc/profile.d/mosh-configuration.sh
    - contents: |
        # Set a timeout of 4 weeks for sessions without any network activity
        # See "man mosh-server"
        export MOSH_SERVER_NETWORK_TMOUT=2592000
