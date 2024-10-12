#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM wordpress:cli-php7.4 AS wp-cli

FROM inrage/docker-php:7.4

# install WP-CLI
COPY --from=wp-cli /usr/local/bin/wp /usr/local/bin/wp


USER root


USER inr

COPY templates /etc/gotpl/
COPY bin /usr/local/bin

COPY init /docker-entrypoint-init.d/
