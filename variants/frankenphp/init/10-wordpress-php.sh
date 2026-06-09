#!/usr/bin/env bash
set -e

start_object_cache() {
  if wp object-cache &>/dev/null; then
    echo "Object Cache Pro detected... enabling drop-in."
    wp object-cache enable --force >/dev/null 2>&1 || true
  elif wp redis &>/dev/null; then
    echo "Redis Object Cache plugin detected... enabling."
    wp redis enable --force >/dev/null 2>&1 || true
  else
    echo "No object cache plugin installed... skipping (default in-memory cache)."
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

content_dir="$(wp eval 'echo WP_CONTENT_DIR;' 2>/dev/null || true)"
if [ -z "$content_dir" ] || [ ! -d "$content_dir" ]; then
  if [ -d /var/www/html/public/content ]; then
    content_dir=/var/www/html/public/content
  else
    content_dir=/var/www/html/wp-content
  fi
fi

mkdir -p "${content_dir}/mu-plugins"
_gomplate "production.php.tmpl" "${content_dir}/mu-plugins/production.php"

mkdir -p "${content_dir}/upgrade"

start_object_cache
