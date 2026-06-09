<?php
/**
 * Plugin Name: inRage Real Client IP
 */

if (PHP_SAPI === 'cli') {
    return;
}

$inr_trusted = getenv('INR_TRUSTED_PROXIES') ?: '10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.0/8,169.254.0.0/16';

$inr_ip_in_cidr = static function (string $ip, string $cidr): bool {
    $cidr = trim($cidr);
    if ($cidr === '') {
        return false;
    }
    if (strpos($cidr, '/') === false) {
        return $ip === $cidr;
    }
    [$subnet, $bits] = explode('/', $cidr, 2);
    if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) || !filter_var($subnet, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        return false;
    }
    $bits = (int) $bits;
    $mask = $bits === 0 ? 0 : (~0 << (32 - $bits)) & 0xFFFFFFFF;
    return (ip2long($ip) & $mask) === (ip2long($subnet) & $mask);
};

$inr_peer = $_SERVER['REMOTE_ADDR'] ?? '';
$inr_peer_trusted = false;
foreach (explode(',', $inr_trusted) as $inr_cidr) {
    if ($inr_ip_in_cidr($inr_peer, $inr_cidr)) {
        $inr_peer_trusted = true;
        break;
    }
}

if ($inr_peer_trusted && !empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
    $inr_forwarded = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
    $inr_client = trim($inr_forwarded[0]);
    if (filter_var($inr_client, FILTER_VALIDATE_IP)) {
        $_SERVER['REMOTE_ADDR'] = $inr_client;
    }
}

if (!empty($_SERVER['HTTP_X_FORWARDED_PROTO']) && strtolower($_SERVER['HTTP_X_FORWARDED_PROTO']) === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
