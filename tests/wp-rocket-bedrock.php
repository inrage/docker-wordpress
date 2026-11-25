<?php

$scenario = $argv[1] ?? '';
if (!in_array($scenario, ['bedrock-web-false', 'bedrock-web-true', 'bedrock-cli-false', 'bedrock-cli-true', 'classic-web-false', 'classic-web-true', 'classic-cli-false', 'classic-cli-true'], true)) {
    throw new RuntimeException('Unknown scenario');
}

$bedrock = 0 === strpos($scenario, 'bedrock-');
$cache = substr($scenario, -4) === 'true';
$filters = [];
define('WP_CACHE', $cache);
define('WP_CLI', strpos($scenario, '-cli-') !== false);

if ($bedrock) {
    class BedrockConfig
    {
    }

    class_alias('BedrockConfig', 'Roots\WPConfig\Config');
}

spl_autoload_register(function ($class) {
    throw new RuntimeException('Unexpected autoload: ' . $class);
});

class WP_CLI
{
    public static function get_config($key)
    {
        return 'https://example.test';
    }
}

function add_action($name, $callback)
{
}

function add_filter($name, $callback, $priority)
{
    global $filters;

    $filters[$name][$priority][] = $callback;
}

function __return_false()
{
    return false;
}

require $argv[2] ?? dirname(__DIR__) . '/templates/production.php.tmpl';

$allowed = true;
foreach ($filters['rocket_set_wp_cache_constant'] ?? [] as $callbacks) {
    foreach ($callbacks as $callback) {
        $allowed = $callback($allowed);
    }
}

if ($allowed !== !$bedrock || WP_CACHE !== $cache) {
    throw new RuntimeException('WP_CACHE ownership changed unexpectedly');
}

echo 'PASS WP Rocket Bedrock: ' . $scenario . PHP_EOL;
