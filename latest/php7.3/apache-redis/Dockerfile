#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM inrage/docker-php:7.3

USER root

RUN set -eux; \
    if [ -f /etc/apt/sources.list.d/sury-php.list ]; then \
    apt-get update; \
    apt-get install -y --no-install-recommends "php${PHP_VERSION%.*}-redis" "php${PHP_VERSION%.*}-igbinary"; \
    rm -rf /var/lib/apt/lists/*; \
    exit 0; \
    fi; \
    apt update && apt install -y libzstd-dev liblz4-dev; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /tmp/pecl-src; \
    curl -fsSL https://github.com/igbinary/igbinary/archive/refs/tags/3.2.17RC1.tar.gz | tar xz -C /tmp/pecl-src; \
    curl -fsSL https://github.com/phpredis/phpredis/archive/refs/tags/6.3.0.tar.gz | tar xz -C /tmp/pecl-src; \
    curl -fsSL https://github.com/nemequ/liblzf/archive/fb25820c3c0aeafd127956ae6c115063b47e459a.tar.gz | tar xz --strip-components=1 -C /tmp/pecl-src/phpredis-6.3.0/liblzf; \
    pecl install /tmp/pecl-src/igbinary-3.2.17RC1/package.xml; \
    pecl install --configureoptions='enable-redis-igbinary="yes" enable-redis-lzf="yes" enable-redis-zstd="yes" enable-redis-lz4="yes"' /tmp/pecl-src/phpredis-6.3.0/package.xml; \
    rm -rf /tmp/pecl-src; \
    docker-php-ext-enable redis igbinary;

RUN set -ex; \
    \
    cd /tmp; \
    wp_cli_version="null"; \
    url="https://github.com/wp-cli/wp-cli/releases/download/v${wp_cli_version}/wp-cli-${wp_cli_version}.phar"; \
    curl -o wp.phar -fSL "${url}"; \
    chmod +x wp.phar; \
    mv wp.phar /usr/local/bin/wp; \
    \
    url="https://raw.githubusercontent.com/wp-cli/wp-cli/v${wp_cli_version}/utils/wp-completion.bash"; \
    curl -o /usr/local/include/wp-completion.bash -fSL "${url}"; \
    chmod +x /usr/local/include/wp-completion.bash; \
    cd /home/inr; \
    echo "source /usr/local/include/wp-completion.bash" | tee -a .bash_profile .bashrc;

USER inr

COPY templates /etc/gotpl/
COPY bin /usr/local/bin

COPY init /docker-entrypoint-init.d/
