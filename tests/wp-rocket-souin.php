<?php

$scenario = $argv[1];
$filters = [];
$actions = [];

if ('unset' === $scenario) {
    putenv('INR_CACHE_DIRECTIVE');
} else {
    putenv('INR_CACHE_DIRECTIVE=' . ('on' === $scenario ? 'cache' : ''));
}

function add_filter($name, $callback, $priority)
{
    global $filters;

    $filters[] = [$name, $callback, $priority];
}

function add_action($name, $callback, $priority)
{
    global $actions;

    $actions[] = [$name, $callback, $priority];
}

require $argv[2];

if ('on' === $scenario) {
    if ($filters !== [['do_rocket_generate_caching_files', '__return_false', PHP_INT_MAX]] || count($actions) !== 8) {
        throw new RuntimeException('Active Souin integration was not configured');
    }
} elseif ($filters || $actions) {
    throw new RuntimeException('Inactive Souin changed WP Rocket behavior');
}

echo 'PASS WP Rocket Souin: ' . $scenario . PHP_EOL;
