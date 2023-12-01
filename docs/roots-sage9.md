```Dockerfile
## SETUP
ARG THEME_PATH=wp-content/themes/mytheme
ARG NODE_VERSION=10
ARG COMPOSER_VERSION=1.10.7
ARG PHP_VERSION=7.4

# THEME ASSETS
FROM node:${NODE_VERSION} as node_base
ARG THEME_PATH
WORKDIR /srv/app
COPY --link ${THEME_PATH}/package.json ${THEME_PATH}/yarn.lock ./
RUN yarn install

COPY --link ${THEME_PATH} ./
RUN yarn build:production

# THEME VENDORS
FROM composer:${COMPOSER_VERSION} as theme-asset
ARG THEME_PATH
WORKDIR /app
COPY ${THEME_PATH}/composer* .
RUN composer install

FROM inrage/docker-wordpress:${PHP_VERSION}
ARG THEME_PATH
COPY --chown=inr . .
RUN cp -a /usr/src/wordpress/wp-config-docker.php wp-config.php

COPY --chown=inr --from=theme-asset /app/vendor /var/www/html/${THEME_PATH}/vendor
COPY --chown=inr --from=node_base /srv/app/dist /var/www/html/${THEME_PATH}/dist
```
