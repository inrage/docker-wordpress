<?php
/**
 * Plugin Name: inRage WP Rocket + Souin
 */

add_filter('do_rocket_generate_caching_files', '__return_false', PHP_INT_MAX);

if (!function_exists('inr_souin_purge_all')) {
    function inr_souin_purge_all(): void
    {
        if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
            return;
        }

        $endpoint = getenv('INR_SOUIN_PURGE_URL');
        if (!$endpoint) {
            $home = defined('WP_HOME') ? WP_HOME : home_url();
            $endpoint = rtrim($home, '/') . '/souin-api/souin/flush';
        }

        $args = [
            'method' => 'PURGE',
            'timeout' => 2,
            'blocking' => false,
            'sslverify' => false,
        ];

        $key = getenv('INR_SOUIN_API_KEY');
        if ($key) {
            $args['headers'] = ['Authorization' => 'Bearer ' . $key];
        }

        wp_remote_request($endpoint, $args);
    }
}

foreach (['save_post', 'deleted_post', 'trashed_post', 'comment_post', 'edit_comment', 'switch_theme', 'after_rocket_clean_domain', 'woocommerce_product_set_stock'] as $inr_hook) {
    add_action($inr_hook, 'inr_souin_purge_all', 20);
}
