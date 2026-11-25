#!/usr/bin/env bash
set -e

start_object_cache() {
  if wp cli has-command 'redis enable' >/dev/null 2>&1; then
    wp eval-file /usr/local/bin/wordpress-object-cache.php
  else
    echo "No redis object cache plugin installed... skipping (default in-memory cache)."
  fi
}

_gomplate() {
  if [ -f "/etc/gomplate/$1" ]; then
    gomplate -f "/etc/gomplate/$1" -o "$2"
  fi
}

if [ "${WORDPRESS_NO_CREATE_CONFIG}" != "true" ]; then
  _gomplate "wp-config.php.tmpl" "/var/www/html/wp-config.php"
fi

wordpress_ready=false
error_file="$(mktemp)"
if content_dir="$(wp eval 'echo WP_CONTENT_DIR;' 2>"$error_file")"; then
  wordpress_ready=true
elif grep -Fq 'Could not generate WP Rocket ' "$error_file"; then
  cat "$error_file" >&2
  rm -f "$error_file"
  exit 1
fi
rm -f "$error_file"
if [ -z "$content_dir" ] || [ ! -d "$content_dir" ]; then
  if [ -d /var/www/html/public/content ]; then
    content_dir=/var/www/html/public/content
  else
    content_dir=/var/www/html/wp-content
  fi
fi

mkdir -p "${content_dir}/mu-plugins"
_gomplate "production.php.tmpl" "${content_dir}/mu-plugins/production.php"
if [ "$wordpress_ready" = true ]; then
  wp eval '' || exit $?
fi

mkdir -p "${content_dir}/upgrade"

start_object_cache
