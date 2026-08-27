# Pull request CI and local reproduction

Use this reference to diagnose a failed OpenEyes PR check or design local CI parity. Read the files
from the branch and base being investigated: job names, images, dependencies, and dispatch targets
can change.

## Source-of-truth map

| Area | Owner | Source |
|---|---|---|
| Changed-file static analysis | OpenEyes | `.github/workflows/static-analysis.yml` plus the layer-specific PHPCS, PHPStan, and Rector configs |
| PR test stack and selected suites | OpenEyes | `.travis.yml` and `protected/tests/docker-compose.yml` |
| `TESTS_TO_RUN` implementation | OEImageBuilder Web-Dev image | `Web-Dev/init_scripts_dev_only/98-run-ci-tests.sh` |
| External Cypress and Playwright PR runs | External action runner | OpenEyes dispatches metadata; the external runner owns the suites and execution environment |

Most configuration is code, but it is split across repositories. Do not describe the OpenEyes
checkout alone as complete local parity for the external E2E jobs.

## Static analysis range

The workflow compares the PR base SHA directly with the head SHA:

`git diff --name-only --diff-filter=ACMRT <base-sha> <head-sha>`

This is not a merge-base diff. If the feature branch is behind its current base, files changed only
on the base can appear in the comparison. Refresh the relevant remote refs before measuring branch
divergence; a stale local `origin/develop` can hide the problem.

`git fetch origin develop <feature-branch>`

For an old CI run, use its exact base and head SHAs where possible. Inspect both the workflow used by
that run and the current base workflow so later CI changes are not mistaken for the historical job.
If GitHub MCP is unavailable, local Git refs and read-only `git fetch` are enough; do not switch to
GitHub writes or API automation.

The workflow partitions changed production PHP files as follows:

| Layer | Included path | Excluded tests | Config suffix |
|---|---|---|---|
| Yii | `protected/` | `protected/tests/`, `protected/modules/*/tests/` | `.yii` |
| Laravel | `oe-laravel/` | `oe-laravel/tests/` | `.laravel` |
| Shared | `oe-shared/` | `oe-shared/tests/` | `.shared` |

Run every file in the workflow's layer list, not only the file highlighted in the first error. PHP
test files excluded by this filter are still covered by the separate test suite.

PHPCS analyses each complete touched file, not only the lines changed by the PR. Existing violations
elsewhere in a touched file therefore still fail the branch check. Keep those required cleanup edits
in a separate standards patch when reviewing someone else's branch so they are easy to distinguish
from the feature change.

## Static commands

The workflow runs PHP 8.4 with Xdebug disabled. Its effective commands for each non-empty layer are:

- PHPCS: `php -d xdebug.mode=off bin/phpcs --standard=<phpcs-config> --warning-severity=0 <files>`
- PHPStan: `php -d xdebug.mode=off bin/phpstan analyse --configuration=<phpstan-config> <files>`
- Rector: `php -d xdebug.mode=off bin/rector process --config=<rector-config> --dry-run <files>`

The workflow may contain additional checks, such as invalid non-compound `use` statements in
non-namespaced PHP files. Always take the current matrix and commands from the workflow rather than
assuming the three named tools are the complete job.

Use a disposable worktree for dependency installation, autofix, and verification. This keeps
generated files and formatting changes out of the normal checkout. OpenEyes does not track
`composer.lock`, so a fresh install can resolve different dependencies from a historical run;
record that limitation when exact historical parity matters.

For static tools in the Web-Dev image, bypass normal application startup with `--entrypoint php`.
Normal startup expects runtime configuration that static analysis does not need.

`docker run --rm --user <uid>:<gid> --entrypoint php -v <worktree>:/var/www/openeyes -w /var/www/openeyes toukanlabsdocker/oe-web-dev:php8.4-noble -d xdebug.mode=off bin/phpcs --standard=phpcs.yii.xml --warning-severity=0 <files>`

Install Composer dependencies in the disposable worktree before invoking `bin/phpcs`, `bin/phpstan`,
or `bin/rector`. For a PHPCS failure, run the check first, apply PHPCBF only to the failing files,
review the formatting diff, then rerun PHPCS against the complete original layer list. Load
`c-oe-coding-standards` for the layer commands and rules.

## Existing Web-Dev instance

When the user asks to switch a running oe-deploy Web-Dev instance, use its checkout helper from an
interactive shell: `docker compose exec -T web bash -ic 'oec <branch>'`. Do not race it with a raw
`git checkout`, a background branch loop, or another `oec` process. The helper also refreshes
submodules, dependencies, migrations, caches, and assets, so allow it to finish before collecting
results.

OpenEyes does not track `composer.lock`. The checkout helper can consequently resolve dependencies
again on every branch switch even when the shared vendor cache is already populated; this is normal
and can dominate a multi-branch review. After each checkout, record `git status --short --branch`
and `git rev-parse HEAD`, and confirm that no older checkout process remains before running checks.
Discard any result collected while the checkout state was changing.

Do not recreate the Web-Dev service merely to change an injected secret. Its OpenEyes checkout can
live on an anonymous Docker volume, so `docker compose up --force-recreate web` can discard the
current branch and clone `develop` again. Prefer configuring the correct secret before first start.
If recreation is unavoidable, treat the checkout as lost, wait for the replacement container to be
healthy, and run `oec <branch>` again before applying or testing patches.

## Travis PR suite

At the time of writing, `.travis.yml` passes this list to the existing test compose stack:

`TESTS_TO_RUN="PHPUNIT-SAMPLE;PHPUNIT-FIXTURES;CYPRESS_COMPONENT"`

The Web-Dev image dispatcher maps those tokens to:

| Token | Runner |
|---|---|
| `PHPUNIT-SAMPLE` | `protected/scripts/oe-unit-tests.sh --sample-data-only` |
| `PHPUNIT-FIXTURES` | `protected/scripts/oe-unit-tests.sh --fixture-only` |
| `CYPRESS_COMPONENT` | Cypress component tests |

The dispatcher also supports other Cypress, Playwright, wait, cleardown, and build-only modes. Read
`98-run-ci-tests.sh` before relying on a token because the implementation is baked into the selected
Web-Dev image, not the OpenEyes checkout. Load `c-oe-unit-tests` for PHPUnit execution and database
safety, and `c-oeimagebuilder` for image bootstrap details.

The dispatcher exits without running the selected suites unless `OE_MODE=TEST` is present in its
own process environment. Pass both variables explicitly when invoking it in an existing service:

`docker compose exec -T -e OE_MODE=TEST -e 'TESTS_TO_RUN=PHPUNIT-SAMPLE;PHPUNIT-FIXTURES;CYPRESS_COMPONENT' web bash -lc '/init_scripts/98-run-ci-tests.sh'`

An interrupted `docker compose exec` can leave the dispatcher and its PHPUnit child running inside
the container. Before retrying, inspect the process tree and terminate only the exact processes
owned by that interrupted run. Otherwise concurrent test runners can corrupt results or compete for
the same sample database.

The dispatcher is designed to own a short-lived CI container. It creates `/NO_APACHE_RUN`, starts
Apache for the suites, and stops Apache at the end. In a long-running oe-deploy service with a
restart policy, the stopped server and retained sentinel can put the service into a restart loop and
kill the dispatcher before it prints its final logs. After the run, remove only that sentinel from
the existing container, restore Apache, and wait for the service to become healthy. Do not recreate
the service to recover it because that can lose an anonymous-volume checkout.

The dispatcher invokes Cypress directly and does not supply a virtual display. If the container has
no `DISPLAY`, Cypress can fail before discovering any project test with `Missing X server or
$DISPLAY`. When `xvfb-run` is available, run the same component command under it and record the
initial failure as a local runner setup issue rather than a branch test failure.

Treat `PHPUNIT-FIXTURES` as terminal for focused sample-data testing in the same database. The
fixture suite can replace data and module state, so a later focused sample test can fail for reasons
that did not exist before the suite. Run focused branch tests before the full fixture suite. If more
focused tests are required afterwards, rebuild only the verified disposable sample database volume
and wait for the stack to become healthy before collecting new evidence.

Run focused Yii PHPUnit tests from `/var/www/openeyes/protected/tests`, where `phpunit.xml` lives.
Module test directories do not contain that configuration, so using them as the working directory
can produce a setup failure unrelated to the test itself.

Check the Laravel application key before a full suite. A sodium key is not a Laravel application
key: Laravel AES encryption needs a 32-byte key, commonly represented as `base64:` plus 44 base64
characters. Some local oe-deploy templates map `LARAVEL_APP_KEY` to `sodium_crypto_key`, which gives
repeatable `Unsupported cipher or incorrect key length` failures in otherwise unrelated tests.
For a disposable CI instance, generate a separate valid key under `~/.claude/openeyes-ci/`, keep it
mode 600, and mount it as the Laravel key secret. Never store its value in `claude-kit`.

`protected/tests/docker-compose.yml` already owns the sample database, Web-Dev container, checkout
mount, test environment, and generated test keys. A clean checkout can still enter the Web-Dev build
path when `protected/modules/eyedraw/.git/HEAD` is absent; that path may require an SSH key. Keep the
key outside Git, preferably under `~/.claude/openeyes-ci/`, and mount it read-only only for the test
run. Never put the key in `claude-kit`, OpenEyes, an `oed` template, or an environment file tracked by
Git.

## External E2E trigger

The GitHub E2E trigger depends on all static matrix checks succeeding and does not run for a draft
PR. A skipped trigger after a static failure means the external jobs were not dispatched; it does
not mean the E2E suites passed or were unnecessary.

OpenEyes supplies PR metadata and a repository-dispatch event. The external action runner owns the
actual Cypress and Playwright execution. Report local static checks and the Travis-style compose
suite separately from external E2E validation.

## Local CI design

Keep `oed` as a thin orchestrator around the repository-owned commands:

1. Refresh refs and calculate the exact base-to-head file lists.
2. Create a disposable worktree for the head under test.
3. Run static tools without a database or credentials.
4. Invoke `protected/tests/docker-compose.yml` for the full PR suite when required.
5. Inject a machine-local SSH key only if the image must fetch eyedraw.
6. Preserve logs and state exactly which layers and suites completed.

Do not duplicate the OpenEyes database or Web-Dev service definitions in `oed`. Add an orchestration
wrapper first; introduce a new service template only when an evidenced requirement cannot be
expressed through the existing compose file.

## Diagnosis checklist

1. Record the failing job, its exact command, file list, and error output.
2. Fetch the base and feature refs read-only, then identify the exact base and head SHAs.
3. Read the branch's workflow, Travis file, compose file, and relevant layer config.
4. Recreate the workflow's direct diff and layer filtering.
5. Reproduce in a disposable worktree with the same PHP image and dependency setup.
6. Apply the narrowest fix and rerun the complete failing layer list.
7. Run the repository-owned compose suite if the change requires full PR parity.
8. Distinguish static, Travis-style, and external E2E results in the handoff.
