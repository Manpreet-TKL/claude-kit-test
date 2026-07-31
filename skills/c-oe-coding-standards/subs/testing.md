# Testing

PHPUnit (v11) for code-level tests, Cypress for genuine browser interactivity. Prefer fast backend
tests; reserve Cypress for JS/UI that can't be exercised from the backend. CI runs PHPUnit on every PR.

**Writing or running PHPUnit tests? Load the `oe-unit-tests` skill** - it holds the run commands,
factory/idiom patterns and environment gotchas that used to live in this file; this file keeps only
the standards.

## PHPUnit attributes

Use PHPUnit **attributes**, not phpdoc annotations (annotations removed in v11). Data providers must
be `static`. `#[CoversClass]` at the top; `#[Group]` for the application area - reuse existing
groups (`oeunittests --list-groups`).

## Running tests

Run through the `oeunittests` helper so the right bootstrap is applied per layer (see `docs/testing`):
`oeunittests --group=<group>` / `--shared oe-shared/tests` / `--laravel oe-laravel/tests`. Direct
`phpunit` invocation, paths and container caveats: `oe-unit-tests` skill.

## Base classes

Pick the context's base class:
- Legacy: `OEDbTestCase` -> `ActiveRecordTestCase` -> `ModelTestCase`; `RestTestCase` for APIs.
- Shared business logic: shared-context tests.
- Laravel: `OELaravel\Tests\TestCase` (transaction-managed, primary DB) or `OELaravel\Tests\InMemoryTestCase` (isolated, for generic reusable behaviour). Mock via the container (DI).
- **Fixture-based legacy tests are deprecated - write no new ones.** Laravel-layer tests follow Laravel testing conventions.

## Keep DB clean

A `sample-data` test must leave the DB untouched. Use **exactly one** isolation trait, on an
`OEDbTestCase`: `WithTransactions` (**preferred** - each test in a rolled-back transaction; unusable
if the code under test opens its own transactions or makes real server requests) or
`ResetsCreatedModels` (declare every created model, child before parent). Trait mechanics and
examples: `oe-unit-tests` skill.

## Test scenarios

Tests consider **expected and unexpected scenarios** - the happy path plus failure/empty/error
paths, edge cases, and different user roles or states where the behaviour varies by them.

## Factories

Use the Laravel-style model factories, not hand-rolled setup: `withoutParents()` to suppress
parents, `unique()` faker for constrained fields, `withDefaultRelations()` (not `configure()`),
`firstOrCreate` for lookups, `Event::factory()->forEventType*`. Recipes: `oe-unit-tests` skill.

## Application requests

Feature-test the full Yii request lifecycle without Cypress via the `MakesApplicationRequests`
trait (on an `OEDbTestCase`, usually with `WithTransactions`): query-string GET params,
`actingAs($user, $institution)`, wrapper assertions. Mechanics: `oe-unit-tests` skill.

## Process isolation

Many modules share the `DefaultController` classname, which collides across a single run.
Non-namespaced module route tests need `@runTestsInSeparateProcesses` +
`@preserveGlobalState disabled` (or per-test `@runInSeparateProcess`).

## Regression tests

For a support-ticket fix, add **>=1 test** that covers the failure state and now passes (PHPUnit or
Cypress as appropriate). Urgent/critical fixes may ship without one - then a follow-up ticket must add
it, unless already slated for a coming release. Prefer also defining a `ModelFactory` for the elements involved.

## New functionality

Cover new functionality with at least an end-to-end happy-path test. Prefer the PHPUnit
application-request approach over Cypress (faster, less brittle); expand existing test abstractions.

## Cypress

Cypress is the primary frontend/E2E framework, for JS interactivity (popups, eyedraw) and
patient-pathway flows - developers write these for features/bugs they work on. Tests live in
`cypress/e2e` (support in `cypress/support`).

```bash
cy:open                 # interactive GUI (needs X server)
cy:run                  # full headless suite
cy:run --spec <path>    # single test/folder
```

- Classify tests **short vs long**: short run on every PR (keep fast - critical/easily-broken features + basic happy paths); long run overnight on key branches (failures reported in Slack, may auto-raise a Jira ticket).
- A `short_tests` / `long_tests` folder split is planned but not yet in place - for now all live together and run per-PR.

---
Sources: PHPUnit (1570242611), Frontend testing (2235006977), Testing & Data Generation (3059286020), Keeping the database clean (2993979395), Application Request Testing (2238611457), Developer Checklist (2227634177).
