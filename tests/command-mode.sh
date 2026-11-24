#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
test_image="wordpress-command-test:$(date +%s)-$$"

cleanup() {
  docker image rm -f "$test_image" >/dev/null 2>&1 || true
  rm -rf "$test_dir"
}
trap cleanup EXIT

docker build --quiet --platform linux/amd64 --build-arg "BASE_IMAGE=${BASE_IMAGE:-inrage/docker-wordpress:8.3-redis}" \
  -f "$repo_dir/tests/Dockerfile" -t "$test_image" "$repo_dir" > "$test_dir/build.log"

docker run --rm --network none --platform linux/amd64 "$test_image" > "$test_dir/server.log"
grep -qx 'SERVER_STARTED' "$test_dir/server.log"
grep -qx 'redis enable --force' "$test_dir/server.log"
grep -qx 'acorn optimize' "$test_dir/server.log"
grep -qx 'cache flush' "$test_dir/server.log"
printf 'PASS default server initialization\n'

docker run --rm --network none --platform linux/amd64 "$test_image" /init > "$test_dir/explicit-server.log"
grep -qx 'SERVER_STARTED' "$test_dir/explicit-server.log"
printf 'PASS explicit server initialization\n'

docker run --rm --network none --platform linux/amd64 "$test_image" sh -ec '
  test "$$" -eq 1
  test "$WORDPRESS_COMMAND_MODE" = true
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
  docker run --rm --network none --platform linux/amd64 --entrypoint sh \
    -e "TEST_ROCKET_CONFIG_FAIL=$failure" "$test_image" -ec '
    gomplate() { cp "$2" "$4"; }
    export WORDPRESS_NO_CREATE_CONFIG=true
    ( . /tests/frankenphp-init.sh; echo MUST_NOT_RUN ) || echo INIT_FAILED_CONTINUING
    ! grep -qx "cli has-command redis enable" /tmp/wp-calls
    echo WRAPPER_CONTINUED
  ' > "$test_dir/frankenphp-wrapper-$failure.log" 2>&1
  grep -Fq 'Could not generate WP Rocket configuration.' "$test_dir/frankenphp-wrapper-$failure.log"
  grep -qx 'INIT_FAILED_CONTINUING' "$test_dir/frankenphp-wrapper-$failure.log"
  grep -qx 'WRAPPER_CONTINUED' "$test_dir/frankenphp-wrapper-$failure.log"
  ! grep -q 'MUST_NOT_RUN' "$test_dir/frankenphp-wrapper-$failure.log"
  printf 'PASS FrankenPHP wrapper preserves policy and stops failed hook: %s\n' "$failure"
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

for scenario in web web-false plugin-absent no-options missing partial existing generation-failed; do
  docker run --rm --network none --platform linux/amd64 --entrypoint php "$test_image" \
    /tests/wp-rocket-config.php "$scenario" /tests/production.php
done
