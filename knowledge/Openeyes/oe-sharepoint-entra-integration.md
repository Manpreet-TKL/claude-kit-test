# OpenEyes integration with SharePoint, Microsoft 365, and Microsoft Entra ID

Read when a client wants to launch OpenEyes from SharePoint or another Microsoft 365 surface, use Entra ID for OpenEyes sign-in, or show a limited amount of OpenEyes data in a Microsoft 365 application. This note separates navigation, identity, private network access, UI embedding, and API integration because they require different controls.

## Recommended position

Use SharePoint, Teams, Outlook, or My Apps to launch OpenEyes as a top-level HTTPS page. Use Entra OIDC for user authentication and keep OpenEyes responsible for clinical authorization and auditing. Keep the OpenEyes session cookie `Secure; HttpOnly; SameSite=Strict`.

For patient-context links, add a short-lived, one-time handoff with an explicit same-origin continuation or a supported Entra sign-in round trip. Do not put patient identifiers in a URL or change the session cookie to `Lax` or `None`. For a small SharePoint data panel, use a SharePoint Framework web part and an Entra-secured Azure API broker. Do not embed the full OpenEyes UI in an iframe.

This is not a case for a Microsoft 365 exception to the cookie policy. `SameSite=Lax` would send `OESESSID` on top-level GET navigation from every external site, not only approved SharePoint pages, and OpenEyes cannot apply a trusted-referrer exception before the browser sends the cookie. It would still not support an iframe or a cross-site browser API. `SameSite=None` would expose the session to a much wider set of third-party contexts and require a new clickjacking, CSRF, CORS, and third-party-cookie design. A narrow launch handoff solves the requested path without expanding the session boundary for every route and user.

## The integration choices

| Method | Suitable outcome | Network model | Authentication | Cookie impact | Recommendation |
|---|---|---|---|---|---|
| SharePoint Link web part | Open OpenEyes or a safe launch endpoint in a full browser page | User device must resolve and reach OpenEyes | OpenEyes login or Entra OIDC | First external request does not carry Strict `OESESSID` | Recommended for simple access |
| Entra My Apps enterprise-app tile | Give assigned users a central OpenEyes launch icon | User device must reach OpenEyes | Entra assignment plus OpenEyes OIDC | Same as any external top-level link | Recommended alongside SharePoint links |
| OpenEyes OIDC with Entra ID | Replace a separate OpenEyes password and map identity or roles | Does not create network reachability | Entra authorization code flow | Uses separate short-lived SSO state; main session stays Strict | Recommended identity layer |
| OpenEyes deep-link handoff | Open a validated patient or workflow target after authentication | Browser or broker must reach OpenEyes | Entra OIDC plus OpenEyes authorization | Uses an opaque handoff, not a weaker session cookie | Recommended for contextual links |
| Entra Private Access | Give managed devices per-app access to a private OpenEyes address | Private Network Connector plus Global Secure Access client | Entra access policy plus OpenEyes OIDC | No reason to change OpenEyes cookies | Suitable for private per-app access |
| Entra Application Proxy | Publish a private web application for remote browser access | Outbound Private Network Connector to OpenEyes | Entra preauthentication, then an OpenEyes-compatible SSO method | Proxy and application cookies both require testing | Suitable when remote publishing is required |
| SharePoint Framework plus Azure API broker | Show a narrow read-only summary or perform a controlled launch | Azure back end needs private routed access to OpenEyes | Entra delegated token to broker; broker calls an OpenEyes API | No OpenEyes session cookie in SharePoint | Recommended for limited integration |
| Power Apps or Power Automate plus Azure API broker | A narrow workflow or approved automation | Broker needs private routed access to OpenEyes | Entra to broker; server-side OpenEyes API authentication | No browser session sharing | Possible with strict scope and audit controls |
| SharePoint or Teams iframe | Display the full OpenEyes UI inside Microsoft 365 | Browser must reach both services | Cross-site browser session | Usually requires `SameSite=None`, frame-policy changes, and third-party cookies | Do not use |

## Keep the layers separate

- SharePoint and Microsoft 365 provide discovery, navigation, and optional user-interface components. They do not grant clinical access.
- Entra ID proves the user's identity and can enforce assignment, MFA, device, risk, and network policies.
- Network access determines whether the browser or Azure service can reach the private OpenEyes hostname. Entra sign-in does not create a route.
- OpenEyes maps the identity to institutions, sites, firms, and clinical roles. It remains the authorization authority for patient data and clinical actions.
- An Azure integration service can broker a limited API workflow, but it must not silently replace the OpenEyes audit identity with a shared service account.

## Option 1: SharePoint link plus OpenEyes Entra OIDC

This is the smallest and safest design for a normal OpenEyes launch.

1. In Entra ID, register a single-tenant web application for OpenEyes.
2. Add the Web redirect URI `https://<oe-host>/sso/login`. The value must exactly match the OpenEyes SSO configuration.
3. Use OIDC authorization code flow. Do not enable an implicit flow unless a separately reviewed legacy requirement proves it necessary.
4. Define application roles that express OpenEyes access, for example `OpenEyes-Clinician` and `OpenEyes-ReadOnly`, then assign approved Entra security groups to those roles.
5. Set the Enterprise application's `Assignment required` control so an authenticated tenant user is not automatically an OpenEyes user.
6. Apply Conditional Access to the enterprise application. Select controls appropriate to clinical access, such as MFA or phishing-resistant authentication, compliant devices, approved client platforms, sign-in risk, and named network locations.
7. Configure OpenEyes under `Admin -> Core -> SSO Configurations` using the tenant-specific Entra authority, Client ID, Client Secret, redirect URL, authorization code response type, and the minimum `openid profile email` scopes.
8. Map stable claims for username, email, first name, and last name. Map the Entra `roles` claim to OpenEyes SSO role mappings when Entra should govern OpenEyes access.
9. Attach the SSO configuration to the intended OpenEyes institution and site authentication methods. Do not enable a tenant-wide default role that grants more access than the Entra assignment.
10. Add the OpenEyes URL or the dedicated launch URL to a SharePoint Link web part. Open it as a full page rather than embedding it.
11. Add the same URL to an Entra enterprise application or My Apps tile if users need a launch point outside SharePoint.

Security handling:

- Keep `OESESSID` Strict. A link from SharePoint will not carry the existing session on the first request. Treat this as an intentional boundary and use a supported login or handoff flow.
- Store the OIDC Client Secret only in the protected OpenEyes SSO configuration. Never put it in SharePoint, a link, JavaScript, a repository, or general deployment configuration.
- Set a rotation reminder before the secret expires. OpenEyes must be updated before the old value is retired.
- Request only the claims OpenEyes needs. OpenEyes records SSO claims in its audit trail, so unnecessary claims create unnecessary sensitive audit data.
- Use app roles rather than raw group identifiers when practical. App roles provide stable application-specific values in the `roles` claim.
- Keep a tested local emergency login path under a documented break-glass process. Do not exempt that account from auditing.
- Test sign-in, account creation, role removal, group removal, disabled users, institution selection, logout, session timeout, and cancelled Entra login.

See separate note: `Setting up Single Sign-On (SSO) in OpenEyes` in `knowledge/Openeyes/oe-sso-setup.md`.

## Option 2: patient-context deep-link handoff

A normal SharePoint link is suitable for opening OpenEyes. A link to a patient or clinical workflow needs stronger controls because URLs are copied into browser history, SharePoint metadata, link-scanning services, referrer headers, screenshots, and logs.

Use this flow:

`Source system -> opaque launch reference -> OpenEyes launch endpoint -> Entra OIDC if needed -> OpenEyes authorization -> target page`

1. Create a server-side launch service. It can be an OpenEyes endpoint or an Entra-authenticated Azure App Service or Function.
2. Accept an authenticated server-side request describing an allow-listed destination type and the minimum identifier needed to resolve it.
3. Store the destination server side and return a cryptographically random opaque reference. Do not encode patient identifiers or clinical values in the URL.
4. Expire the reference after a short interval, preferably no more than five minutes, and permit one successful use.
5. On browser arrival, validate the reference, but do not expect the Strict OpenEyes session cookie and do not resolve or display patient data yet.
6. Render a neutral continuation page. Its explicit same-origin click can reuse an existing Strict OpenEyes session. If one-click launch is mandatory, start the supported Entra OIDC flow and establish a fresh OpenEyes session instead.
7. Bind the reference to the continuation or Entra/OIDC authentication transaction using server-side state.
8. After OpenEyes login, resolve the destination and perform the normal patient and function authorization checks for the signed-in OpenEyes user.
9. Consume the reference and audit the result. Do not log its value or the patient context.

If an Azure service hosts the broker:

- Use App Service Authentication or an equivalent OIDC library to accept only the client's Entra tenant.
- Require user or group assignment and an application role for launch creation.
- Use VNet integration for outbound access to the private OpenEyes address. The integration subnet must have DNS and a routed path to OpenEyes, and security rules should allow only the required destination and port.
- Use a managed identity for Azure resources. Store any unavoidable non-Entra OpenEyes API credential in Key Vault and grant only the broker identity access to it.
- Restrict inbound access to the intended Microsoft 365 application or users. Authentication alone is not authorization.
- Enable HTTPS only, a current minimum TLS version, resource logs, security alerts, rate limiting, and correlation identifiers that contain no patient data.

## Option 3: same-origin continuation page

When the source can only provide a static external URL and a second click is acceptable, a lightweight OpenEyes landing page can preserve Strict sessions without an Azure broker.

1. Link SharePoint to an unauthenticated OpenEyes landing route with a signed or allow-listed opaque target.
2. Render no patient information and apply `Cache-Control: no-store` plus a restrictive `Referrer-Policy`.
3. Show `Continue to OpenEyes`.
4. The click creates a same-site top-level request, allowing the existing Strict session to be sent.
5. If the session is missing, authenticate and restore the validated destination after login.

Do not accept an arbitrary `returnUrl`. Store or map target types server side, reject path traversal and external origins, and verify the browser behavior in every supported Edge and Chrome mode.

## Option 4: Entra My Apps launch

Create or use the OpenEyes enterprise application produced by the OIDC registration, assign users or groups, set the visible home-page URL, and expose it in My Apps.

This gives users an Entra-governed application tile and central assignment lifecycle. It does not change network reachability and does not by itself preserve a deep-link destination. Pair it with OpenEyes OIDC and, where needed, the handoff endpoint.

## Option 5: Entra Private Access

Use Private Access when managed user devices need per-application access to a private OpenEyes hostname without broad network access.

1. Deploy at least two Microsoft Entra Private Network Connectors for availability on Windows servers that can resolve and reach the OpenEyes private address.
2. Create a Global Secure Access per-app application segment for the OpenEyes FQDN and HTTPS port only.
3. Assign only the required Entra users or groups.
4. Enable the Private Access traffic-forwarding profile and deploy the Global Secure Access client to managed devices.
5. Apply Conditional Access to the Private Access enterprise application, including the required device and authentication controls.
6. Keep OpenEyes OIDC and OpenEyes authorization in place. Private Access grants a network route, not clinical permission.

Use per-app access rather than a broad IP range when the requirement is only OpenEyes. Review current Microsoft licensing and platform limitations before selecting this design.

## Option 6: Entra Application Proxy

Use Application Proxy when OpenEyes must be published to remote browsers through an Entra-controlled external URL.

1. Deploy redundant Private Network Connectors on Windows servers with private DNS resolution and HTTPS reachability to OpenEyes.
2. Publish the internal OpenEyes URL as an enterprise application and use a custom external domain with a trusted certificate where possible.
3. Select Entra preauthentication, require user assignment, and apply Conditional Access.
4. Preserve the external hostname through the OpenEyes and OIDC redirect configuration. Test absolute URLs, redirects, cookie host and path rewriting, logout, document links, and SSO callbacks.
5. Keep OpenEyes authorization. Application Proxy preauthentication confirms that Entra allowed the connection but does not assign an OpenEyes institution, firm, or clinical role.

OpenEyes does not currently have a documented trusted-header authentication mode for Application Proxy. Do not enable header-based SSO by teaching OpenEyes to trust an inbound username header unless the application is changed to validate that header source and the back end is reachable only from the connector path. A forged trusted header would otherwise become an authentication bypass.

Application Proxy preauthentication followed by OpenEyes OIDC can produce two authentication layers. The Entra browser session may make the second layer appear seamless, but it still needs an end-to-end test. Passthrough avoids the first layer but also gives up Application Proxy preauthentication and its Conditional Access gate.

## Option 7: SharePoint Framework with an Azure API broker

Use this when the goal is to show a small, purpose-built OpenEyes summary or action in SharePoint rather than the full OpenEyes UI.

1. Define the exact data and operations. Prefer read-only data and exclude clinical writes unless end-user attribution can be preserved.
2. Register a separate Entra application for the Azure API and expose narrowly named delegated scopes or app roles.
3. Protect the Azure API with App Service Authentication or explicit Microsoft identity platform token validation. Validate issuer, tenant, audience, signature, expiry, delegated scope, and role.
4. Add the required API permission to the SharePoint Framework package and have a SharePoint administrator approve only that delegated permission.
5. Use `AadHttpClient` from the web part. Do not use the SharePoint cookie as OpenEyes authentication and do not send an OpenEyes username or password to the browser.
6. Configure exact CORS origins for the expected SharePoint tenant. Do not use wildcard origins with credentials.
7. Connect the Azure API to OpenEyes through private routed networking and call an allow-listed xapi operation server side.
8. Store an unavoidable OpenEyes service credential in Key Vault. Let the Azure app's managed identity retrieve it. Rotate it and restrict the OpenEyes API account to the minimum functions.
9. Return only the minimum fields required by the web part. Prevent caching in SharePoint, browsers, content delivery networks, and application logs unless an approved retention design says otherwise.
10. Record both the Entra user and the OpenEyes API identity. If OpenEyes records only a shared service account, do not use this pattern for clinical writes until a reliable end-user audit mechanism exists.

OpenEyes xapi routes authenticate per request and do not use `OESESSID`, so weakening SameSite is neither necessary nor useful for this design.

## Power Apps, Power Automate, Teams, and Outlook

- A normal link in Teams or Outlook has the same security behavior as a SharePoint link. Open OpenEyes as a full top-level page and use the handoff design for patient context.
- A Teams tab is an iframe. Treat it as the rejected embedding design below.
- A Power Apps custom connector or Power Automate flow should call the Entra-secured Azure API broker, not OpenEyes directly. Do not distribute an OpenEyes Basic-auth credential to makers, connectors, browser clients, or flow definitions.
- Automated flows need a separate service identity, narrow permissions, explicit data-minimization rules, retry and idempotency controls, and an auditable business owner. Never make a user-delegated clinical change after the user's token has expired.

## Why full UI embedding is not recommended

SharePoint's Embed web part uses an iframe, requires HTTPS, permits administrators to restrict allowed external domains, and can display a site only when that site allows framing. OpenEyes is intentionally not designed as third-party embedded content.

Making it work would require all of the following:

- allowing the exact SharePoint origin in `Content-Security-Policy: frame-ancestors` and removing any conflicting `X-Frame-Options` behavior;
- changing the OpenEyes session to `SameSite=None; Secure` so it can be sent in a third-party iframe;
- accepting browser third-party-cookie blocking and Microsoft 365 client differences;
- designing clickjacking defenses for every clinical action instead of relying on frame denial;
- testing authentication, logout, popup, download, print, document, keyboard, focus, timeout, and full-screen behavior inside the frame;
- reviewing referrer and URL leakage into SharePoint and Microsoft 365 telemetry;
- treating the SharePoint page and every permitted web part as part of the OpenEyes session security boundary.

`SameSite=Lax` does not make an iframe work, so changing Strict to Lax would weaken the session without delivering this outcome. Do not embed the full UI.

## Cookie requirements

- Keep `OESESSID` host-only with `Path=/`, `Secure`, `HttpOnly`, and `SameSite=Strict`.
- Use a unique session-cookie name for each OpenEyes instance. SameSite does not prevent cookie-name collisions on the same host and path.
- Do not broaden `Domain` to share a session across hostnames.
- Keep the server-side idle timeout authoritative and short enough for clinical workstations.
- Treat OIDC state, nonce, code-verifier, and OpenEyes SSO bootstrap cookies separately from `OESESSID`. They are short-lived protocol state, not clinical authorization.
- Verify every SSO cookie on the wire. A cross-site OIDC `form_post` callback may require a narrowly scoped `SameSite=None; Secure` handshake cookie, while the final OpenEyes session remains Strict.
- Set `HttpOnly` on handshake cookies unless the existing OpenEyes login JavaScript must create or read that specific cookie. Never put patient context in a JavaScript-readable SSO cookie.
- Do not change the global session cookie to solve a callback-state problem in a separate cookie.

See separate note: `Cookie security in OpenEyes (2026-08, verified against v26)` in `knowledge/Openeyes/oe-cookie-security.md`.

## Security baseline for every design

1. Use HTTPS only, HSTS, trusted certificates, current TLS, and exact production hostnames.
2. Keep OpenEyes session fixation protection, CSRF validation, idle timeout, and audit logging enabled.
3. Require Entra assignment and least-privilege OpenEyes roles. Authentication must not imply clinical authorization.
4. Apply Conditional Access in report-only mode first, then enforce it after validating break-glass and service-account exclusions.
5. Prefer app roles over tenant-specific raw group identifiers in tokens. Map roles explicitly and test removal as well as grant.
6. Minimize OIDC claims because claims are security-sensitive and may be recorded in the OpenEyes SSO audit entry.
7. Keep patient data and clinical identifiers out of URLs, tokens, SharePoint lists, analytics, browser storage, referrers, and general infrastructure logs.
8. Use opaque one-time references for contextual links. Authenticate and authorize before resolving them.
9. Allow-list internal destinations. Never accept an arbitrary `returnUrl`, scheme, hostname, path, or state-changing GET action.
10. Use managed identities for Azure-to-Azure access and Key Vault for any unavoidable non-Entra secret.
11. Limit private network routes and firewall rules to the required FQDN, addresses, and ports. Do not grant an Azure integration service broad clinical-network access.
12. Use exact CORS origins and narrow methods and headers. CORS is not authentication and must not be used to expose OpenEyes Basic authentication to a browser.
13. Apply rate limits, replay protection, input limits, generic error responses, and alerts for repeated invalid launch references.
14. Preserve end-user attribution. Do not allow a shared API account to make clinical changes that appear to have been performed by the service account.
15. Define secret and certificate owners, expiry alerts, rotation procedures, and a tested rollback path.
16. Test failed and cancelled Entra sign-in, disabled users, removed roles, clock skew, expired secrets, certificate rollover, network loss, and connector failure.
17. Complete a data-protection assessment, clinical-safety review, threat model, and penetration test before a patient-context or write-capable integration goes live.

## Minimum validation matrix

| Scenario | Expected result |
|---|---|
| Assigned user, valid role, reachable OpenEyes | Successful OIDC login and correct OpenEyes role |
| Valid Entra user but not assigned to the app | Blocked before OpenEyes access |
| Assigned user with no mapped OpenEyes role | OpenEyes login refused |
| Role removed in Entra | OpenEyes access removed on the next SSO login according to the configured mapping |
| SharePoint link with an existing Strict session | Safe handoff or explicit continuation, then requested target |
| SharePoint link with no session | Entra SSO, then requested target |
| Tampered, replayed, expired, or forwarded launch reference | Generic denial with no patient disclosure |
| User lacks access to target patient or function | OpenEyes authorization denial after login |
| Azure broker loses private network access | Controlled error, no fallback to a public or insecure route |
| OIDC secret or certificate expires | Alert and controlled login failure, not bypass |
| API call from an unapproved SharePoint origin | CORS and token validation denial |
| API call with a valid token but wrong audience, tenant, scope, or role | Authorization denial |
| Logout and idle timeout | OpenEyes session ends without leaving a reusable launch reference |

## References

- [Use the SharePoint Link web part](https://support.microsoft.com/en-US/SharePoint/sites-pages/use-the-link-web-part)
- [Use the SharePoint Embed web part](https://support.microsoft.com/en-US/SharePoint/sites-pages/add-content-to-your-page-using-the-embed-web-part)
- [Microsoft identity platform OAuth 2.0 and OpenID Connect](https://learn.microsoft.com/en-us/entra/identity-platform/v2-protocols)
- [OAuth 2.0 authorization code flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow)
- [Add app roles and receive them in tokens](https://learn.microsoft.com/en-us/entra/identity-platform/howto-add-app-roles-in-apps)
- [Assign users and groups to an enterprise application](https://learn.microsoft.com/en-us/azure/active-directory/manage-apps/assign-user-or-group-access-portal)
- [Microsoft Entra Conditional Access](https://learn.microsoft.com/en-us/entra/identity/conditional-access/overview)
- [Microsoft Entra Private Access](https://learn.microsoft.com/en-us/entra/global-secure-access/concept-private-access)
- [Microsoft Entra Application Proxy](https://learn.microsoft.com/en-us/entra/identity/app-proxy/overview-what-is-app-proxy)
- [Application Proxy cookie settings](https://learn.microsoft.com/en-us/entra/identity/app-proxy/application-proxy-configure-cookie-settings)
- [Consume an Entra-secured enterprise API from SharePoint Framework](https://learn.microsoft.com/en-us/sharepoint/dev/spfx/use-aadhttpclient-enterpriseapi)
- [Manage Entra-secured API access in SharePoint](https://learn.microsoft.com/en-us/sharepoint/api-access)
- [Azure App Service and Functions authentication](https://learn.microsoft.com/en-gb/azure/app-service/overview-authentication-authorization)
- [Azure Functions networking options](https://learn.microsoft.com/en-us/azure/azure-functions/functions-networking-options)
- [Secure Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/general/secure-key-vault)
- [Add and manage Microsoft Entra application credentials](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials)
