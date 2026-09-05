# getbible/v2_builder repository guide

Read this before changing anything. It applies to the whole repository.

## Purpose

`run.sh` builds the getBible JSON API v2. It downloads the Crosswire SWORD
modules listed in `conf/CrosswireModulesMap.json`, converts them to static
JSON files (`src/sword_to_json.py`), hashes every file and writes the indexes
(`src/hash_versions.sh`, `src/hash_books.sh`, `src/hash_chapters.sh`), writes
the OpenAPI document (`src/openapi.py`), verifies that every JSON file has a
correct `.sha` sibling (`src/verify_hashes.py`) and copies the public hash
files into place (`src/movePublicHashFiles.sh`). The deliverables are
described in `README.md` under Deliverables.

## Layout

- `run.sh` - the only entry point; `./run.sh --help` lists the options.
- `src/` - the build steps, sourced or run by `run.sh`.
- `conf/` - the module map, book numbers and names, language tables, and the
  config template.
- `.github/workflows/` - the scheduled build, the test build and the
  keep-active job.

## Rules

- Commits are authored and committed in the maintainer's name: the owner of
  the GitHub connector, `eWɘyn <5607939+Llewellynvdm@users.noreply.github.com>`,
  the identity of this repository's own commits. Do not add a
  `Co-Authored-By` trailer, a session link, an assistant name, or any other
  tool attribution to a commit message, tag, or pull request. This is
  company policy and applies to every repository of the organisation.
- The build standard is stable. The file layout, the fields of every JSON
  file and their order, and the hashing do not change unless explicitly
  requested.
- Every `.json` file in the built tree has a `.sha` sibling holding its
  SHA-1. Indexes exist as `.json` and as tab-separated `.txt`. The names
  `translations`, `checksum`, `books`, `chapters` and `openapi` are reserved
  and never treated as a translation.
- `main` is the only branch. Workflows reference `main`; pull requests target
  `main` and run the test build.
- This repository documents the builder and its deliverables only, never how
  to use the API.

## Verification

`./run.sh --dry` shows the configuration. A full test build needs the
Crosswire modules: `./run.sh --test -q`. Without network access, build a tree
by hand in the shape `src/sword_to_json.py` writes, then run
`./run.sh --hashonly --github --api=<path>/v2 --zip=<path>/sword_zip` and
check that `<path>/v2_scripture/openapi.json` parses and that every `.json`
there has a `.sha` sibling.
