ARG BASE_IMAGE=inrage/docker-wordpress:8.3-redis
FROM ${BASE_IMAGE}

USER root
RUN rm -f /docker-entrypoint-init.d/* \
    && mkdir -p /var/www/html/wp-content \
    && printf 'original-drop-in\n' > /var/www/html/wp-content/object-cache.php \
    && printf 'original-cache\n' > /tmp/cache-sentinel \
    && printf 'original-transient\n' > /tmp/transient-sentinel \
    && mkdir -p /tests/redis/pro/stubs /tests/redis/community/includes \
    && printf 'pro-drop-in\n' > /tests/redis/pro/stubs/object-cache.php \
    && printf 'community-drop-in\n' > /tests/redis/community/includes/object-cache.php \
    && chown -R inr:inr /var/www/html /tmp/cache-sentinel /tmp/transient-sentinel

COPY init/ /docker-entrypoint-init.d/
COPY bin/wordpress-entrypoint.sh /usr/local/bin/wordpress-entrypoint.sh
COPY tests/fixtures/wp /usr/local/bin/wp
COPY tests/fixtures/init /init
COPY tests/fixtures/99-test.sh /docker-entrypoint-init.d/99-test.sh
COPY templates/production.php.tmpl /tests/production.php
COPY tests/wp-cli-url-context.php /tests/wp-cli-url-context.php
COPY tests/wp-rocket-config.php /tests/wp-rocket-config.php
COPY templates/production.php.tmpl /etc/gomplate/production.php.tmpl
COPY variants/frankenphp/init/10-wordpress-php.sh /tests/frankenphp-init.sh
COPY variants/frankenphp/init/00-presets.sh /tests/frankenphp-presets.sh
RUN chmod +x /usr/local/bin/wordpress-entrypoint.sh /usr/local/bin/wp /init

USER inr
ENTRYPOINT ["/usr/local/bin/wordpress-entrypoint.sh"]
