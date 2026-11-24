<?php

$cases = [
    'web' => ['cli' => null],
    'web-false' => ['cli' => false],
    'https' => ['read_home' => true, 'expected' => ['https://example.test']],
    'http' => ['home' => 'http://example.test', 'read_home' => true, 'expected' => ['http://example.test']],
    'subdirectory' => ['home' => 'https://example.test/site/', 'read_home' => true, 'expected' => ['https://example.test/site/']],
    'explicit-http' => ['url' => 'http://selected.test'],
    'explicit-https' => ['url' => 'https://selected.test'],
    'explicit-blog' => ['blog' => 'https://selected.test/site/'],
    'missing-home' => ['home' => false, 'read_home' => true],
    'empty-home' => ['home' => '', 'read_home' => true],
];

$scenario = $argv[1] ?? '';
if (!isset($cases[$scenario])) {
    throw new RuntimeException('Unknown scenario: ' . $scenario);
}

$case = $cases[$scenario] + [
    'cli' => true,
    'url' => null,
    'blog' => null,
    'home' => 'https://example.test',
    'read_home' => false,
    'expected' => [],
];
$home_reads = 0;

if (null !== $case['cli']) {
    define('WP_CLI', $case['cli']);
}

class WP_CLI
{
    public static $urls = [];

    public static function get_config($key)
    {
        global $case;

        if (true !== $case['cli'] || !in_array($key, ['url', 'blog'], true)) {
            throw new RuntimeException('Unexpected WP-CLI configuration access');
        }

        return $case[$key];
    }

    public static function set_url($url)
    {
        self::$urls[] = $url;
    }
}

function get_option($key)
{
    global $case, $home_reads;

    if ('home' !== $key || !$case['read_home']) {
        throw new RuntimeException('Unexpected WordPress option access');
    }

    ++$home_reads;

    return $case['home'];
}

function add_action($name, $callback)
{
}

function add_filter($name, $callback, $priority)
{
}

require $argv[2] ?? dirname(__DIR__) . '/templates/production.php.tmpl';

if (WP_CLI::$urls !== $case['expected'] || $home_reads !== (int) $case['read_home']) {
    throw new RuntimeException('Unexpected URL context for ' . $scenario);
}

echo 'PASS WP-CLI URL context: ' . $scenario . PHP_EOL;
