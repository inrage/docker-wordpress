<?php

$scenarios = ['web', 'web-false', 'plugin-absent', 'no-options', 'missing', 'partial', 'existing', 'generation-failed', 'advanced-missing', 'advanced-existing', 'advanced-empty', 'advanced-symlink', 'advanced-disabled', 'advanced-undefined', 'advanced-invalid', 'advanced-filtered', 'advanced-failed', 'advanced-empty-result', 'advanced-both', 'advanced-api-absent', 'advanced-cache-existing', 'advanced-cache-failed'];

if (!isset($argv[1])) {
    foreach ($scenarios as $scenario) {
        passthru(escapeshellarg(PHP_BINARY) . ' ' . escapeshellarg(__FILE__) . ' ' . escapeshellarg($scenario), $status);

        if (0 !== $status) {
            exit($status);
        }
    }

    exit;
}

$scenario = $argv[1];
if (!in_array($scenario, $scenarios, true)) {
    throw new RuntimeException('Unknown scenario');
}

$directory = sys_get_temp_dir() . '/rocket-config-test-' . bin2hex(random_bytes(6));
$files = [$directory . '/example.test.php', $directory . '/other.test.php'];
$callbacks = [];
$generations = 0;
$failed = false;
$advanced_generations = 0;
$advanced_cache = $directory . '/advanced-cache.php';
$advanced_scenario = 0 === strpos($scenario, 'advanced-');
define('WP_CONTENT_DIR', $directory);
define('WP_ROCKET_CACHE_PATH', $directory . '/cache/');
$cache_initializations = 0;
if ('advanced-undefined' !== $scenario) {
    define('WP_CACHE', $advanced_scenario && 'advanced-disabled' !== $scenario);
}

if ('web' !== $scenario) {
    define('WP_CLI', 'web-false' !== $scenario);
}

function add_action($hook, $callback)
{
    global $callbacks;

    if ('wp_loaded' !== $hook) {
        throw new RuntimeException('Unexpected hook');
    }

    $callbacks[] = $callback;
}

class ConfigurationError extends RuntimeException
{
}

class WP_CLI
{
    public static function get_config($key)
    {
        return 'https://example.test';
    }

    public static function error($message)
    {
        throw new ConfigurationError($message);
    }
}

function add_filter($name, $callback, $priority)
{
}

function apply_filters($name, $value)
{
    global $scenario;

    return 'advanced-filtered' === $scenario ? false : $value;
}

if ('plugin-absent' !== $scenario) {
    function get_rocket_config_file()
    {
        global $files, $scenario;

        return ['no-options' === $scenario ? [] : $files, 'generated'];
    }

    function rocket_generate_config_file()
    {
        global $directory, $files, $generations, $scenario;

        ++$generations;

        if ('generation-failed' === $scenario) {
            return;
        }

        if (!is_dir($directory)) {
            mkdir($directory);
        }

        foreach ($files as $file) {
            file_put_contents($file, 'generated');
        }
    }
}

if (!in_array($scenario, ['plugin-absent', 'advanced-api-absent'], true)) {
    function rocket_init_cache_dir()
    {
        global $scenario, $cache_initializations;

        ++$cache_initializations;
        if ('advanced-cache-failed' !== $scenario) {
            mkdir(WP_ROCKET_CACHE_PATH);
        }
    }

    function rocket_valid_key()
    {
        global $scenario;

        return 'advanced-invalid' !== $scenario;
    }

    function rocket_generate_advanced_cache_file()
    {
        global $advanced_cache, $advanced_generations, $scenario;

        ++$advanced_generations;

        if ('advanced-failed' !== $scenario) {
            file_put_contents($advanced_cache, 'advanced-empty-result' === $scenario ? '' : 'generated-drop-in');
        }
    }
}

try {
    if ($advanced_scenario) {
        mkdir($directory);
        if ('advanced-cache-existing' === $scenario) {
            mkdir(WP_ROCKET_CACHE_PATH);
            file_put_contents(WP_ROCKET_CACHE_PATH . 'sentinel.html', 'existing-cache');
        }
        if ('advanced-both' !== $scenario) {
            foreach ($files as $file) {
                file_put_contents($file, 'original');
            }
        }
        if (in_array($scenario, ['advanced-existing', 'advanced-empty', 'advanced-cache-existing'], true)) {
            file_put_contents($advanced_cache, 'advanced-empty' === $scenario ? '' : 'custom-drop-in');
        }
        if ('advanced-symlink' === $scenario) {
            symlink($directory . '/missing-target', $advanced_cache);
        }
    }
    if ('partial' === $scenario) {
        mkdir($directory);
        file_put_contents($files[0], 'original');
    }

    if ('existing' === $scenario) {
        mkdir($directory);

        foreach ($files as $file) {
            file_put_contents($file, 'original');
        }
    }

    require $argv[2] ?? dirname(__DIR__) . '/templates/production.php.tmpl';

    if (count($callbacks) !== (int) !in_array($scenario, ['web', 'web-false'], true)) {
        throw new RuntimeException('Unexpected hook registration');
    }

    try {
        foreach ($callbacks as $callback) {
            $callback();
        }
    } catch (ConfigurationError $error) {
        $failed = true;

        if (!in_array($error->getMessage(), ['Could not generate WP Rocket configuration.', 'Could not generate WP Rocket advanced cache.', 'Could not generate WP Rocket cache directory.'], true)) {
            throw $error;
        }
    }

    if ($failed !== in_array($scenario, ['generation-failed', 'advanced-failed', 'advanced-empty-result', 'advanced-cache-failed'], true) || $generations !== (int) in_array($scenario, ['missing', 'partial', 'generation-failed', 'advanced-both'], true)) {
        throw new RuntimeException('Unexpected generation result');
    }

    if (in_array($scenario, ['missing', 'partial', 'existing'], true)) {
        foreach ($files as $file) {
            if (file_get_contents($file) !== ('existing' === $scenario ? 'original' : 'generated')) {
                throw new RuntimeException('Unexpected configuration content');
            }
        }
    }

    if ($cache_initializations !== (int) in_array($scenario, ['advanced-missing', 'advanced-existing', 'advanced-empty', 'advanced-symlink', 'advanced-failed', 'advanced-empty-result', 'advanced-both', 'advanced-cache-failed'], true)) {
        throw new RuntimeException('Unexpected cache directory initialization count');
    }

    if ('advanced-cache-existing' === $scenario && file_get_contents(WP_ROCKET_CACHE_PATH . 'sentinel.html') !== 'existing-cache') {
        throw new RuntimeException('Existing page cache was changed');
    }

    if ($advanced_generations !== (int) in_array($scenario, ['advanced-missing', 'advanced-both', 'advanced-failed', 'advanced-empty-result'], true)) {
        throw new RuntimeException('Unexpected advanced cache generation count');
    }

    if (in_array($scenario, ['advanced-missing', 'advanced-both', 'advanced-existing', 'advanced-empty'], true)) {
        $expected = 'advanced-existing' === $scenario ? 'custom-drop-in' : ('advanced-empty' === $scenario ? '' : 'generated-drop-in');
        if (file_get_contents($advanced_cache) !== $expected) {
            throw new RuntimeException('Unexpected advanced cache content');
        }
    } elseif ('advanced-symlink' === $scenario) {
        if (!is_link($advanced_cache)) {
            throw new RuntimeException('Existing advanced cache symlink was replaced');
        }
    }

    echo 'PASS WP Rocket config: ' . $scenario . PHP_EOL;
} finally {
    if (is_file(WP_ROCKET_CACHE_PATH . 'sentinel.html')) {
        unlink(WP_ROCKET_CACHE_PATH . 'sentinel.html');
    }
    if (is_dir(WP_ROCKET_CACHE_PATH)) {
        rmdir(WP_ROCKET_CACHE_PATH);
    }
    if (file_exists($advanced_cache) || is_link($advanced_cache)) {
        unlink($advanced_cache);
    }
    foreach ($files as $file) {
        if (is_file($file)) {
            unlink($file);
        }
    }

    if (is_dir($directory)) {
        rmdir($directory);
    }
}
