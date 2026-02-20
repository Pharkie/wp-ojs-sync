<?php
/**
 * Staging environment config.
 */

use Roots\WPConfig\Config;
use function Env\env;

Config::define('WP_DEBUG', false);
Config::define('WP_DEBUG_DISPLAY', false);
Config::define('WP_DEBUG_LOG', env('WP_DEBUG_LOG') ?: '/var/www/html/web/app/uploads/debug.log');
Config::define('DISALLOW_INDEXING', true);
