#!/usr/bin/env bash

set -e

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

if wp cache &>/dev/null; then
  echo "wp cache command is available"

  # Run wp cache flush command
  if [ "${SKIP_CACHE_FLUSH:-false}" = "true" ]; then
    echo "⚡ SKIP_CACHE_FLUSH is enabled : The existing cache is retained (High-Traffic Mode)."
  else
    echo "Flushing cache..."
    if ! wp cache flush; then
      echo "Failed to flush cache" >&2
    fi
  fi
else
  echo "project is not using cache or cache is not installed... skipping cache commands."
fi
