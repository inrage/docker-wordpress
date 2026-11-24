export TEST_INIT_EXPORT=preserved
if [[ "${TEST_INIT_FAIL:-false}" == true ]]; then
  return 23
fi
