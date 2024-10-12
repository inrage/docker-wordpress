#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM wordpress:cli-php8.2 AS wp-cli

FROM inrage/docker-php:8.2

# install WP-CLI
COPY --from=wp-cli /usr/local/bin/wp /usr/local/bin/wp


USER root

RUN set -eux; \
    pecl install redis; \
    docker-php-ext-enable redis;

USER inr

COPY templates /etc/gotpl/
COPY bin /usr/local/bin

COPY init /docker-entrypoint-init.d/
