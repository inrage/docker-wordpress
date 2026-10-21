#!/usr/bin/env bash

set -e

wp_root="${APACHE_VHOST_DIR:-/var/www/html}/wp"

if [[ ! -f /var/www/html/wp-cli.yml && ! -f /var/www/html/wp-load.php && -f "${wp_root}/wp-load.php" ]]; then
  mkdir -p "${HOME}/.wp-cli"
  printf 'path: %s\n' "${wp_root}" > "${HOME}/.wp-cli/config.yml"
  echo "Using WP-CLI path ${wp_root}"
fi
