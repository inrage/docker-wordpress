#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# 00-presets.sh
# Centralized performance profile management (WP_PRESET)
# -----------------------------------------------------------------------------

# If WP_PRESET is not defined, default to 'vitrine'
WP_PRESET=${WP_PRESET:-vitrine}

echo "🔧 [Init] Loading configuration preset: [$WP_PRESET]"

case "$WP_PRESET" in
"high-traffic")
  # --- MODE: HIGH TRAFFIC / SALES / NEWSLETTER ---
  # Goal: Max availability. Never crash, never flush cache on boot.

  # 1. Cache Safety (Used by scripts 10 and 20)
  export SKIP_CACHE_FLUSH=${SKIP_CACHE_FLUSH:-true}

  # 2. Apache Tuning (Used by docker-php)
  # We override default values ONLY if they are not explicitly set in docker-compose
  export APACHE_MPM_START_SERVERS=${APACHE_MPM_START_SERVERS:-10}
  export APACHE_MPM_MIN_SPARE_SERVERS=${APACHE_MPM_MIN_SPARE_SERVERS:-10}
  export APACHE_MPM_MAX_SPARE_SERVERS=${APACHE_MPM_MAX_SPARE_SERVERS:-20}
  export APACHE_MPM_MAX_REQUEST_WORKERS=${APACHE_MPM_MAX_REQUEST_WORKERS:-50}
  export APACHE_MPM_MAX_CONNECTIONS_PER_CHILD=${APACHE_MPM_MAX_CONNECTIONS_PER_CHILD:-3000}

  # 3. PHP Tuning
  export PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-512M}
  # Max Performance: stop scanning disk for PHP file changes
  export PHP_OPCACHE_VALIDATE_TIMESTAMPS=${PHP_OPCACHE_VALIDATE_TIMESTAMPS:-0}
  export PHP_OPCACHE_MAX_ACCELERATED_FILES=${PHP_OPCACHE_MAX_ACCELERATED_FILES:-60000}
  export PHP_OPCACHE_MEMORY_CONSUMPTION=${PHP_OPCACHE_MEMORY_CONSUMPTION:-512}
  ;;

"woocommerce")
  # --- MODE: STANDARD E-COMMERCE ---
  # Goal: Stability and RAM, but standard cache flush for updates.

  export SKIP_CACHE_FLUSH=${SKIP_CACHE_FLUSH:-false}

  export PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-512M}
  export PHP_OPCACHE_VALIDATE_TIMESTAMPS=${PHP_OPCACHE_VALIDATE_TIMESTAMPS:-1}

  export APACHE_MPM_START_SERVERS=${APACHE_MPM_START_SERVERS:-5}
  export APACHE_MPM_MIN_SPARE_SERVERS=${APACHE_MPM_MIN_SPARE_SERVERS:-5}
  export APACHE_MPM_MAX_SPARE_SERVERS=${APACHE_MPM_MAX_SPARE_SERVERS:-10}
  export APACHE_MPM_MAX_REQUEST_WORKERS=${APACHE_MPM_MAX_REQUEST_WORKERS:-25}
  ;;

"vitrine-heavy")
  # --- MODE: LARGE CORPORATE SITE ---
  # Goal: Asset delivery, moderate traffic.

  export SKIP_CACHE_FLUSH=${SKIP_CACHE_FLUSH:-false}
  export PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-256M}
  export APACHE_MPM_MAX_REQUEST_WORKERS=${APACHE_MPM_MAX_REQUEST_WORKERS:-25}
  ;;

*)
  # --- MODE: VITRINE / DEFAULT ---
  # Goal: Resource economy.

  export SKIP_CACHE_FLUSH=${SKIP_CACHE_FLUSH:-false}

  export PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-128M}
  export PHP_OPCACHE_VALIDATE_TIMESTAMPS=${PHP_OPCACHE_VALIDATE_TIMESTAMPS:-1}

  export APACHE_MPM_START_SERVERS=${APACHE_MPM_START_SERVERS:-2}
  export APACHE_MPM_MIN_SPARE_SERVERS=${APACHE_MPM_MIN_SPARE_SERVERS:-2}
  export APACHE_MPM_MAX_SPARE_SERVERS=${APACHE_MPM_MAX_SPARE_SERVERS:-5}
  export APACHE_MPM_MAX_REQUEST_WORKERS=${APACHE_MPM_MAX_REQUEST_WORKERS:-10}
  ;;
esac

echo "✅ [Init] Configuration applied for preset '$WP_PRESET'."
echo "   - Workers: $APACHE_MPM_MAX_REQUEST_WORKERS"
echo "   - Skip Flush: $SKIP_CACHE_FLUSH"
