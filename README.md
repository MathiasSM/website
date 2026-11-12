# website

Public publisher for [mathiassm.dev](https://mathiassm.dev).

The written content is private and lives in [`MathiasSM/web-writings`](https://github.com/MathiasSM/web-writings). This repository only holds the GitHub Actions pipeline that builds that content with [MathiasSM/Cozyll](https://github.com/MathiasSM/Cozyll) and publishes it to GitHub Pages. Nothing from the content repo is committed here.

## Pipeline

```
web-writings: commit to master
        |
        v
web-writings: .github/workflows/dispatch-site.yml   (Deploy site)
        |  repository_dispatch (content-updated)
        v
website: .github/workflows/deploy.yml               (Build and deploy)
        |  Cozyll site-ci.yml: checkout content -> build -> checks
        |  then this repo runs the publish guard and Pages
        v
https://mathiassm.dev
```

- `dispatch-site.yml` (in the content repo) fires on a commit to `master` and sends a `repository_dispatch` to this repo.
- `deploy.yml` calls Cozyll's reusable `site-ci.yml`, which checks out `web-writings` with `CONTENT_TOKEN`, installs the kit, builds the site, and runs the checks (internal links, content schema, HTML, a11y advisory, JSON-LD, well-known, XML, external links).
- The deploy job runs the publish guard and publishes the `site` artifact to Pages.
- A monthly schedule in `deploy.yml` rebuilds as a canary for link rot and expiring `security.txt`.

## Kit version

The reusable workflow resolves the kit version from its `cozyll-version` input when set, then `.cozyll-version` at the content repo root, then `latest`. This repo passes no `cozyll-version`, so `web-writings/.cozyll-version` decides. The file holds one release tag such as `v3.4.3.1`; blank lines and `#` comments are ignored.

## Manual deploy

```sh
gh api --method POST repos/MathiasSM/website/dispatches \
  -f event_type=content-updated
```

Or run the `Deploy site` workflow in `web-writings`. The website workflow has no `workflow_dispatch` so that only the default branch can run with `CONTENT_TOKEN`.

## Secrets and tokens

| Secret | Where | Scope | Purpose |
| --- | --- | --- | --- |
| `CONTENT_TOKEN` | this repo (repository secret) | Fine-grained PAT, `MathiasSM/web-writings` only, `Contents: Read-only` | Check out the content repo in the reusable workflow |
| `SITE_DISPATCH_TOKEN` | `MathiasSM/web-writings` | Fine-grained PAT, `MathiasSM/website` only, `Contents: Read and write` | Send the `repository_dispatch` |

Neither token may have `Workflows` permission. `CONTENT_TOKEN` is a repository secret because a reusable-workflow caller cannot read an environment secret; the workflow has no `workflow_dispatch`, so only `repository_dispatch` and `schedule` runs on the default branch can use it. Rotate both on their expiry; a failed dispatch in the content repo is the signal a token expired.

## Pages configuration

- Settings -> Pages -> Source: `GitHub Actions`.
- Custom domain: `mathiassm.dev`, with Enforce HTTPS.
- The `github-pages` environment gates the deploy job; keep it restricted to `master`.

## Rules

- Never commit content or build output to this repo (`content/`, `_site/`, `_cache/`, `_artifacts/`, the kit directories). They are gitignored and guarded in CI.
- `deploy.yml` has no `pull_request` or `pull_request_target` trigger; fork PRs cannot run it or read secrets.
- No `actions/cache` for anything derived from `content/`.

## Security notes

The reusable workflow uses `CONTENT_TOKEN` in its build, content-schema, and external-link jobs; all three run on this repo's runner and the token is masked in logs. The external link check reads `content/config/lychee.toml` in place, so that file is never uploaded as an artifact. The `site` artifact is uploaded by the reusable workflow and consumed by the deploy job; it contains only the public site output, and drafts are excluded by the production build. The deploy job runs the publish guard before uploading the Pages artifact.

The public run logs include the built site's file paths because `upload-pages-artifact` runs `tar -v`, and the step summary records the content commit SHA. `CONTENT_TOKEN` is a repository secret, so a compromise of this repo could expose the private content; the workflow has no `workflow_dispatch`, so a non-default ref cannot run it. `SITE_DISPATCH_TOKEN` can write to this repo (required for `repository_dispatch`), so keep a `master` ruleset that blocks direct pushes and deletions.

Changes are committed to `master` by the owner.

See [Cozyll's consumer CI docs](https://github.com/MathiasSM/Cozyll/blob/master/docs/consumer-ci.md) for the reusable workflow and checks.
