<?php

$target = WP_CONTENT_DIR . '/object-cache.php';

if (is_file($target)) {
    if (!is_readable($target)) {
        WP_CLI::error('Could not read the object cache drop-in.');
    }

    $headers = get_file_data($target, ['PluginURI' => 'Plugin URI']);

    if (!in_array(rtrim($headers['PluginURI'], '/'), ['https://objectcache.pro', 'https://wordpress.org/plugins/redis-cache'], true)) {
        return;
    }
}

if (defined('RedisCachePro\\Filename')) {
    $source = dirname(constant('RedisCachePro\\Filename')) . '/stubs/object-cache.php';
} elseif (defined('WP_REDIS_PLUGIN_PATH')) {
    $source = WP_REDIS_PLUGIN_PATH . '/includes/object-cache.php';
} elseif (is_file($target)) {
    return;
} else {
    WP_CLI::error('Cannot initialize this Redis plugin without flushing its cache.');
}

if (!is_readable($source)) {
    WP_CLI::error('Could not read the Redis object cache drop-in source.');
}

if (is_file($target) && hash_file('sha256', $target) === hash_file('sha256', $source)) {
    return;
}

if (!copy($source, $target)) {
    WP_CLI::error('Could not install the Redis object cache drop-in.');
}

if (function_exists('wp_opcache_invalidate')) {
    wp_opcache_invalidate($target, true);
}
