#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM inrage/docker-php:8.0

USER root


RUN set -ex; \
    \
    cd /tmp; \
    wp_cli_version="2.11.0"; \
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
