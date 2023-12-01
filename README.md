The provided Docker image allows you to deploy WordPress in production with a powerful configuration, an integrated SMTP relay, and support for PHP Redis.

Key features:

- Based on the official WordPress image
- Includes an SMTP server for outgoing emails
- Supports PHP Redis
- Advanced configuration for optimal performance
- Easy deployment and scalability with Docker

## Installation

To install, you need to either mount a directory into `/var/www/html` or customize the destination directory according to your needs. Here's how to proceed:

### Dockerfile

```Dockerfile
FROM inrage/docker-wordpress:8.2

COPY --chown=inr . .
RUN cp -a /usr/src/wordpress/wp-config-docker.php wp-config.php
```

### Docker Swarm Configuration

We are using a Docker Swarm configuration with Traefik as a reverse proxy. Here's an example of a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  redis:
    hostname: mywebsite.redis
    image: redis:7.2.0
    healthcheck:
      test: [ "CMD-SHELL", "redis-cli --raw incr ping" ]
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
      - /host/website/mywebsite/object-cache.php:/var/www/html/wp-content/object-cache.php
      
    deploy:
      replicas: 1
      labels:
        - traefik.enable=true
        - traefik.docker.network=traefik-public
        - traefik.constraint-label=traefik-public
        - traefik.http.routers.${ALIAS}-http.rule=Host(`www.inrage.fr`, `inrage.fr`)
        - traefik.http.routers.${ALIAS}-http.entrypoints=http
        - traefik.http.routers.${ALIAS}-http.middlewares=https-redirect
        - traefik.http.routers.${ALIAS}-https.rule=Host(`www.inrage.fr`, `inrage.fr`)
        - traefik.http.routers.${ALIAS}-https.entrypoints=https
        - traefik.http.routers.${ALIAS}-https.tls=true
        - traefik.http.routers.${ALIAS}-https.tls.certresolver=le
        - traefik.http.services.${ALIAS}.loadbalancer.server.port=80

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

- `WORDPRESS_DB_HOST`: Database host (default: mysql)
- `WORDPRESS_DB_USER`: Database user (default: example username)
- `WORDPRESS_DB_PASSWORD`: Database password (default: example password)
- `WORDPRESS_DB_NAME`: Database name (default: wordpress)
- `WORDPRESS_TABLE_PREFIX`: Database table prefix (default: wp_)
- `WORDPRESS_DEBUG`: Enable debug mode (default: false)
- `WORDPRESS_CONFIG_EXTRA`: Additional configuration (default: empty)

For `WORDPRESS_CONFIG_EXTRA`, you can use the following variables:

```apacheconf
WORDPRESS_CONFIG_EXTRA: |
    define( 'DISALLOW_FILE_MODS', true );	
    define( 'WP_MEMORY_LIMIT', '511M' );
    define( 'WP_REDIS_HOST', 'mysite.redis');
```

### SMTP
- `INR_SMTP_HOST`: Relay SMTP server host (default: relay.mailhub)
- `INR_SMTP_PORT`: Relay SMTP server port (default: 25)

### Running User
- `INRAGE_USER_ID`: UID of the user to run the application as (default: 1000)
- `INRAGE_GROUP_ID`: GID of the user to run the application as (default: 1000)
