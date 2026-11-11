# Changelog

## v0.1.4

Changes:

- Fix issue where created containers from previous builds were restored and
  builds were incremental. This runs `mix nerves.artifact.clean --image` to fix
  this when it happens.

## v0.1.3

Changes:

- Support `:enable-ccache` again

## v0.1.2

Changes:

- Continue to stream build output for everything but the long artifact build
  step. This adjusts the v0.1.1 change to be friendlier for website only review
  of CI failures.

## v0.1.1

Changes:

- Process logs so that GHA website results are easier to view on error

## v0.1.0

Initial release of `nerves-project/actions-nerves2-package`, a Nerves 2-only fork of
`gridpoint-com/actions-nerves-system`.

- Add `build-package` to explicitly build Nerves package artifacts using Docker.
- Generate `checksum.exs` before building the Hex package.
- Preserve package archives, signature sidecars, checksums, the changelog, and
  the Hex package in the uploaded Actions artifact.
- Add `deploy-package` to create draft GitHub releases containing package
  archives and their checksum manifest.
- Retain optional Buildroot source caching and S3 download-site support through
  `get-br-dependencies`.
- Remove Nerves 1 compatibility, ccache support, and automatic
  `mix nerves.system.lint` execution.

See the [migration guide](README.md#upgrading-from-gridpoint-comactions-nerves-system)
for upgrading an existing workflow.
