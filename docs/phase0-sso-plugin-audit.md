# Phase 0: Subscription SSO Plugin Source Code Audit

Conducted 2026-02-16. Source: [github.com/asmecher/subscriptionSSO](https://github.com/asmecher/subscriptionSSO)

## Summary

**The Subscription SSO plugin hijacks the OJS purchase flow and is incompatible with per-item sales.** It was eliminated as an option.

## Plugin structure

The entire plugin is two PHP classes and a template:
- `SubscriptionSSOPlugin.php` — 172 lines, the core logic
- `SubscriptionSSOSettingsForm.php` — 93 lines, settings form
- `templates/settingsForm.tpl` — settings UI

## Five configuration settings

1. **`incomingParameterName`** — URL query parameter name (e.g. `ssoToken`)
2. **`verificationUrl`** — server-to-server URL called via cURL to validate the token
3. **`resultRegexp`** — PCRE regex tested against the cURL response body
4. **`redirectUrl`** — where the user's browser is sent when they lack access
5. **`hoursValid`** — how long the session stays valid before re-verification

## Hooks registered

Two hooks:

```php
Hook::add('LoadHandler', [&$this, 'loadHandlerCallback']);
Hook::add('IssueAction::subscribedUser', [&$this, 'subscribedUserCallback']);
```

- `LoadHandler` — fires on every page request. Checks for the incoming SSO parameter and runs verification.
- `IssueAction::subscribedUser` — fires when OJS checks subscription status. Either confirms access or redirects.

## Detailed flow

### When user arrives with SSO token in URL (LoadHandler)

1. Checks `$_GET` for the configured parameter name
2. If present, makes a server-side cURL call: `verificationUrl + urlencode(tokenValue)`
3. Tests response body against `resultRegexp`
4. If regex matches → stores `$_SESSION['subscriptionSSOTimestamp'] = time()`
5. If regex fails → **unsets** any existing session timestamp, redirects to `redirectUrl`

Note: a failed verification **destroys any existing valid session**.

### When user hits paywalled content (subscribedUser)

1. **Excluded pages** (always allowed): index, issue listing, search, abstract-only views
2. **Open access articles**: allowed regardless
3. **Existing OJS subscription**: if OJS's own check already returned true (`$args[4]`), plugin does nothing — access granted
4. **SSO session check**: if `$_SESSION['subscriptionSSOTimestamp']` exists and hasn't expired → access granted
5. **Otherwise**: `$request->redirectUrl(redirectUrl + '?redirectUrl=' + currentUrl)`

### The critical problem (step 5)

If OJS says "not subscribed" AND there's no valid SSO session, the plugin **immediately redirects** to the external system. There is no code path where OJS gets to show its own purchase/paywall page.

```php
if (!$result) {
    $request->redirectUrl($this->getSetting($journal->getId(), 'redirectUrl') .
        '?redirectUrl=' . urlencode($request->getRequestUrl()));
}
```

This means a non-member who wants to buy a £3 article gets bounced to WordPress instead of seeing OJS's purchase options.

## Key technical details

- **No OJS user account required.** The plugin operates on PHP sessions only. Anonymous visitors can get access.
- **No email matching.** Identity is established by the external token, not by any user attribute.
- **Session is PHP `$_SESSION`** — not stored in OJS database. Tied to PHP session cookie.
- **cURL call is synchronous** — OJS page load blocks until the verification URL responds.
- **No retry logic.** If cURL fails, the user gets redirected.
- **Cache is per-session only.** No shared cache. Every new browser session requires fresh verification.

## Why this kills non-member purchases

The plugin assumes the external system (WordPress) is the ONLY subscription authority. Its logic is:

1. Does OJS already say they're subscribed? → Let them through.
2. Do they have a valid SSO session? → Let them through.
3. Otherwise → Redirect to the external system. Always. No exceptions.

There is no "fall through to OJS purchase page" path. The plugin replaces OJS's paywall-with-purchase-options with a redirect-to-external-system.

For SEA, this means non-members can never see OJS's "buy this article for £3" page while the plugin is active.
