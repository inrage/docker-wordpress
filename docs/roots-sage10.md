```Dockerfile
# SETUP
ARG THEME_PATH=wp-content/themes/mytheme
ARG NODE_VERSION=18
ARG PHP_VERSION=8.0
ARG COMPOSER_VERSION=latest

# THEME ASSETS
FROM node:${NODE_VERSION}-alpine as theme-assets
ARG THEME_PATH
WORKDIR /srv/app
COPY ${THEME_PATH}/package.json ${THEME_PATH}/yarn.lock ./
RUN yarn install --frozen-lockfile --non-interactive

COPY --link ${THEME_PATH} ./
RUN yarn build --ci

# THEME VENDORS
FROM composer:${COMPOSER_VERSION} as theme-vendors
ARG THEME_PATH
WORKDIR /app
COPY ${THEME_PATH}/composer* .
RUN composer install --ignore-platform-req=ext-soap --ignore-platform-req=ext-gd

WORKDIR /app

FROM inrage/docker-wordpress:${PHP_VERSION}-redis

ARG THEME_PATH

COPY --chown=inr . .
RUN cp -a /usr/src/wordpress/wp-config-docker.php wp-config.php
COPY --chown=inr --from=theme-vendors /app/vendor ${THEME_PATH}/vendor
COPY --chown=inr --from=theme-assets /srv/app/public ${THEME_PATH}/public
```
