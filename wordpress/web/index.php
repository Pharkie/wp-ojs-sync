<?php
/**
 * Bedrock loader.
 *
 * WordPress is installed to web/wp/ — this file bootstraps it.
 */

define('WP_USE_THEMES', true);
require __DIR__ . '/wp/wp-blog-header.php';
