#!/usr/bin/env bash

set -e

if [[ "${WORDPRESS_COMMAND_MODE:-false}" == "true" ]]; then
  return
fi

if wp acorn &>/dev/null; then
  echo "wp acorn command is available"

  echo "Clearing Acorn and optimize..."
  wp acorn optimize

  # Run wp acorn view:cache command
  echo "Running wp acorn icons:cache..."
  if wp acorn icons &>/dev/null; then
    echo "wp acorn icons command is available"
    if ! wp acorn icons:cache; then
      echo "Failed to cache icons" >&2
      exit 1
    fi
  else
    echo "wp acorn icons command is not available... skipping Acorn commands."
  fi
else
  echo "project is not using Acorn or Acorn is not installed... skipping Acorn commands."
fi

if [ "${SKIP_CACHE_FLUSH:-true}" != false ]; then
  echo "Cache flush skipped."
  return
fi

if wp cache &>/dev/null; then
  echo "Flushing cache..."
  if ! wp cache flush; then
    echo "Failed to flush cache" >&2
    exit 1
  fi
else
  echo "WordPress cache is not available... skipping cache flush."
fi
