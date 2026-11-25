<?php

$scenario = $argv[1];
$directory = sys_get_temp_dir() . '/rocket-htaccess-' . bin2hex(random_bytes(6));
mkdir($directory);
$htaccess = $directory . '/.htaccess';
$original = "# BEGIN SolidSecurity\nOptions -Indexes\n# END SolidSecurity\n# BEGIN WordPress\nRewriteEngine On\n# END WordPress\n";
$callbacks = [];
$generations = 0;
$is_apache = false;
define('ABSPATH', $directory . '/wp/');
$original_script_filename = $_SERVER['SCRIPT_FILENAME'];
define('WP_CLI', true);
define('WP_CACHE', true);
define('WP_CONTENT_DIR', $directory);
file_put_contents($directory . '/advanced-cache.php', 'existing-drop-in');

class WP_CLI
{
    public static function get_config($key) { return 'https://example.test'; }
    public static function error($message) { throw new RuntimeException($message); }
}
function add_action($name, $callback) { $GLOBALS['callbacks'][] = $callback; }
function add_filter($name, $callback, $priority) {}
function apply_filters($name, $value) { return 'rocket_disable_htaccess' === $name && 'opt-out' === $GLOBALS['scenario'] ? true : $value; }
function get_rocket_config_file() { return [[], '']; }
function rocket_generate_config_file() {}
function rocket_valid_key() { return true; }
function get_home_path() { if ($_SERVER['SCRIPT_FILENAME'] !== ABSPATH) { throw new RuntimeException('CLI home path context missing'); } return $GLOBALS['directory'] . '/'; }
function flush_rocket_htaccess()
{
    global $scenario, $generations, $htaccess, $is_apache;
    if (!$is_apache) { throw new RuntimeException('Apache context was not set'); }
    ++$generations;
    if ('failed' === $scenario) { return false; }
    $contents = is_file($htaccess) ? file_get_contents($htaccess) : '';
    file_put_contents($htaccess, "# BEGIN WP Rocket\nNative rules\n# END WP Rocket\n" . $contents);
    return 'legacy-return' === $scenario ? null : true;
}

try {
    if (!in_array($scenario, ['missing', 'parent-readonly', 'symlink'], true)) {
        file_put_contents($htaccess, 'existing' === $scenario ? "# BEGIN WP Rocket\nExisting rules\n# END WP Rocket\n" . $original : $original);
    }
    if ('readonly' === $scenario) { chmod($htaccess, 0444); }
    if ('parent-readonly' === $scenario) { chmod($directory, 0555); }
    if ('symlink' === $scenario) { symlink($directory . '/missing-target', $htaccess); }
    require $argv[2];
    $failed = false;
    try {
        foreach ($callbacks as $callback) { $callback(); }
    } catch (RuntimeException $error) {
        if ($error->getMessage() !== 'Could not generate WP Rocket Apache rules.') { throw $error; }
        $failed = true;
    }
    if ($failed !== ('failed' === $scenario) || $is_apache !== false || $_SERVER['SCRIPT_FILENAME'] !== $original_script_filename) { throw new RuntimeException('Unexpected result or Apache global changed'); }
    if ($generations !== (int) in_array($scenario, ['missing', 'custom', 'failed', 'legacy-return'], true)) { throw new RuntimeException('Unexpected generation count'); }
    if (in_array($scenario, ['missing', 'custom'], true) && strpos(file_get_contents($htaccess), '# BEGIN WP Rocket') === false) { throw new RuntimeException('Rocket rules missing'); }
    if (in_array($scenario, ['custom', 'existing', 'readonly', 'opt-out', 'not-apache'], true) && strpos(file_get_contents($htaccess), $original) === false) { throw new RuntimeException('Application rules changed'); }
    if ('symlink' === $scenario && !is_link($htaccess)) { throw new RuntimeException('Symlink changed'); }
    if ('parent-readonly' === $scenario && file_exists($htaccess)) { throw new RuntimeException('Readonly site changed'); }
    echo 'PASS WP Rocket Apache rules: ' . $scenario . PHP_EOL;
} finally {
    chmod($directory, 0755);
    if (file_exists($htaccess) || is_link($htaccess)) { unlink($htaccess); }
    unlink($directory . '/advanced-cache.php');
    rmdir($directory);
}
