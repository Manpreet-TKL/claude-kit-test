---
name: oe-unit-tests
description: OpenEyes PHPUnit practice - run commands, patterns, gotchas
disable-model-invocation: false
---

# OE unit tests

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it
never does anything by itself - it just loads knowledge; act only on instructions given in the
conversation.

How to write and run PHPUnit tests in the `openeyes` repo. The *rules* (what must be tested, which
isolation trait, attribute style) stay in `c-oe-coding-standards` #68-77; this skill is the working
practice that satisfies them. Add a test whenever it is possible - "pure refactor" and
"behaviour-preserving" changes still get tests when the touched methods are testable.

## Only the dev container can run tests

The dev web image (`oe-web-dev`) carries the dev Composer packages including PHPUnit; the live-tag
`web` images do not - `docker exec` into a live web container cannot run the suite at all. Run tests
on a dev-image container (or a checkout with dev dependencies installed), never expect them to work
on a production-tagged image.

## Running a test class

- PHPUnit lives at `vendor/phpunit/phpunit/phpunit` - composer's `bin-dir` is `bin`, so there is
  **no `vendor/bin/`**.
- Config is `protected/tests/phpunit.xml`. Its bootstrap `chdir()`s to the webroot *before* PHPUnit
  resolves CLI arguments, so a relative test-file path fails with "Test file not found" - **always
  pass the absolute path** to the test file.
- The dev image enables CLI opcache with a file cache (`opcache.enable_cli=On`,
  `opcache.file_cache=/usr/local/php/opcache`); after editing the code under test, run with
  `-d opcache.enable_cli=0` to rule out a stale compiled class.

```bash
docker exec -w /var/www/openeyes/protected/tests <web-ctr> php -d opcache.enable_cli=0 ../../vendor/phpunit/phpunit/phpunit -c phpunit.xml --colors=never /var/www/openeyes/protected/tests/unit/models/<Class>Test.php
```

Where the `oeunittests` helper exists it wraps the right bootstrap per layer:
`oeunittests --group=<group>`, `oeunittests --shared oe-shared/tests`,
`oeunittests --laravel oe-laravel/tests`.

Expect model suites to be slow and heavy - a 37-test model class takes ~75 s and peaks over 7 GB.
Run one class at a time, not the tree.

## Which database the tests hit

`protected/config/core/test.php` picks the DB as `DATABASE_TEST_NAME`, falling back to
`DATABASE_NAME`, falling back to `openeyes_test`. On a box where `DATABASE_TEST_NAME` is unset the
tests run against the **main schema**. So: check `env | grep DATABASE` before the first run on any
new box, and never run a DB-touching test class without an isolation trait.

## Base class and isolation

Legacy chain: `OEDbTestCase` -> `ActiveRecordTestCase` -> `ModelTestCase` (`RestTestCase` for
APIs); Laravel: `OELaravel\Tests\TestCase` / `InMemoryTestCase`. Never write new fixture-based
tests.

Exactly one isolation trait per class, `WithTransactions` preferred
(`protected/tests/test-traits/WithTransactions.php`): `OEDbTestCase` discovers
`setUp<Trait>`/`tearDown<Trait>` hooks Laravel-style, so `use WithTransactions;` on the class is the
whole change - every test then runs in a rolled-back transaction (only auto-increment residue
remains). Unusable when the code under test opens its own transactions or makes real server
requests; then `ResetsCreatedModels` with `$additional_clean_up_models` declared child-before-parent
(FK order), plus `$creates_events` / `$creates_patients` flags.

Older model test classes may carry **no** isolation trait at all - their factory rows commit to the
test DB on every run. When touching such a class, add `use WithTransactions;` and say so in the PR.

## Test idiom (match the existing suite)

Attributes not annotations (PHPUnit 11), snake_case descriptive test names reading as sentences,
arrange-act-assert:

```php
#[\PHPUnit\Framework\Attributes\Test]
public function getPreviousMedication_returns_the_entry_linked_by_latest_med_use_id()
{
    $event_medication = EventMedicationUse::factory()->medicationHistoryEntry()->create();
    $linked = EventMedicationUse::factory()->medicationHistoryEntry()->forLatestMedUseId($event_medication->id)->create();

    $previous_medication = $event_medication->getPreviousMedication();

    $this->assertNotNull($previous_medication);
    $this->assertEquals($linked->id, $previous_medication->id);
}
```

- `#[CoversClass]` at the top of the class; `#[Group]` reusing an existing group; data providers
  `static`.
- Chain/state fixtures come from factory states (`->forLatestMedUseId($id)`,
  `->medicationParametersChangedStopped()`, ...) - check the model's factory in
  `protected/factories/` for existing states before inventing setup code.
- To pin *memoisation* (not just the resolved value), `assertSame($obj->getX(), $obj->getX())` -
  two calls must return the identical instance. This genuinely fails against unmemoised code.
- A method that `usort()`s re-keys its array to `0..n` - assert on index `[0]`, not the original
  key.

## Factories

- Laravel-style factories under `protected/factories/`; `definition()` usually supplies parents
  (e.g. `'event_id' => Event::factory()`), so created rows come with a usable relation graph.
- `withoutParents()` suppresses belongs-to parents; unique-constrained values via
  `$this->faker->unique()`; default relations in `withDefaultRelations()` (not `configure()`);
  lookup rows via `Model::firstOrCreate([...])`.
- Events: `Event::factory()->forEventTypeName('Examination')->create()` or
  `->forEventTypeClassname('OphCoCorrespondence')`.

## Application requests (feature-level PHPUnit)

`MakesApplicationRequests` on an `OEDbTestCase` (usually with `WithTransactions`) exercises the full
Yii request lifecycle without Cypress:

```php
[$user, $institution] = $this->createUserWithInstitution();
$this->actingAs($user, $institution)->get('OphCiExamination/view/?id=123456')->assertSuccessful();
```

GET params go in the query string, not path segments; authenticate with `actingAs()` (never a login
step); RBAC via `User::factory()->withAuthItems([...])` + `Institution::factory()->withUserAsMember($user)`;
responses wrap in `ApplicationResponseWrapper` (`assertSuccessful()`, `assertRedirect()`,
`assertException()`, `crawl()`); JSON endpoints need `$this->ajaxRequest()`. Fails if the code calls
`Yii::app()->end()`.

Non-namespaced module `DefaultController` route tests collide across one run - isolate with
`@runTestsInSeparateProcesses` + `@preserveGlobalState disabled` on the class.

## Gotchas learnt the hard way

- **"Impossible" failure? Re-verify the code under test is on disk.** A container working tree can
  lose uncommitted changes mid-session (someone else's checkout, a reset). Before debugging, grep
  the file for a symbol your change introduced (`grep -c '<new_symbol>' <file>`); a reverted tree
  reproduces exactly like a broken patch. `ReflectionClass::getFileName()` +
  `property_exists($obj, '<new_prop>')` settles *which* file the runtime actually loaded.
- The bootstrap-chdir/absolute-path and no-`vendor/bin` traps above burn a run each; the
  DATABASE_TEST_NAME fallback silently pointing at the main schema is the dangerous one.
