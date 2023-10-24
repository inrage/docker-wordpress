#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$1" == apache2* ]]; then
  uid="$(id -u)"
  	gid="$(id -g)"
  	if [ "$uid" = '0' ]; then
  		case "$1" in
  			apache2*)
  				user="${APACHE_RUN_USER:-www-data}"
  				group="${APACHE_RUN_GROUP:-www-data}"

  				# strip off any '#' symbol ('#1000' is valid syntax for Apache)
  				pound='#'
  				user="${user#$pound}"
  				group="${group#$pound}"
  				;;
  		esac
  	else
  		user="$uid"
  		group="$gid"
  	fi

  	# if the directory exists and WordPress doesn't appear to be installed AND the permissions of it are root:root, let's chown it (likely a Docker-created directory)
    if [ "$uid" = '0' ] && [ "$(stat -c '%u:%g' .)" = '0:0' ]; then
      chown "$user:$group" .
    fi
fi

exec "$@"
