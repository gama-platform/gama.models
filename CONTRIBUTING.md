# Sharing a model in the GAMA model registry

Anyone can add a model to the community registry. GAMA's model discovery can then find it.
You don't need to know git or JSON: you fill in a form and a bot does the rest.

## 1. Put your model online

Zip your GAMA project folder, the one that contains `models/` and `includes/`. With a recent GAMA,
you can also export it as a `.gamp` (editable project) or a `.gamx` (playable model) file.

Then upload it somewhere that gives you a **direct and permanent link** to the file:

| Works | Doesn't work |
|---|---|
| A [GitHub release](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository) asset: `https://github.com/<you>/<repo>/releases/download/v1.0/model.zip` | Branch archives: `…/archive/refs/heads/main.zip`. They change on every commit. |
| [Zenodo](https://zenodo.org), which also gives you a DOI, or [OSF](https://osf.io) | Google Drive links, which open a preview page |
| Your lab's web server | Dropbox links ending with `dl=0` (use `dl=1`) |

The link must never change. The registry records the file's SHA-256 fingerprint, and a weekly check flags any
file that has disappeared or been modified. To publish a new version, upload a **new file** and use the update form.

## 2. Fill in the form

Open [**Share a GAMA model**](https://github.com/gama-platform/gama.models/issues/new?template=submit-model.yml) and fill it in.

The bot then:

1. downloads your file and computes its SHA-256,
2. checks the archive: no unsafe paths, size limits, and a valid manifest for `.gamp` / `.gamx`,
3. **compiles every `.gaml` file** with the GAMA version you chose, using GAMA headless in Docker,
4. posts the result as a comment on your issue.

If everything compiles, the bot opens a pull request that adds your entry. A maintainer reviews and merges it,
and the issue closes automatically. If something is wrong, the comment explains what. **Edit the issue** to fix
it, and the bot runs again.

> Every `.gaml` file in the archive must compile. Remove drafts and old files that are not part of the model.

Compilation is the only check: the bot does not run your simulation.

## 3. Update your model

Use [**Update a GAMA model**](https://github.com/gama-platform/gama.models/issues/new?template=update-model.yml) and give the model ID. The ID is the
`id` field of the [registry index](https://gama-platform.org/gama.models/registry/index.json). You can:

- **publish a new version**: a new link and a new version number. Previous versions stay listed.
- **update the information only**: description, authors, license… Empty fields keep their current value.

Anyone can request an update. If you aren't the original submitter, a listed maintainer, or a member of the
GAMA organisation, the pull request is labelled `needs-owner-approval` and the owners are asked to confirm.

---

## For tool developers: the registry format

Everything is static JSON served by GitHub Pages:

- `https://gama-platform.org/gama.models/registry/index.json`: the list of models
  ([schema](registry/schema/index.schema.json)). Each item has a `path` to the full entry, relative to `index.json`,
  plus a short summary: `name`, `latest_version`, `gama_version`, `format`, `thematics`, `available` and `updated_at`.
- `https://gama-platform.org/gama.models/registry/models/<id>.json`: one entry per model
  ([schema](registry/schema/model.schema.json)).

Each entry's `versions[]` is in publication order, so the last item is the latest. Each version has:

- `url`, `sha256` and `size`: verify the hash after downloading.
- `format`: `zip`, `gamp` or `gamx`.
- `gama_version`, plus `main_model`, `gaml_files` and `experiments`.
- `status`: `available` or `unavailable`, with a `status_reason` such as `hash-mismatch` or `unreachable:http-404`.

## For maintainers

The pieces:

- **Issue forms**: [`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE). The field labels must match
  `LABELS` in [`tools/registry/issue_form.py`](tools/registry/issue_form.py), and a test checks this.
- **Workflows**:

  | Workflow | Runs on | What it does |
  |---|---|---|
  | [`model-submission.yml`](.github/workflows/model-submission.yml) | issue opened, edited or reopened | Validates the issue, opens the PR, comments on the issue. Run it manually (*Run workflow* with the issue number) to process an issue again. |
  | [`registry-ci.yml`](.github/workflows/registry-ci.yml) | PRs touching the registry | Unit tests, plus a check of every entry. |
  | [`deploy-registry.yml`](.github/workflows/deploy-registry.yml) | pushes to `main` that touch `registry/` | Publishes Pages: the content of the `p2-deploy` branch (the legacy p2 update site) plus the generated `registry/`. `index.json` is generated at this step and is never committed, so parallel submissions can't conflict. |
  | [`check-links.yml`](.github/workflows/check-links.yml) | Mondays | Re-downloads every file and compares hashes. Maintains a tracking issue labelled `registry-link-check` and a PR that toggles `status`. |

- **GAMA versions** offered in the forms: [`registry/config.json`](registry/config.json) maps each one to a Docker
  image and the formats it accepts. The size limits are set there too. When you add a version, also add it to the
  `GAMA version` dropdowns of both forms.

One-time setup:

1. *Settings → Pages → Build and deployment → Source*: **GitHub Actions**.
2. *Settings → Actions → General → Workflow permissions*: tick **Allow GitHub Actions to create and approve pull
   requests**. This may have to be allowed at the organisation level first.
3. Optional: PRs opened by the bot with `GITHUB_TOKEN` don't trigger `registry-ci.yml`. The submission workflow
   already validates the entry, so this isn't required. To get CI on bot PRs anyway, pass a GitHub App token to
   `peter-evans/create-pull-request`.

Running the tooling locally (Python 3.12 and Docker):

```sh
python -m venv .venv && .venv/bin/pip install -r tools/registry/requirements.txt
.venv/bin/python -m pytest tools/registry/tests                      # unit tests
.venv/bin/python -m tools.registry build-index --check               # validate registry/models/*.json
.venv/bin/python -m tools.registry validate path/to/extracted/model  # compile with GAMA in Docker
```
