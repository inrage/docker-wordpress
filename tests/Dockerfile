ARG BASE_IMAGE=inrage/docker-wordpress:8.3-redis
FROM ${BASE_IMAGE}

USER root
RUN rm -f /docker-entrypoint-init.d/* \
    && mkdir -p /var/www/html/wp-content \
    && printf 'original-drop-in\n' > /var/www/html/wp-content/object-cache.php \
    && printf 'original-cache\n' > /tmp/cache-sentinel \
    && printf 'original-transient\n' > /tmp/transient-sentinel \
    && chown -R inr:inr /var/www/html /tmp/cache-sentinel /tmp/transient-sentinel

COPY init/ /docker-entrypoint-init.d/
COPY bin/wordpress-entrypoint.sh /usr/local/bin/wordpress-entrypoint.sh
COPY tests/fixtures/wp /usr/local/bin/wp
COPY tests/fixtures/init /init
COPY tests/fixtures/99-test.sh /docker-entrypoint-init.d/99-test.sh
RUN chmod +x /usr/local/bin/wordpress-entrypoint.sh /usr/local/bin/wp /init

USER inr
ENTRYPOINT ["/usr/local/bin/wordpress-entrypoint.sh"]
