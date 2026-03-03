<?php

namespace APP\plugins\generic\wpojsSubscriptionApi;

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class WpojsApiLogMigration extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('wpojs_api_log')) {
            return;
        }

        Schema::create('wpojs_api_log', function (Blueprint $table) {
            $table->bigIncrements('log_id');
            $table->string('endpoint', 255);
            $table->string('method', 10);
            $table->string('source_ip', 45);
            $table->smallInteger('http_status');
            $table->dateTime('created_at');
            $table->index('created_at', 'wpojs_api_log_created_at');
            $table->index(['source_ip', 'created_at'], 'wpojs_api_log_ratelimit');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wpojs_api_log');
    }
}
