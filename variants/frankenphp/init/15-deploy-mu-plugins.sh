#!/usr/bin/env bash
set -e

if [ ! -d /etc/inrage/mu-plugins ]; then
  exit 0
fi

content_dir="$(wp eval 'echo defined("WP_CONTENT_DIR") ? WP_CONTENT_DIR : ABSPATH . "wp-content";' 2>/dev/null || true)"
if [ -z "$content_dir" ] || [ ! -d "$content_dir" ]; then
  content_dir="/var/www/html/public/content"
fi
[ -d "$content_dir" ] || content_dir="/var/www/html/wp-content"

mkdir -p "${content_dir}/mu-plugins"

for f in /etc/inrage/mu-plugins/*.php; do
  [ -f "$f" ] || continue
  cp -f "$f" "${content_dir}/mu-plugins/"
done

echo "✅ [init] mu-plugins inRage déployés dans ${content_dir}/mu-plugins"
