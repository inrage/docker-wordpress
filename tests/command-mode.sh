#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
test_image="wordpress-command-test:$(date +%s)-$$"
frankenphp_test_image="${test_image}-frankenphp"

cleanup() {
  docker image rm -f "$test_image" "$frankenphp_test_image" >/dev/null 2>&1 || true
  rm -rf "$test_dir"
}
trap cleanup EXIT

docker build --quiet --platform linux/amd64 --build-arg "BASE_IMAGE=${BASE_IMAGE:-inrage/docker-wordpress:8.3-redis}" \
  -f "$repo_dir/tests/Dockerfile" -t "$test_image" "$repo_dir" > "$test_dir/build.log"

docker run --rm --network none --platform linux/amd64 -e TEST_PRESERVE_CACHE=true -e TEST_EXPECT_DROPIN=original-drop-in "$test_image" > "$test_dir/server.log"
grep -qx 'SERVER_STARTED' "$test_dir/server.log"
! grep -q '^redis enable' "$test_dir/server.log"
grep -qx 'acorn optimize' "$test_dir/server.log"
! grep -qx 'cache flush' "$test_dir/server.log"
printf 'PASS default server initialization\n'

for variant in apache frankenphp; do
  for scenario in pro-existing community-existing pro-missing community-missing pro-current community-current pro-outdated community-outdated absent unknown-existing; do
    plugin="${scenario%%-*}"
    expected=original-drop-in
    updates=0
    case "$scenario" in
      *-missing|*-outdated) expected="$plugin-drop-in"; updates=1 ;;
      *-current) expected="$plugin-drop-in" ;;
      absent) expected=absent ;;
    esac
    docker run --rm --network none --platform linux/amd64 --entrypoint bash \
      -e TEST_PRESERVE_CACHE=true -e "TEST_EXPECT_UPDATES=$updates" \
      -e "TEST_REDIS_PLUGIN=$plugin" -e "TEST_EXPECT_DROPIN=$expected" "$test_image" -ec '
      case "$2" in
        *-missing|absent) rm /var/www/html/wp-content/object-cache.php ;;
        *-current) printf "%s-drop-in\n" "${2%%-*}" > /var/www/html/wp-content/object-cache.php ;;
        *-outdated) printf "old-%s-drop-in\n" "${2%%-*}" > /var/www/html/wp-content/object-cache.php ;;
      esac
      if [ "$1" = apache ]; then
        exec /init
      fi
      gomplate() { cp "$2" "$4"; }
      export WORDPRESS_NO_CREATE_CONFIG=true
      source /tests/frankenphp-init.sh
      source /docker-entrypoint-init.d/20-acorn-php.sh
      source /docker-entrypoint-init.d/99-test.sh
      echo SERVER_STARTED
    ' cache-test "$variant" "$scenario" > "$test_dir/skip-$variant-$scenario.log" 2>&1
    grep -qx SERVER_STARTED "$test_dir/skip-$variant-$scenario.log"
    printf 'PASS web cache preservation: %s %s\n' "$variant" "$scenario"
  done
done

for scenario in preset-high normal explicit-false-high; do
  docker run --rm --network none --platform linux/amd64 --entrypoint bash \
    -e TEST_REDIS_PLUGIN=pro "$test_image" -ec '
    gomplate() { cp "$2" "$4"; }
    export WORDPRESS_NO_CREATE_CONFIG=true
    export INRAGE_RUNTIME_ENV="$(mktemp)"
    case "$1" in
      preset-high) export WP_SCALE=high ;;
      explicit-false-high) export WP_SCALE=high SKIP_CACHE_FLUSH=false ;;
    esac
    ( . /tests/frankenphp-presets.sh )
    . "$INRAGE_RUNTIME_ENV"
    . /tests/frankenphp-init.sh
    . /docker-entrypoint-init.d/20-acorn-php.sh
    if [ "$1" != explicit-false-high ]; then
      export TEST_PRESERVE_CACHE=true TEST_EXPECT_DROPIN=original-drop-in
      . /docker-entrypoint-init.d/99-test.sh
    else
      test "$(cat /var/www/html/wp-content/object-cache.php)" = original-drop-in
      test ! -e /tmp/cache-sentinel
      test -e /tmp/transient-sentinel
      test "$(grep -c "^cache flush$" /tmp/wp-calls)" -eq 1
      ! grep -q "^redis enable" /tmp/wp-calls
    fi
    echo PRESET_VERIFIED
  ' test "$scenario" > "$test_dir/frankenphp-preset-$scenario.log" 2>&1
  grep -qx PRESET_VERIFIED "$test_dir/frankenphp-preset-$scenario.log"
  printf 'PASS FrankenPHP cache policy: %s\n' "$scenario"
done

docker run --rm --network none --platform linux/amd64 -e SKIP_CACHE_FLUSH=false "$test_image" > "$test_dir/explicit-invalidation.log"
test "$(grep -c '^cache flush$' "$test_dir/explicit-invalidation.log")" -eq 1
! grep -q '^redis enable' "$test_dir/explicit-invalidation.log"
printf 'PASS explicit Apache startup invalidation runs once\n'

status=0
docker run --rm --network none --platform linux/amd64 -e SKIP_CACHE_FLUSH=false \
  -e TEST_CACHE_FLUSH_FAIL=true "$test_image" > "$test_dir/flush-failure.log" 2>&1 || status=$?
test "$status" -eq 1
! grep -q SERVER_STARTED "$test_dir/flush-failure.log"
grep -q 'Failed to flush cache' "$test_dir/flush-failure.log"
printf 'PASS failed requested invalidation stops web startup\n'


docker run --rm --network none --platform linux/amd64 --entrypoint /tests/frankenphp-entrypoint.sh \
  -e SKIP_CACHE_FLUSH=false "$test_image" sh -ec '
  test "$WORDPRESS_COMMAND_MODE" = true
  test "$$" -eq 1
  test "$1" = "argument with spaces"
  ! grep -Eq "^(acorn|cache flush|redis enable)" /tmp/wp-calls
  wp cache flush
  test "$(grep -c "^cache flush$" /tmp/wp-calls)" -eq 1
  test -e /tmp/transient-sentinel
  echo FRANKENPHP_COMMAND_COMPLETED
' command-test 'argument with spaces' > "$test_dir/frankenphp-command.log"
grep -qx FRANKENPHP_COMMAND_COMPLETED "$test_dir/frankenphp-command.log"
printf 'PASS FrankenPHP commands preserve startup cache and execute requested flush once\n'

docker run --rm --network none --platform linux/amd64 --entrypoint /tests/frankenphp-entrypoint.sh \
  "$test_image" frankenphp run > "$test_dir/frankenphp-server.log"
grep -qx FRANKENPHP_SERVER_STARTED "$test_dir/frankenphp-server.log"
printf 'PASS FrankenPHP server command keeps web initialization\n'

{
  printf 'FROM %s\nCOPY variants/frankenphp/bin/wordpress-entrypoint.sh /usr/local/bin/wordpress-entrypoint.sh\n' "$test_image"
  sed -n '/^ENTRYPOINT /p; /^CMD /p' "$repo_dir/variants/frankenphp/Dockerfile.template"
} > "$test_dir/Dockerfile.frankenphp"
docker build --quiet --platform linux/amd64 -f "$test_dir/Dockerfile.frankenphp" \
  -t "$frankenphp_test_image" "$repo_dir" > "$test_dir/frankenphp-build.log"
docker run --rm --network none --platform linux/amd64 "$frankenphp_test_image" > "$test_dir/frankenphp-default-server.log"
grep -qx FRANKENPHP_SERVER_STARTED "$test_dir/frankenphp-default-server.log"
printf 'PASS FrankenPHP default server command is retained\n'

docker run --rm --network none --platform linux/amd64 "$test_image" /init > "$test_dir/explicit-server.log"
grep -qx 'SERVER_STARTED' "$test_dir/explicit-server.log"
printf 'PASS explicit server initialization\n'

for mode in default explicit; do
  docker run --rm --network none --platform linux/amd64 --entrypoint bash "$test_image" -ec '
    touch /tmp/inrage-command-mode
    if [ "$1" = explicit ]; then
      exec /usr/local/bin/wordpress-entrypoint.sh /init
    fi
    exec /usr/local/bin/wordpress-entrypoint.sh
  ' marker-test "$mode" > "$test_dir/marker-$mode.log"
  grep -qx SERVER_STARTED "$test_dir/marker-$mode.log"
  printf 'PASS server removes command marker: %s\n' "$mode"
done

docker run --rm --network none --platform linux/amd64 "$test_image" sh -ec '
  test "$$" -eq 1
  test "$WORDPRESS_COMMAND_MODE" = true
  test -f /tmp/inrage-command-mode
  test "$TEST_INIT_EXPORT" = preserved
  test "$1" = "argument with spaces"
  test "$2" = "*"
  test "$(cat /var/www/html/wp-content/object-cache.php)" = original-drop-in
  test "$(cat /tmp/cache-sentinel)" = original-cache
  test "$(cat /tmp/transient-sentinel)" = original-transient
  ! grep -Eq "^(redis enable|acorn|cache flush)" /tmp/wp-calls
  test -s /var/www/html/wp-config.php
  test -s /etc/msmtprc
  printf "COMMAND_COMPLETED\n"
' command-test 'argument with spaces' '*' > "$test_dir/command.log"
grep -qx 'COMMAND_COMPLETED' "$test_dir/command.log"
! grep -q 'SERVER_STARTED' "$test_dir/command.log"
printf 'PASS command arguments, initialization and cache preservation\n'

status=0
docker run --rm --network none --platform linux/amd64 "$test_image" sh -c 'exit 37' > "$test_dir/exit.log" 2>&1 || status=$?
test "$status" -eq 37
printf 'PASS command exit status\n'

status=0
docker run --rm --network none --platform linux/amd64 -e TEST_INIT_FAIL=true "$test_image" sh -c 'echo MUST_NOT_RUN' \
  > "$test_dir/failure.log" 2>&1 || status=$?
test "$status" -eq 23
! grep -q 'MUST_NOT_RUN' "$test_dir/failure.log"
printf 'PASS initialization failure stops the command\n'

status=0
docker run --rm --network none --platform linux/amd64 -e TEST_ROCKET_CONFIG_FAIL=true "$test_image" sh -c 'echo MUST_NOT_RUN' \
  > "$test_dir/rocket-failure.log" 2>&1 || status=$?
test "$status" -eq 42
! grep -q 'MUST_NOT_RUN' "$test_dir/rocket-failure.log"
printf 'PASS WP Rocket configuration failure stops the command\n'

status=0
docker run --rm --network none --platform linux/amd64 -e TEST_ROCKET_CONFIG_FAIL=bootstrap "$test_image" \
  > "$test_dir/rocket-bootstrap-failure.log" 2>&1 || status=$?
test "$status" -eq 1
! grep -q 'SERVER_STARTED' "$test_dir/rocket-bootstrap-failure.log"
grep -q 'Could not generate WP Rocket configuration.' "$test_dir/rocket-bootstrap-failure.log"
printf 'PASS existing MU configuration failure stops server startup\n'

for variant in apache frankenphp; do
  status=0
  docker run --rm --network none --platform linux/amd64 --entrypoint bash \
    -e TEST_ROCKET_CONFIG_FAIL=bootstrap -e 'TEST_ROCKET_MESSAGE=Could not generate WP Rocket advanced cache.' \
    "$test_image" -ec '
    if [ "$1" = apache ]; then
      exec /usr/local/bin/wordpress-entrypoint.sh
    fi
    exec /tests/frankenphp-entrypoint.sh frankenphp run
  ' advanced-cache-test "$variant" > "$test_dir/advanced-bootstrap-$variant.log" 2>&1 || status=$?
  test "$status" -eq 1
  ! grep -q SERVER_STARTED "$test_dir/advanced-bootstrap-$variant.log"
  grep -Fq 'Could not generate WP Rocket advanced cache.' "$test_dir/advanced-bootstrap-$variant.log"
  printf 'PASS advanced cache failure stops %s bootstrap\n' "$variant"
done

docker run --rm --network none --platform linux/amd64 -e TEST_WP_UNINSTALLED=true "$test_image" sh -c 'echo INSTALL_ALLOWED' \
  > "$test_dir/uninstalled.log"
grep -qx 'INSTALL_ALLOWED' "$test_dir/uninstalled.log"
printf 'PASS uninstalled WordPress permits commands\n'

for scenario in ready uninstalled bootstrap-failure; do
  status=0
  docker run --rm --network none --platform linux/amd64 --entrypoint bash "$test_image" -ec '
    gomplate() { cp "$2" "$4"; }
    export WORDPRESS_NO_CREATE_CONFIG=true
    case "$1" in
      uninstalled) export TEST_WP_UNINSTALLED=true ;;
      bootstrap-failure) export TEST_ROCKET_CONFIG_FAIL=bootstrap ;;
    esac
    source /tests/frankenphp-init.sh
    if [ "$1" = uninstalled ]; then
      ! grep -qx "eval " /tmp/wp-calls
    else
      grep -qx "eval " /tmp/wp-calls
    fi
    echo FRANKENPHP_INIT_COMPLETED
  ' test "$scenario" > "$test_dir/frankenphp-$scenario.log" 2>&1 || status=$?
  if [ "$scenario" = bootstrap-failure ]; then
    test "$status" -eq 1
    ! grep -q 'FRANKENPHP_INIT_COMPLETED' "$test_dir/frankenphp-$scenario.log"
  else
    test "$status" -eq 0
    grep -qx 'FRANKENPHP_INIT_COMPLETED' "$test_dir/frankenphp-$scenario.log"
  fi
  printf 'PASS FrankenPHP initialization: %s\n' "$scenario"
done

for failure in bootstrap true; do
  status=0
  docker run --rm --network none --platform linux/amd64 --entrypoint bash \
    -e "TEST_ROCKET_CONFIG_FAIL=$failure" "$test_image" -ec '
    gomplate() { cp "$2" "$4"; }
    export WORDPRESS_NO_CREATE_CONFIG=true
    ( . /tests/frankenphp-init.sh; echo MUST_NOT_RUN )
    echo TARGET_MUST_NOT_RUN
  ' > "$test_dir/frankenphp-wrapper-$failure.log" 2>&1 || status=$?
  if [ "$failure" = bootstrap ]; then
    test "$status" -eq 1
  else
    test "$status" -eq 42
  fi
  grep -Fq 'Could not generate WP Rocket configuration.' "$test_dir/frankenphp-wrapper-$failure.log"
  ! grep -q 'MUST_NOT_RUN' "$test_dir/frankenphp-wrapper-$failure.log"
  printf 'PASS FrankenPHP initialization failure stops target: %s\n' "$failure"
done

docker run --rm --network none --platform linux/amd64 "$test_image" sh -ec '
  wp cache flush
  test ! -e /tmp/cache-sentinel
  test -e /tmp/transient-sentinel
  test "$(grep -c "^cache flush$" /tmp/wp-calls)" -eq 1
' > "$test_dir/explicit.log"
printf 'PASS explicitly requested cache command\n'

for scenario in web web-false https http subdirectory explicit-http explicit-https explicit-blog missing-home empty-home; do
  docker run --rm --network none --platform linux/amd64 --entrypoint php "$test_image" \
    /tests/wp-cli-url-context.php "$scenario" /tests/production.php
done

for scenario in web web-false plugin-absent no-options missing partial existing generation-failed advanced-missing advanced-existing advanced-empty advanced-symlink advanced-disabled advanced-undefined advanced-invalid advanced-filtered advanced-failed advanced-empty-result advanced-both advanced-api-absent advanced-cache-existing advanced-cache-failed; do
  docker run --rm --network none --platform linux/amd64 --entrypoint php "$test_image" \
    /tests/wp-rocket-config.php "$scenario" /tests/production.php
done

for scenario in unset off on; do
  docker run --rm --network none --platform linux/amd64 --entrypoint php "$test_image" \
    /tests/wp-rocket-souin.php "$scenario" /tests/inr-wp-rocket-souin.php
done

for scenario in missing custom existing readonly parent-readonly symlink opt-out failed legacy-return not-apache; do
  mounts=()
  if [ "$scenario" = not-apache ]; then
    mounts+=(--tmpfs /etc/s6-overlay/s6-rc.d/apache)
  fi
  docker run --rm --network none --platform linux/amd64 --entrypoint php "${mounts[@]}" "$test_image" \
    /tests/wp-rocket-htaccess.php "$scenario" /tests/production.php
done
