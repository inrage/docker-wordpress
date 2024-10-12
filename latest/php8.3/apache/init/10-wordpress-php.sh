#!/usr/bin/env bash

set -e

start_redis() {
  if wp redis &> /dev/null; then
    echo "Redis is installed... enabling Redis object cache..."
    wp redis enable --force
  else
    echo "Redis is not installed... skipping Redis commands."
  fi
}

_gotpl() {
    if [[ -f "/etc/gotpl/$1" ]]; then
        gotpl "/etc/gotpl/$1" > "$2"
    fi
}

if [[ "${WORDPRESS_NO_CREATE_CONFIG}" != "true" ]]; then
    _gotpl "wp-config.php.tmpl" "/var/www/html/wp-config.php"
fi

start_redis
