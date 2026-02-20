<?php

/**
 * SEA Subscription API Plugin
 *
 * Exposes REST endpoints for managing OJS user accounts and subscriptions,
 * called by the SEA WordPress membership sync plugin (sea-ojs-sync).
 *
 * Deploy to: plugins/generic/seaSubscriptionApi/ in OJS installation.
 * Requires OJS 3.5+ for plugin API extensibility (pkp-lib #9434).
 *
 * Configuration in config.inc.php:
 *   [sea]
 *   allowed_ips = "1.2.3.4,5.6.7.8"
 */

namespace APP\plugins\generic\seaSubscriptionApi;

use PKP\core\APIRouter;
use PKP\plugins\GenericPlugin;
use PKP\plugins\Hook;

class SeaSubscriptionApiPlugin extends GenericPlugin
{
    public function register($category, $path, $mainContextId = null)
    {
        $success = parent::register($category, $path, $mainContextId);

        if (!$success || !$this->getEnabled()) {
            return $success;
        }

        Hook::add('APIHandler::endpoints::plugin', function (
            string $hookName,
            APIRouter $apiRouter
        ): bool {
            $apiRouter->registerPluginApiControllers([
                new SeaApiController(),
            ]);
            return Hook::CONTINUE;
        });

        return $success;
    }

    public function getDisplayName()
    {
        return __('plugins.generic.seaSubscriptionApi.displayName');
    }

    public function getDescription()
    {
        return __('plugins.generic.seaSubscriptionApi.description');
    }
}
