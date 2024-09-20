#!/bin/bash
# See http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

# Update Mastodon repository and switch to a stable version
# https://docs.joinmastodon.org/admin/install/#checking-out-the-code
# ----
echo " * Switching to tagged Mastodon version..."
cd "{{ masto_repo_dir }}"
# Revert custom patches
git restore \*
# Fetch newest code
git fetch
# Switch to latest versioned branch
git checkout $(git tag -l |{% if salt['pillar.get']('server:web:app:mastodon:use_unstable_versions', False) == False %} grep '^v[0-9.]*$' |{% endif %} sort -V | tail -n 1)

# Finish installing Ruby
# https://docs.joinmastodon.org/admin/install/#installing-ruby
#
# NOTE: Run this after checking out the repo to have the correct Ruby version
# ----
echo " * Installing Ruby..."
MASTODON_RUBY_VERSION="$(<"{{ masto_repo_dir }}/.ruby-version")"
RUBY_CONFIGURE_OPTS=--with-jemalloc rbenv install --skip-existing "$MASTODON_RUBY_VERSION"
rbenv global "$MASTODON_RUBY_VERSION"
echo " * Cleaning up old Ruby versions..."
for RB_VERSION in $(rbenv versions --bare); do
	if [[ "$RB_VERSION" == "$MASTODON_RUBY_VERSION" ]]; then
		continue
	fi
	rbenv uninstall --force "$RB_VERSION"
done

echo " * Installing Ruby Bundler..."
gem install bundler --no-document

# Clean up global cache
# (Must be done manually)
# https://yarnpkg.com/features/offline-cache/
# ----
echo " * Cleaning global Yarn cache..."
yarn cache clean --mirror

# Switch to Yarn 4
# ----
corepack prepare

# Install more dependencies (within repository)
# https://docs.joinmastodon.org/admin/install/#installing-the-last-dependencies
# ----
echo " * Installing additional dependencies..."
bundle config deployment 'true'
bundle config without 'development test'
bundle install -j$(getconf _NPROCESSORS_ONLN)
yarn install --immutable

# Apply character limit if necessary and possible
# ----
{% if masto_status_char_limit_changed|to_bool == True -%}
echo " * Modifying status character limits..."
if ! git apply 0001-Increase-character-limit-posts.patch; then
	echo "[!] Could not apply '0001-Increase-character-limit-posts.patch'!"
	echo "----"
	echo "Switch to repository and fix the patch within Salt."
	echo
	echo "cd \"{{ masto_repo_dir }}\""
	exit 1
fi
{% else %}
echo " * Using default status character limits (not changed within Salt configuration)"
{% endif -%}
{% if masto_bio_char_limit_changed|to_bool == True -%}
echo " * Modifying bio character limits..."
if ! git apply 0001-Increase-character-limit-bio.patch; then
	echo "[!] Could not apply '0001-Increase-character-limit-bio.patch'!"
	echo "----"
	echo "Switch to repository and fix the patch within Salt."
	echo
	echo "cd \"{{ masto_repo_dir }}\""
	exit 1
fi
{% else %}
echo " * Using default bio character limits (not changed within Salt configuration)"
{% endif %}

# Compile assets
# https://github.com/mastodon/mastodon/blob/main/lib/tasks/mastodon.rake
# ----
echo " * Compiling assets..."
RAILS_ENV=production bundle exec rails yarn:install assets:precompile

echo
echo
echo "Automated portion of initial setup complete!"
echo "-------------"
echo "Remaining steps:"
echo ""
echo "1.  Switch to repository"
echo "cd \"{{ masto_repo_dir }}\""
echo
echo "2.  FOR INITIAL SETUP..."
echo "  A.  Create configuration file"
# https://docs.joinmastodon.org/admin/install/#generating-a-configuration
echo "RAILS_ENV=production bundle exec rake mastodon:setup"
echo
echo "  B.  Copy .env.production generated configuration into Salt YAML"
echo "  C.  Re-run Salt deployment"
echo
echo "2.  IF SKIPPING INITIAL SETUP..."
# https://docs.joinmastodon.org/admin/migrating/
echo "  A.  Regenerate home feeds"
echo "RAILS_ENV=production bin/tootctl feeds build"
echo
# https://github.com/mastodon/mastodon/blob/main/lib/tasks/mastodon.rake
echo "  B.  Create database and user ONLY IF NEEDED"
echo "# RAILS_ENV=production SAFETY_ASSURED=1 bundle exec rails db:setup"
# "[...] --approve" at the end arrives after 4.1.2
echo "# RAILS_ENV=production bin/tootctl accounts create USERNAME --email EMAIL --confirmed --role Owner"
echo
echo "3.  IF UPGRADING..."
echo "  Run all upgrade steps for each Mastodon version, then restart services"
echo
echo "4.  REGARDLESS OF SETUP, as the system user, enable and (re)start services"
echo "  (Open new tmux pane, or Ctrl+D until reaching system user)"
echo "sudo systemctl enable --now mastodon-web mastodon-sidekiq mastodon-streaming"
echo "  (...or...)"
echo "sudo systemctl restart mastodon-web mastodon-sidekiq mastodon-streaming"
