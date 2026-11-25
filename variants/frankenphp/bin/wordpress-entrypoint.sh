#!/usr/bin/env bash
set -eo pipefail

if [[ $# -gt 0 && ( "${1##*/}" != frankenphp || "${2:-}" != run ) ]]; then
  export WORDPRESS_COMMAND_MODE=true
fi

exec /usr/local/bin/inrage-entrypoint.sh "$@"
