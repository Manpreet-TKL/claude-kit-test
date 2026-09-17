# Login overlay: behavior, performance cost and proposed changes

The OpenEyes login overlay covers an open patient screen after session expiry and lets the same user reauthenticate while retaining the page and its unsaved work where the workflow permits. It displays the existing user/location context and supports the application's authentication flow. It is a privacy and workflow feature, not simply a login-page shortcut.

The behavior below is source-checked against OpenEyes **v10.0.30**. The request counts come from the generic [usage profile](oe-v10-typical-usage-and-load-profile.md). They describe one sticky-session backend's workload, not unique users or a measured CPU profile.

## What runs today

| Source or route | Behavior and cost |
|---|---|
| `protected/assets/js/script.js` | On document ready, except for `/site/login`, creates/appends the overlay, initially hides it, and calls `queueLoginOverlay()`. |
| `protected/assets/js/script-utils.js::createLoginOverlay()` | Fetches `/Site/getOverlayPrepopulationData` with synchronous AJAX before constructing the overlay. This blocks browser JavaScript while the request completes. |
| `SiteController::actionGetOverlayPrepopulationData()` | Reads the session's user context and loads selected institution/site models to populate names and IDs. |
| `script-utils.js::queueLoginOverlay()` | Calls `/User/getSessionExpireTimestamp` with `extend_session=false`, then schedules the overlay for five seconds after the reported expiry. It is also called around reauthentication. |
| `UserController::actionGetSessionExpireTimestamp()` | Explicitly queries `user_session.expire` for the current session, falling back to the current server time if no row exists. |
| `protected/components/OESession.php` | Uses Yii database sessions. Non-extending writes still check session existence and write session data; ordinary writes extend expiry. |
| `script-utils.js` authentication helpers | The overlay also checks authentication and submits reauthentication requests. Those calls are separate from the two initialization endpoints measured below. |

This is custom OpenEyes JavaScript/controller behavior built on Yii services. The two initialization calls are not unavoidable framework traffic, and the near-equal counts are consistent with page setup rather than two continuously running interval polls.

`extend_session=false` is not a no-SQL flag. `OESession::writeSessionWithoutExtending()` can update existing session data, and its missing-row path can insert a session record. The overlay-defaults request does not supply the non-extension flag. Any optimization must preserve the intended authentication policy rather than assuming these background requests are behaviorally neutral.

## Observed request cost

| Category | Requests | Share of application requests |
|---|---|---|
| `/User/getSessionExpireTimestamp` | 89,781 | 9.93% |
| `/Site/getOverlayPrepopulationData` | 89,583 | 9.91% |
| Combined | 179,364 | 19.84% |
| All application requests | 903,932 | 100% |

Each extra HTTP request has routing/bootstrap/authentication/session work and uses a web worker for its lifetime, in addition to the endpoint-specific SQL. The synchronous defaults request also adds a blocking round trip to page initialization. Its latency is not present in the access logs, so the number of milliseconds saved is unknown.

The 179,364 calls are about 6.12% of all 2,932,635 HTTP requests after including assets, health checks and Apache internal traffic. They are not 19.84% of database queries, CPU time or total HTTP traffic. Request counts also include automation, and do not establish how many times a staff member saw the overlay.

## Proposed changes

### 1. Include minimal overlay defaults in the existing page response

Build the required username and institution/site display context from data already available when rendering an authenticated page. Serialize it safely into a small bootstrap object and let `createLoginOverlay()` consume it. Reuse loaded context rather than adding the same model lookups again elsewhere.

This can remove `/Site/getOverlayPrepopulationData` from normal page initialization and eliminate its synchronous network wait. It adds a small amount of page data rather than another application request. Store only what the overlay needs; do not serialize the session, authentication model, password or tokens into it.

Retain that minimal context for use after expiry. A design that waits until the session has expired before requesting protected user/site information may be unable to retrieve it. Refresh the snapshot when user or location context changes.

### 2. Provide an authoritative expiry deadline through existing responses

Expose the session deadline and server time through the normal page/response path, and use them to schedule one local expiry timer. The session layer should supply a deadline consistent with the session write that actually occurs; simply embedding the old `expire` value before a later write extends it can make the UI lock prematurely.

Define how successful activity updates the deadline and how non-extending background requests leave it unchanged. Coordinate response generation and session persistence without introducing an extra session write or an early close that discards later session changes. If that cannot be made reliable in the first change, retain the expiry endpoint as a fallback until it can.

Use server time to account for clock skew. Clear the previous timer before scheduling a replacement, including after reauthentication. On tab resume or a suspended device, reassess the deadline rather than assuming a delayed timer fired at the right moment. Keep server-side expiry and authorization as the authority; local keystrokes or tab messages must not manufacture a longer authenticated session.

### 3. Build the UI when needed and make its remaining requests asynchronous

Keep only the minimal bootstrap context until an overlay is needed, then create its DOM once. This avoids repeatedly building an unused overlay on short page visits. Make authentication checks and reauthentication asynchronous with explicit pending/success/failure states, rather than freezing JavaScript while waiting.

Keep patient content covered while authentication is unresolved or fails. In the inspected implementation, the login request's error callback hides the overlay before displaying an alert; the refactor should have a regression case for network failure and retain the covering state until successful authentication or navigation to a safe screen.

Lazy DOM creation alone does not remove SQL or HTTP traffic if the same two data requests still run on every page. The bootstrap/expiry changes are what remove that repeated backend work.

### 4. Avoid unnecessary initialization in trusted rendering layouts

Document-rendering layouts that do not need an interactive login overlay should explicitly omit its initializer while retaining normal server authentication and authorization. Do not infer permission from a Headless Chrome user-agent string. First measure how many of the two endpoints come from the affected layouts; the overall headless-traffic percentage is not a saving estimate for this feature.

Cross-tab coordination is a separate refinement: share deadline/logout notifications, not credentials, so another tab's reauthentication or logout can be reflected correctly. Do not silently retain unsaved patient edits if the authenticated user or permitted location changes.

## Expected gains and their limits

The figures below are arithmetic ceilings against the reference workload, assuming the removed endpoint has no replacement HTTP call. They are not benchmark results.

| Change | Maximum request reduction in the reference workload | Expected benefit |
|---|---|---|
| Bootstrap overlay defaults | 89,583, or 9.91% of application requests | Removes a synchronous round trip and that request's bootstrap/session work; can reuse existing model data. |
| Supply expiry reliably through existing responses | 89,781, or 9.93% | Removes the expiry request and its separate session-expiry lookup path, subject to what the session layer must still read/write. |
| Remove both initialization endpoints | 179,364, or 19.84%; application requests would fall from 903,932 to 724,568 under this assumption | Fewer worker acquisitions, fewer session/bootstrap passes and less endpoint-specific SQL. CPU and latency savings still need measurement. |
| Merge the two reads as an interim alternative | Roughly one request per paired initialization, around half the pair's HTTP calls | Lower round-trip and bootstrap overhead, but most endpoint-specific SQL can remain. This overlaps with, and is not additional to, the two rows above. |
| Lazy UI construction / asynchronous authentication | No fixed request saving by itself | Less blocking and less unused DOM work; requires browser timing to quantify. |

Do not claim that removing 19.84% of requests makes pages 19.84% faster. These endpoints may be relatively cheap, and some work is moved into an existing response. Measure incremental SQL, session writes and response size as well as the request-count reduction. Increasing session lifetime or disabling expiry changes the security/workflow policy and is not the proposed optimization.

## Verification and measurement

1. Record the current browser request waterfall, blocking time, two endpoint counts, PHP/SQL time and session writes for representative page navigation and editing. Keep the debug/profiling configuration consistent between runs.
2. Confirm normal pages no longer make the removed request and do not replace it with an equivalent hidden request or duplicate model query. Test both freshly loaded and cached assets.
3. Verify expiry while idle and during editing, active versus non-extending requests, clock skew, sleeping/resumed devices, multiple tabs, logout elsewhere, reauthentication failure and network loss. The patient screen must remain covered when authentication is unresolved.
4. Exercise the supported password, external-authentication and location-change flows. Preserve CSRF handling and the existing rules about reusing unsaved work for the same user/context.
5. Check document-rendering routes separately. Compare worker occupancy, database/session work, page responsiveness and errors under the same workload; report measured savings with their denominator.

The full local-hour and weekday/weekend tables remain in [Typical busy and quiet hours](oe-v10-typical-usage-and-load-profile.md#typical-busy-and-quiet-hours). They identify likely busy test periods and quieter candidates, not a guaranteed maintenance window.

Source baseline: OpenEyes `v10.0.30`, commit `77438f14e9f4124df8c66effb4bc2b6a28e44435`; the source files and methods listed above. This note proposes application changes; it does not record their implementation or measured performance gains.
