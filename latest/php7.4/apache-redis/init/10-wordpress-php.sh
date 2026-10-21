#!/usr/bin/env bash

set -e

start_redis() {
  if wp redis &>/dev/null; then
    echo "Redis is installed... enabling Redis object cache..."
    wp redis enable --force
  else
    echo "Redis is not installed... skipping Redis commands."
  fi
}

_gotpl() {
  if [[ -f "/etc/gotpl/$1" ]]; then
    gotpl "/etc/gotpl/$1" >"$2"
  fi
}

if [[ "${WORDPRESS_NO_CREATE_CONFIG}" != "true" ]]; then
  _gotpl "wp-config.php.tmpl" "/var/www/html/wp-config.php"
fi

CONTENT_DIR=$(wp eval 'echo WP_CONTENT_DIR;')

mkdir -p "${CONTENT_DIR}/mu-plugins"
_gotpl "production.php.tmpl" "${CONTENT_DIR}/mu-plugins/production.php"

## Create upgrade directory
if [[ ! -d "${CONTENT_DIR}/upgrade" ]]; then
  mkdir -p "${CONTENT_DIR}/upgrade"
fi

start_redis
