# Docker WordPress

[![Docker Pulls](https://img.shields.io/docker/pulls/inrage/docker-wordpress.svg)](https://hub.docker.com/r/inrage/docker-wordpress)
[![Docker Stars](https://img.shields.io/docker/stars/inrage/docker-wordpress.svg)](https://hub.docker.com/r/inrage/docker-wordpress)
[![Docker Image Size](https://img.shields.io/docker/image-size/inrage/docker-wordpress.svg)](https://hub.docker.com/r/inrage/docker-wordpress)

The provided Docker image allows you to deploy your WordPress website in production with a powerful configuration, an integrated SMTP relay, and support for PHP Redis.

Key features:

- All images are based on [inrage/docker-php](https://github.com/inrage/docker-php)
- [Docker Hub](https://hub.docker.com/r/inrage/docker-wordpress)
- Includes an SMTP server for outgoing emails
- Supports PHP Redis
- Advanced configuration for optimal performance
- Easy deployment and scalability with Docker

Supported tags:

- latest:
  - `8.4` ([Dockerfile](latest/php8.4/apache/Dockerfile)), `8.4-redis` ([Dockerfile](latest/php8.4/apache-redis/Dockerfile))
  - `8.3` ([Dockerfile](latest/php8.3/apache/Dockerfile)), `8.3-redis` ([Dockerfile](latest/php8.3/apache-redis/Dockerfile))
  - `8.2` ([Dockerfile](latest/php8.2/apache/Dockerfile)), `8.2-redis` ([Dockerfile](latest/php8.2/apache-redis/Dockerfile))
  - `8.1` ([Dockerfile](latest/php8.1/apache/Dockerfile)), `8.1-redis` ([Dockerfile](latest/php8.1/apache-redis/Dockerfile))
  - `8.0` ([Dockerfile](latest/php8.0/apache/Dockerfile)), `8.0-redis` ([Dockerfile](latest/php8.0/apache-redis/Dockerfile))
  - `7.4` ([Dockerfile](latest/php7.4/apache/Dockerfile)), `7.4-redis` ([Dockerfile](latest/php7.4/apache-redis/Dockerfile))
- legacy:
  - `7.2` ([Dockerfile](legacy/php7.2/apache/Dockerfile))
  - `7.0` ([Dockerfile](legacy/php7.0/apache/Dockerfile))
  - `5.6` ([Dockerfile](legacy/php5.6/apache/Dockerfile))

## Installation

To install, you need to either mount a directory into `/var/www/html` or customize the destination directory according to your needs. Here's how to proceed:

### Dockerfile

```Dockerfile
FROM inrage/docker-wordpress:8.4

COPY --chown=inr . .
```

### Docker Swarm Configuration

We are using a Docker Swarm configuration with Traefik as a reverse proxy. Here's an example of a `docker-compose.yml` file:

```yaml
version: "3.8"

services:
  redis:
    hostname: mywebsite.redis
    image: redis:7.2.0
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
    networks:
      - internal-network
    command: redis-server --maxmemory 1024mb --maxmemory-policy allkeys-lru --appendonly yes
    environment:
      TZ: "Europe/Paris"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - redis_data:/data
  web:
    image: inrage/mycustomimage
    networks:
      database:
      traefik-public:
      internal-network:
    environment:
      WORDPRESS_DB_HOST: db-master.db
      WORDPRESS_DB_USER: mywebsite
      WORDPRESS_DB_PASSWORD: "mywebsitepassword"
      WORDPRESS_DB_NAME: mywebsite
      WORDPRESS_TABLE_PREFIX: gr_
      WORDPRESS_CONFIG_EXTRA: |
        define( 'DISALLOW_FILE_MODS', true );	
        define( 'WP_MEMORY_LIMIT', '512M' );
        define( 'WP_REDIS_HOST', 'mywebsite.redis');

      TZ: "Europe/Paris"
    volumes:
      - /host/website/mywebsite/uploads:/var/www/html/wp-content/uploads

    deploy:
      replicas: 1
      labels:
        - traefik.enable=true
        - traefik.docker.network=traefik-public
        - traefik.constraint-label=traefik-public
        - traefik.http.routers.mywebsite-http.rule=Host(`www.inrage.fr`, `inrage.fr`)
        - traefik.http.routers.mywebsite-http.entrypoints=http
        - traefik.http.routers.mywebsite-http.middlewares=https-redirect
        - traefik.http.routers.mywebsite-https.rule=Host(`www.inrage.fr`, `inrage.fr`)
        - traefik.http.routers.mywebsite-https.entrypoints=https
        - traefik.http.routers.mywebsite-https.tls=true
        - traefik.http.routers.mywebsite-https.tls.certresolver=le
        - traefik.http.services.mywebsite.loadbalancer.server.port=80

volumes:
  redis_data:

networks:
  internal-network:
  database:
    external: true
  traefik-public:
    external: true
```

## One-off commands

The Apache images start the web server when no command is provided. An explicit command, such as `wp cron event run --due-now`, prepares the PHP, mail and WordPress configuration and then runs directly without starting Apache or PHP-FPM.

Command startup preserves Redis data and SQL transients. Official Object Cache Pro and Redis Object Cache drop-ins are installed or updated from the active plugin only when their contents differ, without enabling or flushing Redis. Custom drop-ins are retained; other Redis plugins require an existing drop-in. Acorn optimization and startup cache flushing are skipped during command startup, even with `SKIP_CACHE_FLUSH=false`; operations explicitly requested by the command still run.

WP-CLI uses the configured WordPress home URL when no URL was supplied through its arguments, aliases or configuration. This preserves the site's HTTP or HTTPS context for commands such as cache preloading. Explicit `--url` and legacy `--blog` values take precedence, and an uninstalled site with no home URL is left unchanged.

```yaml
cronjob:
  image: inrage/docker-wordpress:8.3-redis
  command: ["wp", "cron", "event", "run", "--due-now"]
```

Use the same database configuration and persistent WordPress content as the web service. The command's exit code and signals are preserved. FrankenPHP also prepares its runtime and WordPress configuration before explicit commands; `frankenphp run` retains normal web startup.

## Preserving cache during web startup

Every preset defaults to `SKIP_CACHE_FLUSH=true`: restarting an Apache or FrankenPHP container does not request a Redis flush or delete SQL transients. Official Redis drop-ins are installed or updated without activating the plugin's flushing commands. Identical files are not rewritten, and custom drop-ins are retained. The configuration directory and any outdated official drop-in must be writable when an update is needed.

Set `SKIP_CACHE_FLUSH=false` explicitly to request one `wp cache flush` during each web startup. A failed requested flush stops initialization. For a deployment with several replicas, keep the default and run this command once after deployment using the application image and the same database, network and volumes:

```sh
wp cache flush
```

Command startup does not add a second invalidation. This operation flushes the WordPress object cache; it does not delete SQL transients or purge WP Rocket page caches. Request those separately only when needed. Plugin-driven invalidation, including Object Cache Pro's integrity checks when cache serialization or configuration changes, remains under the plugin's control.

## Apache WordPress presets

`WP_PRESET` is applied before WordPress initialization. The PHP templates are rendered again after the preset is loaded so that the effective configuration matches the selected profile. Explicit environment variables take precedence.

| Preset | PHP memory limit | OPcache timestamp checks | OPcache memory / files | Skip cache flush |
| --- | --- | --- | --- | --- |
| `vitrine` (default) | `256M` | `1` | Base image defaults | `true` |
| `vitrine-heavy` | `256M` | Base image default | Base image defaults | `true` |
| `woocommerce` | `512M` | `1` | Base image defaults | `true` |
| `high-traffic` | `512M` | `0` | `512` / `60000` | `true` |

These presets do not size Apache or PHP-FPM automatically. Configure `APACHE_EVENT_*` and `PHP_FPM_PM_*` explicitly for the container's resources and workload. The old `APACHE_MPM_*` prefork variables are not used by the event-based Apache image. `PHP_MEMORY_LIMIT` limits a single PHP request, not the combined memory of all workers and caches.

Timestamp checks can be disabled for immutable application code replaced with the container. Keep them enabled when PHP files may change in a running container. Size the worker pool using observed worker memory and concurrency, with room for Apache and shared caches; increasing every site's worker limit can increase memory pressure without improving throughput.

## WP Rocket configuration

When WP Rocket is active, startup regenerates missing domain configuration files through the plugin's native API before starting the web server. The same check runs during WP-CLI startup, including the selected site in multisite. An existing complete set of readable configuration files is retained. When the license is valid, `WP_CACHE` is enabled and the plugin allows generation, startup also restores a missing page-cache directory or `advanced-cache.php` through WP Rocket’s native APIs without purging existing cache files. Any existing drop-in or symlink is retained, including a drop-in supplied by another cache plugin. On Apache, a missing WP Rocket `.htaccess` block is restored through the native API when the file or its parent is writable. Existing application rules, Rocket blocks, symlinks, read-only files and the `rocket_disable_htaccess` opt-out are retained. The FrankenPHP integration disables WP Rocket page-cache generation only when Souin is actually enabled by the preset. If a file is missing, WP Rocket regenerates the current site's configuration set. Failure to create an expected file or directory stops WP-CLI commands and prevents Apache or FrankenPHP from starting. No WP Rocket installation or license is included in these images.

The generated configuration directory must be writable by the container user when regeneration is needed. This does not replace persistent uploads or cache storage. In multisite, each site's configuration is checked when that site is loaded; startup does not enumerate the network.

On Bedrock sites using Roots WPConfig, WP Rocket cannot rewrite `WP_CACHE` in `wp-config.php`. Configure this constant through Bedrock instead. This prevents duplicate constant definitions while preserving the site's chosen cache setting; standard WordPress installations keep WP Rocket's normal behavior.

## Environment Variable

### WordPress

| Variable                     | Description                 | Default            |
| ---------------------------- | --------------------------- | ------------------ |
| `WORDPRESS_NO_CREATE_CONFIG` | Do not create a config file | `false`            |
| `WORDPRESS_DB_HOST`          | Database host               | `mysql`            |
| `WORDPRESS_DB_USER`          | Database user               | `example username` |
| `WORDPRESS_DB_PASSWORD`      | Database password           | `example password` |
| `WORDPRESS_DB_NAME`          | Database name               | `wordpress`        |
| `WORDPRESS_TABLE_PREFIX`     | Database table prefix       | `wp_`              |
| `WORDPRESS_DEBUG`            | Enable debug mode           | `false`            |
| `WORDPRESS_CONFIG_EXTRA`     | Additional configuration    | `empty`            |
| `WORDPRESS_DB_CHARSET`       | Database charset            | `utf8`             |
| `WORDPRESS_DB_COLLATE`       | Database collate            | `empty`            |
| `WORDPRESS_AUTH_KEY`         | Authentication key          | `empty`            |
| `WORDPRESS_SECURE_AUTH_KEY`  | Secure authentication key   | `empty`            |
| `WORDPRESS_LOGGED_IN_KEY`    | Logged in key               | `empty`            |
| `WORDPRESS_NONCE_KEY`        | Nonce key                   | `empty`            |
| `WORDPRESS_AUTH_SALT`        | Authentication              |
| `WORDPRESS_SECURE_AUTH_SALT` | Secure authentication salt  | `empty`            |
| `WORDPRESS_LOGGED_IN_SALT`   | Logged in salt              | `empty`            |
| `WORDPRESS_NONCE_SALT`       | Nonce salt                  | `empty`            |
| `WORDPRESS_DB_WAIT`          | Seconds to wait for WordPress at boot | `60`     |

Without WordPress core files (e.g. a static placeholder page), or when WordPress is not installed yet (e.g. files uploaded before the database import), the WordPress setup is skipped and Apache starts. When the database is unreachable, the init retries for `WORDPRESS_DB_WAIT` seconds, then starts anyway; the mu-plugin and Redis drop-in are set up on the next start. Configuration errors, including failure to create an expected WP Rocket configuration, prevent the web server from starting. Apache's S6 supervisors may remain running, so container process state alone is not an application readiness check.

For `WORDPRESS_NO_CREATE_CONFIG`: Do not create a new configuration file (default: false)

By default, the image will use a new [configuration file](templates/wp-config.php.tmpl) which is generated at runtime and after you can use WordPress environnement.

If you want to use your own configuration file, set this variable to `true`.

For `WORDPRESS_CONFIG_EXTRA`, you can use the following variables:

```apacheconf
WORDPRESS_CONFIG_EXTRA: |
    define( 'DISALLOW_FILE_MODS', true );
    define( 'WP_MEMORY_LIMIT', '511M' );
    define( 'WP_REDIS_HOST', 'mysite.redis');
```

### From inrage/docker-php image

Refer to the [inrage/docker-php](https://github.com/inrage/docker-php) documentation for more information.

### Running User

- `INRAGE_USER_ID`: UID of the user to run the application as (default: 1000)
- `INRAGE_GROUP_ID`: GID of the user to run the application as (default: 1000)

## Tools

- `wp`: WordPress CLI
- `sr`: allow you to replace in the database (`wp search-replace $1 $2 --precise --all-tables --skip-columns=guid`)

## Daily Usage

- [WordPress - Roots Sage 9](/docs/roots-sage9.md)
- [WordPress - Roots Sage 10](/docs/roots-sage10.md)
