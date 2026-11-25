export TEST_INIT_EXPORT=preserved
if [[ "${TEST_INIT_FAIL:-false}" == true ]]; then
  return 23
fi

if [ "${TEST_PRESERVE_CACHE:-false}" = true ]; then
  test "$(cat /tmp/cache-sentinel)" = original-cache
  test "$(cat /tmp/transient-sentinel)" = original-transient
  ! grep -Eq '^(redis enable|cache flush)' /tmp/wp-calls
  if [ "${TEST_EXPECT_DROPIN}" = absent ]; then
    test ! -f /var/www/html/wp-content/object-cache.php
  else
    test "$(cat /var/www/html/wp-content/object-cache.php)" = "$TEST_EXPECT_DROPIN"
  fi
fi
