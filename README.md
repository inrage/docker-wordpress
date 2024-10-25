The provided Docker image allows you to deploy your WordPress website in production with a powerful configuration, an integrated SMTP relay, and support for PHP Redis.

Key features:

- All images are based on [inrage/docker-php](https://github.com/inrage/docker-php)
- [Docker Hub](https://hub.docker.com/r/inrage/docker-wordpress)
- Includes an SMTP server for outgoing emails
- Supports PHP Redis
- Advanced configuration for optimal performance
- Easy deployment and scalability with Docker

## Installation

To install, you need to either mount a directory into `/var/www/html` or customize the destination directory according to your needs. Here's how to proceed:

### Dockerfile

```Dockerfile
FROM inrage/docker-wordpress:8.3

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
      test: ["CMD-SHELL", "redis-cli --raw incr ping"]
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

## Daily Usage

- [WordPress - Roots Sage 9](/docs/roots-sage9.md)
- [WordPress - Roots Sage 10](/docs/roots-sage10.md)
