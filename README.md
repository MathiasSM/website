# website

Public publisher for [mathiassm.dev](https://mathiassm.dev).

The written content is private and lives in [`MathiasSM/web-writings`](https://github.com/MathiasSM/web-writings). This repository only holds the GitHub Actions pipeline that builds that content with [MathiasSM/Cozyll](https://github.com/MathiasSM/Cozyll) and publishes it to GitHub Pages. Nothing from the content repo is committed here.

## Pipeline

```
web-writings: merge to master
        |
        v
web-writings: .github/workflows/dispatch-site.yml   (Deploy site)
        |  gh workflow run deploy.yml (workflow_dispatch)
        v
website: .github/workflows/deploy.yml               (Build and deploy)
        |  checkout content -> install kit -> build -> checks -> Pages
        v
https://mathiassm.dev
```

- `dispatch-site.yml` (in the content repo) fires on a merge to `master` and dispatches this repo's `deploy.yml` with the merged commit SHA.
- `deploy.yml` checks out that SHA, installs the Cozyll kit, builds the site, runs the checks (internal links, content schema, HTML, a11y advisory, JSON-LD, well-known, XML, external links), and deploys to Pages.
- A monthly schedule in `deploy.yml` rebuilds as a canary for link rot and expiring `security.txt`.

## Kit version

The Cozyll kit version is read from `.cozyll-version` at the content repo root. The file holds one release tag such as `v3.4.3.1`; blank lines and `#` comments are ignored. A missing or invalid file fails the build, and `latest` is rejected so the build is reproducible. The content repo ships this file; bump it there when upgrading the kit.

The Cozyll action refs are pinned by commit SHA to `v3.4.3.1`; bump them together with the kit version.

## Manual deploy

```sh
gh workflow run deploy.yml --repo MathiasSM/website --ref master
# or pin the content commit:
gh workflow run deploy.yml --repo MathiasSM/website --ref master \
  -f content_sha="$(git -C ../web-writings rev-parse master)"
```

## Secrets and tokens

| Secret | Where | Scope | Purpose |
| --- | --- | --- | --- |
| `CONTENT_TOKEN` | this repo, `github-pages` environment | Fine-grained PAT, `MathiasSM/web-writings` only, `Contents: Read-only` | Check out the content repo |
| `SITE_DISPATCH_TOKEN` | `MathiasSM/web-writings` | Fine-grained PAT, `MathiasSM/website` only, `Actions: Read and write` | Dispatch `deploy.yml` |

Neither token may have `Workflows` permission. `CONTENT_TOKEN` is an environment secret, not a repository secret, so it is withheld from any ref the `github-pages` environment does not allow. Rotate both on their expiry; a failed dispatch in the content repo is the signal a token expired.

## Pages configuration

- Settings -> Pages -> Source: `GitHub Actions`.
- Custom domain: `mathiassm.dev`, with Enforce HTTPS.
- The `github-pages` environment allows jobs from `master` only; this gates both `build` (and its `CONTENT_TOKEN`) and `deploy`.

## Rules

- Never commit content or build output to this repo (`content/`, `_site/`, `_cache/`, `_artifacts/`, the kit directories). They are gitignored and guarded in CI.
- `deploy.yml` has no `pull_request` or `pull_request_target` trigger; fork PRs cannot run it or read secrets.
- No `actions/cache` for anything derived from `content/`.

## Security notes

The `site` artifact is short-lived (1 day) and is uploaded only after the build job's checks pass, so a failed build job does not leave unpublished output in the artifact store; a downstream check failure can leave it for its 1-day retention. The external link check runs inside `build` against the content repo's `config/lychee.toml`; that file is never uploaded as an artifact. The check runs in the same job as `CONTENT_TOKEN` with `harden-runner` in audit mode; the lychee action is SHA-pinned and the config has no executable surface. The public run logs include the built site's file paths because `upload-pages-artifact` runs `tar -v`, and the step summary records the content commit SHA; drafts are excluded by the production build. The content-read token lives in this repo's `github-pages` environment, so a compromise of this repo could expose the private content.

Changes are committed to `master` by the owner.

See [Cozyll's consumer CI docs](https://github.com/MathiasSM/Cozyll/blob/master/docs/consumer-ci.md) for the reusable workflow and checks.
