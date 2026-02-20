<?php
/**
 * Bedrock wp-config.php — delegates to config/application.php.
 *
 * This file exists because WordPress looks for wp-config.php.
 * All configuration is in config/application.php which reads from .env.
 */

require_once dirname(__DIR__) . '/vendor/autoload.php';
require_once dirname(__DIR__) . '/config/application.php';
require_once ABSPATH . 'wp-settings.php';
