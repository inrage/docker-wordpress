FROM wordpress:cli-php8.0 AS wp-cli

FROM inrage/docker-php:8.0

# install WP-CLI
COPY --from=wp-cli /usr/local/bin/wp /usr/local/bin/wp

COPY --chown=inr wp-config-docker.php /usr/src/wordpress/
COPY bin /usr/local/bin