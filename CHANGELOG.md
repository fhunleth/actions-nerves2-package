# Changelog

## v0.1.1

Changes:

- Process logs so that GHA website results are easier to view on error

## v0.1.0

Initial release of `fhunleth/actions-nerves2-package`, a Nerves 2-only fork of
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
