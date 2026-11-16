#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM inrage/frankenphp:8.4

USER root

ADD --chmod=755 https://github.com/wp-cli/wp-cli/releases/download/v2.12.0/wp-cli-2.12.0.phar /usr/local/bin/wp

COPY Caddyfile /etc/frankenphp/Caddyfile
COPY mu-plugins /etc/inrage/mu-plugins/
COPY templates /etc/gomplate/
COPY init /docker-entrypoint-init.d/
COPY bin /usr/local/bin/

RUN set -eux; \
	find /docker-entrypoint-init.d -type f -name '*.sh' -exec chmod +x {} +; \
	chown -R inr:inr /etc/inrage

USER inr
