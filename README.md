# website

Public publisher for [mathiassm.dev](https://mathiassm.dev).

The written content is private and lives in [`MathiasSM/web-writings`](https://github.com/MathiasSM/web-writings). This repository only holds the GitHub Actions pipeline that builds that content with [MathiasSM/Cozyll](https://github.com/MathiasSM/Cozyll) and publishes it to GitHub Pages. Nothing from the content repo is committed here.

## Pipeline

```
web-writings: commit to master
        |
        v
web-writings: .github/workflows/dispatch-site.yml   (Deploy site)
        |  gh workflow run deploy.yml (workflow_dispatch)
        v
website: .github/workflows/deploy.yml               (Build and deploy)
        |  Cozyll site-ci.yml: checkout content -> build -> checks
        |  then this repo runs the publish guard and Pages
        v
https://mathiassm.dev
```

- `dispatch-site.yml` (in the content repo) fires on a commit to `master` and starts this repo's `deploy.yml` with `workflow_dispatch`.
- `deploy.yml` calls Cozyll's reusable `site-ci.yml`, which checks out `web-writings` with `CONTENT_TOKEN`, installs the kit, builds the site, and runs the checks (internal links, content schema, HTML, a11y advisory, JSON-LD, well-known, XML, external links).
- The deploy job runs the publish guard and publishes the `site` artifact to Pages.
- A monthly schedule in `deploy.yml` rebuilds as a canary for link rot and expiring `security.txt`.

## Triggers

Website:
- `push` to any branch, any file: build and checks. Deploy only on `master`.
- `pull_request` that touches `.github/workflows/**`: build and checks for PRs from this repository. Fork PRs get no secrets, so the site build is skipped; `lint.yml` still runs for them.
- `workflow_dispatch`: build and checks; deploy only when dispatched on `master`.
- `schedule`: monthly, on `master`, build and deploy.
- Every build uses `website.yaml`'s `mathiassm.dev` domain; there is no per-branch domain override.

`web-writings`:
- `push` to any branch: `Content CI` builds and checks that branch.
- `push` to `master`: `Deploy site` also starts the website pipeline.
- No PRs (private repo) and no schedule; the website schedule exercises `master`.

## Kit version

The Cozyll version is pinned in two places and must stay equal:

- `web-writings/.cozyll-version` - one release tag such as `v3.5.1.0` (blank lines and `#` comments are ignored). This decides the downloaded kit and `web-writings`' commit checks.
- this repo's `deploy.yml` - the `site-ci.yml@v3.5.1.0` pin.

The reusable `site-ci` workflow fails the build if the tag it was called at differs from `content/.cozyll-version`, so a version bump means editing both files together; forgetting one fails loudly. There is no `cozyll-version` input passed here.

## Manual deploy

```sh
./deploy.sh
```

That runs `gh workflow run deploy.yml --repo MathiasSM/website --ref master`. You can also run the `Deploy site` workflow in `web-writings`.

## Secrets and tokens

| Secret | Where | Scope | Purpose |
| --- | --- | --- | --- |
| `CONTENT_TOKEN` | this repo (repository secret) | Fine-grained PAT, `MathiasSM/web-writings` only, `Contents: Read-only` | Check out the content repo in the reusable workflow |
| `SITE_DISPATCH_TOKEN` | `MathiasSM/web-writings` | Fine-grained PAT, `MathiasSM/website` only, `Actions: Read and write` | Start `deploy.yml` with `workflow_dispatch` |

Neither token may have `Workflows` permission. `CONTENT_TOKEN` is a repository secret because a reusable-workflow caller cannot read an environment secret. `SITE_DISPATCH_TOKEN` can start a run on any existing ref but cannot create or edit one; keep this repo owner-only and delete stale branches. Rotate both on their expiry; a failed dispatch in the content repo is the signal a token expired.

## Pages configuration

- Settings -> Pages -> Source: `GitHub Actions`.
- Custom domain: `mathiassm.dev`, with Enforce HTTPS.
- The `github-pages` environment gates the deploy job; keep it restricted to `master`.

## Rules

- Never commit content or build output to this repo (`content/`, `_site/`, `_cache/`, `_artifacts/`, the kit directories). They are gitignored and guarded in CI.
- `deploy.yml` has no `pull_request_target` trigger. Same-repo PRs can read `CONTENT_TOKEN`; fork PRs cannot, so the site job skips them and `lint.yml` is the only check.
- No `actions/cache` for anything derived from `content/`.

## Security notes

The reusable workflow uses `CONTENT_TOKEN` in its build, content-schema, and external-link jobs; all three run on this repo's runner and the token is masked in logs. The external link check reads `content/config/lychee.toml` in place, so that file is never uploaded as an artifact. The `site` artifact is uploaded by the reusable workflow and consumed by the deploy job; it contains only the public site output, and drafts are excluded by the production build. The deploy job runs the publish guard before uploading the Pages artifact.

The public run logs include the built site's file paths because `upload-pages-artifact` runs `tar -v`, and the step summary records the content commit SHA. `CONTENT_TOKEN` is a repository secret, so a compromise of this repo could expose the private content. The `site` job runs on every branch, on same-repo PRs, and on manual dispatch; fork PRs skip it. The deploy job is limited to non-PR runs on `master`. The `if` guards are defence in depth, not a boundary on a branch.

Changes are committed to `master` by the owner.

See [Cozyll's consumer CI docs](https://github.com/MathiasSM/Cozyll/blob/master/docs/consumer-ci.md) for the reusable workflow and checks.
