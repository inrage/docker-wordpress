FROM wordpress:cli-php5.6 AS wp-cli
FROM wordpress:php5.6-apache

WORKDIR /var/www/html

RUN echo "deb http://deb.debian.org/debian buster main" > /etc/apt/sources.list

RUN set -eux; \
	apt-get update; \
	apt-get install -y --allow-unauthenticated --no-install-recommends \
    mariadb-client \
    msmtp \
    msmtp-mta \
	; \
	rm -rf /var/lib/apt/lists/*

# use production php.ini
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# apply custom PHP configuration
COPY php-custom.ini "$PHP_INI_DIR/conf.d/zzz-custom-php.ini"

RUN set -eux; \
	a2enmod rewrite expires; \
	\
    # https://httpd.apache.org/docs/2.4/mod/mod_remoteip.html
	a2enmod remoteip; \
	{ \
		echo 'RemoteIPHeader X-Forwarded-For'; \
        # these IP ranges are reserved for "private" use and should thus *usually* be safe inside Docker
		echo 'RemoteIPInternalProxy 10.0.0.0/8'; \
		echo 'RemoteIPInternalProxy 172.16.0.0/12'; \
		echo 'RemoteIPInternalProxy 192.168.0.0/16'; \
		echo 'RemoteIPInternalProxy 169.254.0.0/16'; \
		echo 'RemoteIPInternalProxy 127.0.0.0/8'; \
	} > /etc/apache2/conf-available/remoteip.conf; \
	a2enconf remoteip; \
    # https://github.com/docker-library/wordpress/issues/383#issuecomment-507886512
    # (replace all instances of "%h" with "%a" in LogFormat)
	find /etc/apache2 -type f -name '*.conf' -exec sed -ri 's/([[:space:]]*LogFormat[[:space:]]+"[^"]*)%h([^"]*")/\1%a\2/g' '{}' +

RUN echo "sendmail_path=/usr/bin/msmtp -t --read-envelope-from" > /usr/local/etc/php/conf.d/php-sendmail.ini

RUN set -eux; \
    { \
      echo 'account default'; \
      echo 'host relay.mailhub'; \
      echo 'port 25'; \
    } > /etc/msmtprc

# install WP-CLI
COPY --from=wp-cli /usr/local/bin/wp /usr/local/bin/wp

WORKDIR /var/www/html

RUN set -eux; \
    chmod 755 /var/www/html;

COPY --chown=www-data wp-config-docker.php /usr/src/wordpress/

CMD ["apache2-foreground"]
