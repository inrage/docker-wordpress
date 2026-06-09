#!/usr/bin/env bash
set -Eeuo pipefail

WP_PROFILE="${WP_PROFILE:-showcase}"
WP_SCALE="${WP_SCALE:-standard}"

echo "🔧 [init] preset WP_PROFILE=${WP_PROFILE} WP_SCALE=${WP_SCALE}"

case "$WP_SCALE" in
"high")
  : "${PHP_OPCACHE_VALIDATE_TIMESTAMPS:=0}"
  : "${PHP_OPCACHE_MEMORY_CONSUMPTION:=512}"
  : "${PHP_OPCACHE_MAX_ACCELERATED_FILES:=60000}"
  : "${PHP_OPCACHE_INTERNED_STRINGS_BUFFER:=32}"
  : "${SKIP_CACHE_FLUSH:=true}"
  ;;
*)
  : "${PHP_OPCACHE_VALIDATE_TIMESTAMPS:=1}"
  : "${PHP_OPCACHE_MEMORY_CONSUMPTION:=256}"
  : "${PHP_OPCACHE_MAX_ACCELERATED_FILES:=20000}"
  : "${PHP_OPCACHE_INTERNED_STRINGS_BUFFER:=16}"
  : "${SKIP_CACHE_FLUSH:=false}"
  ;;
esac

case "$WP_PROFILE" in
"shop")
  : "${PHP_MEMORY_LIMIT:=512M}"
  : "${INR_CACHE:=on}"
  : "${INR_CACHE_BYPASS_COOKIES:=wordpress_logged_in_|wp-postpass_|comment_author_|woocommerce_items_in_cart|woocommerce_cart_hash|wp_woocommerce_session_}"
  ;;
*)
  : "${PHP_MEMORY_LIMIT:=256M}"
  : "${INR_CACHE:=on}"
  : "${INR_CACHE_BYPASS_COOKIES:=wordpress_logged_in_|wp-postpass_|comment_author_}"
  ;;
esac

if [ "${INR_CACHE}" = "on" ] && [ -n "${REDIS_HOST:-}" ]; then
  INR_CACHE_DIRECTIVE="cache"
  CADDY_CACHE_GLOBAL="cache {
	ttl ${SOUIN_TTL:-120s}
	stale ${SOUIN_STALE:-60s}
	redis {
		url ${REDIS_HOST}:${REDIS_PORT:-6379}
	}
}"
  echo "✅ [init] Souin full-page cache activé (Redis ${REDIS_HOST})"
else
  INR_CACHE_DIRECTIVE=""
  CADDY_CACHE_GLOBAL=""
  echo "ℹ️  [init] pas de REDIS_HOST → full-page cache Souin désactivé"
fi

export PHP_MEMORY_LIMIT PHP_OPCACHE_VALIDATE_TIMESTAMPS PHP_OPCACHE_MEMORY_CONSUMPTION \
  PHP_OPCACHE_MAX_ACCELERATED_FILES PHP_OPCACHE_INTERNED_STRINGS_BUFFER SKIP_CACHE_FLUSH \
  INR_CACHE INR_CACHE_BYPASS_COOKIES INR_CACHE_DIRECTIVE

if [ -n "${INRAGE_RUNTIME_ENV:-}" ]; then
  {
    printf "export INR_CACHE_DIRECTIVE='%s'\n" "${INR_CACHE_DIRECTIVE}"
    printf "export INR_CACHE_BYPASS_COOKIES='%s'\n" "${INR_CACHE_BYPASS_COOKIES}"
    printf "export CADDY_CACHE_GLOBAL='%s'\n" "${CADDY_CACHE_GLOBAL}"
  } >> "$INRAGE_RUNTIME_ENV"
fi

PHP_CONF_D="${PHP_INI_DIR:-/usr/local/etc/php}/conf.d"
cat > "${PHP_CONF_D}/zzz-wp-preset.ini" <<EOF
memory_limit = ${PHP_MEMORY_LIMIT}
opcache.validate_timestamps = ${PHP_OPCACHE_VALIDATE_TIMESTAMPS}
opcache.memory_consumption = ${PHP_OPCACHE_MEMORY_CONSUMPTION}
opcache.max_accelerated_files = ${PHP_OPCACHE_MAX_ACCELERATED_FILES}
opcache.interned_strings_buffer = ${PHP_OPCACHE_INTERNED_STRINGS_BUFFER}
EOF

echo "✅ [init] preset appliqué : mem=${PHP_MEMORY_LIMIT} opcache_mem=${PHP_OPCACHE_MEMORY_CONSUMPTION} interned=${PHP_OPCACHE_INTERNED_STRINGS_BUFFER} cache=${INR_CACHE}"
