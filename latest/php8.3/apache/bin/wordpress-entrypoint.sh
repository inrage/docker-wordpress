#!/usr/bin/env bash
set -eo pipefail

if [[ $# -eq 0 ]]; then
  rm -f /tmp/inrage-command-mode
  exec /init
fi

if [[ "$1" == /init ]]; then
  rm -f /tmp/inrage-command-mode
  exec "$@"
fi

touch /tmp/inrage-command-mode
export WORDPRESS_COMMAND_MODE=true
. /etc/s6-overlay/scripts/init-templates
exec "$@"
