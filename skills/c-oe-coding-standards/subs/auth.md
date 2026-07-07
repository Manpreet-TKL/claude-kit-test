# Auth (replatform)

## Auth

Cross-framework authentication and authorisation live in `OELaravel\Modules\YiiAuth` and follow
standard Laravel auth conventions rather than ad-hoc inline checks.

**Authentication**
- `YiiStore extends Store` for Yii-compatible session identifiers; `YiiDatabaseSession` maps GC/reads to Yii session defaults.
- `YiiSessionGuard` handles Basic-Auth-header auth via `YiiUserProvider`, returning an `OELaravel\Models\User`.
- API users authenticate against local passwords mapped through active `UserAuthentication` models, encapsulated in `User::getLocalPasswordForValidation` (no LDAP/header auth planned for the API).

**Authorisation**
- Check via Laravel's `Gate` facade, backed by `YiiRBAC` (wired through `YiiAuthServiceProvider`): returns `true` when `YiiRBAC::check` passes, else falls through to standard Laravel checks.
- `YiiRBAC` is currently scoped to xAPI use cases and the existing "special users" concept.

**Direction of travel**
- Move away from hard-coded user references; prefer HMAC token-based auth over Basic Auth - it gives granular audit, duplicate-query prevention, and future data-sharing options.
- Future RBAC: bizrules as invokable classes operating on DTOs/Services (not Yii models), checking auth-item assignments via a repository.

```php
if (Gate::allows('view-clinical', $patient)) { /* ... */ }
```

---
Source: Authentication & Authorisation (3171155969).
