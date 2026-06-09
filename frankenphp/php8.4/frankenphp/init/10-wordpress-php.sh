#!/usr/bin/env bash
set -e

start_redis() {
  if wp redis &>/dev/null; then
    echo "Redis object cache plugin detected... enabling."
    wp redis enable --force || true
  else
    echo "No Redis object cache plugin... skipping (OCP manages its own drop-in)."
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

content_dir="$(wp eval 'echo WP_CONTENT_DIR;' 2>/dev/null || echo /var/www/html/wp-content)"

mkdir -p "${content_dir}/mu-plugins"
_gomplate "production.php.tmpl" "${content_dir}/mu-plugins/production.php"

mkdir -p "${content_dir}/upgrade"

start_redis
