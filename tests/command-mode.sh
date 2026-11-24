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

docker run --rm --network none --platform linux/amd64 "$test_image" sh -ec '
  wp cache flush
  test ! -e /tmp/cache-sentinel
  test -e /tmp/transient-sentinel
  test "$(grep -c "^cache flush$" /tmp/wp-calls)" -eq 1
' > "$test_dir/explicit.log"
printf 'PASS explicitly requested cache command\n'
