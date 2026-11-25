#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for scenario in high-traffic vitrine woocommerce vitrine-heavy default overrides; do
  docker run --rm --network none --platform linux/amd64 \
    --entrypoint bash \
    -v "$repo_dir/init/00-presets.sh:/docker-entrypoint-init.d/00-presets.sh:ro" \
    "${PRESET_BASE_IMAGE:-inrage/docker-php:8.3}" -ec '
    expected_memory=256M
    expected_opcache=640
    expected_files=100000
    expected_timestamps=1
    expected_flush=false
    expected_children=20
    expected_workers=150
    case "$1" in
      high-traffic)
        export WP_PRESET=high-traffic
        expected_memory=512M
        expected_opcache=512
        expected_files=60000
        expected_timestamps=0
        expected_flush=true
        ;;
      woocommerce)
        export WP_PRESET=woocommerce
        expected_memory=512M
        ;;
      vitrine-heavy)
        export WP_PRESET=vitrine-heavy
        expected_timestamps=0
        ;;
      vitrine) export WP_PRESET=vitrine ;;
      overrides)
        export WP_PRESET=high-traffic PHP_MEMORY_LIMIT=384M \
          PHP_OPCACHE_MEMORY_CONSUMPTION=256 PHP_OPCACHE_MAX_ACCELERATED_FILES=30000 \
          PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 SKIP_CACHE_FLUSH=false \
          PHP_FPM_PM_MAX_CHILDREN=8 PHP_FPM_PM_START_SERVERS=2 \
          PHP_FPM_PM_MIN_SPARE_SERVERS=1 PHP_FPM_PM_MAX_SPARE_SERVERS=4 \
          APACHE_EVENT_MAX_REQUEST_WORKERS=100
        expected_memory=384M
        expected_opcache=256
        expected_files=30000
        expected_children=8
        expected_workers=100
        ;;
    esac
    source /etc/s6-overlay/scripts/init-templates
    php -r '\''
      $expected = [
        "memory_limit" => $argv[1],
        "opcache.memory_consumption" => $argv[2],
        "opcache.max_accelerated_files" => $argv[3],
        "opcache.validate_timestamps" => $argv[4],
      ];
      foreach ($expected as $key => $value) {
        if (ini_get($key) !== $value) {
          fwrite(STDERR, $key . ": expected " . $value . ", got " . ini_get($key) . "\n");
          exit(1);
        }
      }
      echo json_encode($expected), "\n";
    '\'' "$expected_memory" "$expected_opcache" "$expected_files" "$expected_timestamps"
    test "$SKIP_CACHE_FLUSH" = "$expected_flush"
    test -z "${APACHE_MPM_MAX_REQUEST_WORKERS+x}"
    php-fpm -tt >/tmp/fpm-config 2>&1
    grep -Fq "pm.max_children = $expected_children" /tmp/fpm-config
    apache2ctl -t
    grep -Eq "^MaxRequestWorkers[[:space:]]+$expected_workers$" /etc/apache2/mpm-overrides/mpm_event.conf
    printf "PASS preset %s with effective PHP, Apache and FPM settings\n" "$1"
  ' preset-test "$scenario"
done
