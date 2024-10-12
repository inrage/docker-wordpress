#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM wordpress:cli-php8.1 AS wp-cli

FROM inrage/docker-php:8.1

# install WP-CLI
COPY --from=wp-cli /usr/local/bin/wp /usr/local/bin/wp

COPY --chown=inr wp-config-docker.php /usr/src/wordpress/
COPY bin /usr/local/bin

USER root

RUN set -eux; \
    pecl install redis; \
    docker-php-ext-enable redis;

COPY crontab /etc/crontab
RUN chmod 0644 /etc/crontab

USER inr
