# Development

The CLI's source lives in the private m2cloud monorepo; this documentation
mirrors to the public repo on every release. To work on the docs:

```sh
uvx mkdocs serve -f apps/m2-cli/mkdocs.yml   # live preview on :8000
```

## Layout

```text
apps/m2-cli/
  mkdocs.yml            this site's configuration
  docs/                 markdown source (this tree)
  packaging/
    m2cloud.example.toml   annotated config example (release asset)
scripts/
  install-cli.sh        the one-line installer served by Pages
```

## Publishing flow

```text
edit here (private repo, apps/m2-cli/docs/)
        │  merge to main + release pipeline runs
        ▼
release.yml "Mirror release" job
        │  copies docs/ + mkdocs.yml + install.sh + example.toml to the public repo
        ▼
public repo .github/workflows/pages.yml
        │  mkdocs build → _site/ → deploy to Pages
        ▼
https://mt2-saas.github.io/m2cloud-cli/
```

- Docs-only changes still trigger a release (the pipeline can't tell), but a
  failed build should never reach `main` — `mkdocs build --strict` runs in CI
  (see below).
- The mirror syncs `install.sh` and `m2cloud.example.toml` too, so the public
  repo never again drifts from the private source of truth.

## CI guard

The private repo's CI gains a `docs` job: `uvx mkdocs build --strict` on every
PR and push touching `apps/m2-cli/docs/**` or `mkdocs.yml`. `--strict` turns a
warning (broken link, missing page in nav) into a failure, so the release
pipeline never receives an unbuildable tree.

## Rules

- Content is faithful to the code: flag names, exit codes and allow-listed
  commands come from `internal/cli` and `internal/commands`, not from memory.
- No secrets, endpoints or credentials in docs — examples use
  `api.m2cloud.example`.
- Language: English (matches the repo's docs conventions).
