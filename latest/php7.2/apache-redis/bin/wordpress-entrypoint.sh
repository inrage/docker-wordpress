#!/usr/bin/env bash
set -eo pipefail

if [[ $# -eq 0 ]]; then
  exec /init
fi

if [[ "$1" == /init ]]; then
  exec "$@"
fi

export WORDPRESS_COMMAND_MODE=true
. /etc/s6-overlay/scripts/init-templates
exec "$@"
