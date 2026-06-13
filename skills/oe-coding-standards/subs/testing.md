# Testing

PHPUnit (v11) for code-level tests, Cypress for genuine browser interactivity. Prefer fast backend
tests; reserve Cypress for JS/UI that can't be exercised from the backend. CI runs PHPUnit on every PR.

## PHPUnit attributes

Use PHPUnit **attributes**, not phpdoc annotations (annotations removed in v11). Data providers must
be `static`.

```php
#[\PHPUnit\Framework\Attributes\CoversClass(ExampleBaseActiveRecord::class)]
#[\PHPUnit\Framework\Attributes\Group('sample-data')]
class ExampleTest extends \ModelTestCase {
    public static function caseProvider(): array { return [/* ... */]; }
    #[\PHPUnit\Framework\Attributes\DataProvider('caseProvider')]
    public function testThing($case): void { /* ... */ }
}
```

- `#[CoversClass]` at the top; `#[Group]` for the application area — reuse existing groups (`oeunittests --list-groups`).

## Running tests

Run through the `oeunittests` helper so the right bootstrap is applied per layer (see `docs/testing`):

```bash
oeunittests --group=sample-data
oeunittests --shared  oe-shared/tests
oeunittests --laravel oe-laravel/tests
```

## Base classes

Pick the context's base class:
- Legacy: `OEDbTestCase` → `ActiveRecordTestCase` → `ModelTestCase`; `RestTestCase` for APIs.
- Shared business logic: shared-context tests.
- Laravel: `OELaravel\Tests\TestCase` (transaction-managed, primary DB) or `OELaravel\Tests\InMemoryTestCase` (isolated, for generic reusable behaviour). Mock via the container (DI).
- **Fixture-based legacy tests are deprecated — write no new ones.** Laravel-layer tests follow Laravel testing conventions.

## Keep DB clean

A `sample-data` test must leave the DB untouched. Use **exactly one** isolation trait, on an `OEDbTestCase`:
- `WithTransactions` (**preferred**) — wraps each test in a transaction, rolled back pass or fail. Unusable if the code under test opens its own transactions (Yii has no nested transactions) or makes real server requests.

  ```php
  class ExampleTest extends \OEDbTestCase { use \WithTransactions; }
  ```

- `ResetsCreatedModels` — when transactions can't be used. Records max PK per tracked model at start, deletes higher-PK rows at the end; declare every model created, **child before parent** (FK order):

  ```php
  use ResetsCreatedModels;
  protected array $additional_clean_up_models = [ChildElement::class, ParentElement::class];
  protected bool $creates_events   = true;  // events, episodes (+patients)
  protected bool $creates_patients = true;  // identifiers, patients, contacts, addresses
  ```

## Factories

- Laravel factories resolve belongs-to parents on `make()` — call `withoutParents()` for legacy-equivalent behaviour.
- Generate every unique-constrained value via Faker `unique()` (tests run in a transaction, which reduces but doesn't guarantee collision avoidance).
- Default relations go in an explicit `withDefaultRelations()` method (first-party `has()` API), **not** `configure()`/`afterCreate`.
- "Use existing" lookup/reference data via `Model::firstOrCreate([...])`.
- Events: `Event::factory()->forEventTypeName('Examination')->create()` (pass `true` 2nd arg to create the type) or `->forEventTypeClassname('OphCoCorrespondence')` (throws if unresolved). Module factory: `OELaravel\Database\Factories\Modules\{class_name}\EventFactory`.

```php
$patient = Patient::factory()->withDefaultRelations()->create();
$this->faker->unique()->words(3, true);
```

## Application requests

Feature-test the full Yii request lifecycle without Cypress via the `MakesApplicationRequests` trait
(on an `OEDbTestCase`, usually with `WithTransactions`):

```php
use \MakesApplicationRequests;
[$user, $institution] = $this->createUserWithInstitution();
$this->actingAs($user, $institution)->get('OphCiExamination/view/?id=123456')->assertSuccessful();
```

- **GET params go in the query string**, not as path segments (`/view/?id=123`, not `/view/123`).
- Authenticate with `actingAs($user, $institution)` (users always work within an institution) — don't perform a login step. RBAC: `User::factory()->withAuthItems(['User','Edit','View clinical'])` + `Institution::factory()->withUserAsMember($user)`.
- Responses are an `ApplicationResponseWrapper`: `assertSuccessful()`, `assertRedirect(...)`, `assertException(\CHttpException::class, ['message' => 'Login Required'])`, `crawl()` (Symfony `DomCrawler`).
- JSON: emit via `RenderJsonTrait::renderJSON` and flag the request with `$this->ajaxRequest()->get(...)`.
- Will fail if the code under test calls `Yii::app()->end()` — avoid covering such endpoints this way.

## Process isolation

Many modules share the `DefaultController` classname, which collides across a single run. Non-namespaced
module route tests need separate processes:

```php
/**
 * @runTestsInSeparateProcesses
 * @preserveGlobalState disabled
 */
class ExampleRouteTest extends \OEDbTestCase
```

(or per-test `@runInSeparateProcess` + `@preserveGlobalState disabled`.)

## Regression tests

For a support-ticket fix, add **≥1 test** that covers the failure state and now passes (PHPUnit or
Cypress as appropriate). Urgent/critical fixes may ship without one — then a follow-up ticket must add
it, unless already slated for a coming release. Prefer also defining a `ModelFactory` for the elements involved.

## New functionality

Cover new functionality with at least an end-to-end happy-path test. Prefer the PHPUnit
application-request approach over Cypress (faster, less brittle); expand existing test abstractions.

## Cypress

Cypress is the primary frontend/E2E framework, for JS interactivity (popups, eyedraw) and
patient-pathway flows — developers write these for features/bugs they work on. Tests live in
`cypress/e2e` (support in `cypress/support`).

```bash
cy:open                 # interactive GUI (needs X server)
cy:run                  # full headless suite
cy:run --spec <path>    # single test/folder
```

- Classify tests **short vs long**: short run on every PR (keep fast — critical/easily-broken features + basic happy paths); long run overnight on key branches (failures reported in Slack, may auto-raise a Jira ticket).
- A `short_tests` / `long_tests` folder split is planned but not yet in place — for now all live together and run per-PR.

---
Sources: PHPUnit (1570242611), Frontend testing (2235006977), Testing & Data Generation (3059286020), Keeping the database clean (2993979395), Application Request Testing (2238611457).
