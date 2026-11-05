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

wordpress_ready() {
  local deadline=$((SECONDS + ${WORDPRESS_DB_WAIT:-60}))
  local error_file
  local error

  if ! wp core version &>/dev/null; then
    echo "WordPress core not found... skipping WordPress setup."
    return 1
  fi

  error_file="$(mktemp)"
  while ! CONTENT_DIR="$(wp eval 'echo WP_CONTENT_DIR;' 2>"${error_file}")"; do
    error="$(grep -m 1 . "${error_file}" || true)"
    if grep -q "is not installed" "${error_file}" || ((SECONDS >= deadline)); then
      echo "WordPress is not ready (${error})... skipping WordPress setup." >&2
      rm -f "${error_file}"
      return 1
    fi
    echo "Waiting for WordPress (${error})..."
    sleep 5
  done
  rm -f "${error_file}"
}

if [[ "${WORDPRESS_NO_CREATE_CONFIG}" != "true" ]]; then
  _gotpl "wp-config.php.tmpl" "/var/www/html/wp-config.php"
fi

if wordpress_ready; then
  mkdir -p "${CONTENT_DIR}/mu-plugins"
  _gotpl "production.php.tmpl" "${CONTENT_DIR}/mu-plugins/production.php"

  ## Create upgrade directory
  if [[ ! -d "${CONTENT_DIR}/upgrade" ]]; then
    mkdir -p "${CONTENT_DIR}/upgrade"
  fi

  start_redis
fi
