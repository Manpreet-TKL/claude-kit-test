# OEImageBuilder — local-source variant (volatile)

For offline builds or work-in-progress branches that aren't pushed to GitHub yet, the `git` stage can be skipped and the build can read from a local OpenEyes checkout instead.

## When to use

- You're on a host with no GitHub access.
- You're iterating on a branch that you'd rather not push every five minutes.
- You're testing a patch that crosses repo boundaries (OE + a module) and want to bind-mount both.

## How

```bash
./build.sh \
  --source local \
  --oe-src /path/to/openeyes \
  --module-src /path/to/modules \
  --tag wip-$(git -C /path/to/openeyes rev-parse --short HEAD)
```

This sets `BUILD_SOURCE=local`, and the Dockerfile's stage 1 `COPY` (instead of git clone) pulls from the bind-mounted path. Everything from stage 2 onward is identical.

## Constraints

- The local checkout must have its own `composer.lock` and `package-lock.json` committed (or at least present). Stage 2/3 still run in CI mode.
- The tag **must not** look like a release tag (no `vNN.N.N`). Use `wip-…`, `pr-…`, or `local-…` so it can't accidentally end up in production.
- Pushing a local-source build to Docker Hub requires `--push --force-local`. That second flag is intentional friction.

## Common pitfalls

- **"composer.lock not found"** — your local checkout never ran `composer install`. Run it host-side first, or use the git path.
- **"modules dir empty"** — `--module-src` must point at a directory whose children are module repos, not at a single module.
- **Tag collision** — if you build `wip-abc123` twice from a dirty tree, you'll silently overwrite. Use `--tag` with a uniquifier (timestamp, git status hash) for trees that aren't clean.
