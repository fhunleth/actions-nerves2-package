# fhunleth/actions-nerves2-package

A collection of GitHub actions for building and deploying Nerves 2 packages.

This is a fork of
[gridpoint-com/actions-nerves-system](https://github.com/gridpoint-com/actions-nerves-system)
for Nerves 2. If your package supports both Nerves 1 and Nerves 2, check
`mix.lock` to determine which action is appropriate.

## Requirements

- A Linux runner with Docker, `script`, and `stty` available. Standard GitHub
  Ubuntu runners provide these tools.
- Erlang/OTP, Elixir, and `nerves_bootstrap` versions supported by the selected
  Nerves 2 release.
- Include `"checksum.exs"` in the package's Hex `:files` list. For a package using
  the legacy `:nerves_package` configuration, set `artifact_checksum: true`
  before building to enable checksum verification by consumers.

`get-br-dependencies` is optional and only applies to Buildroot-based packages.
`build-package` builds the current Nerves package, generates its checksum manifest,
and then builds the Hex package. No Nerves 1 compatibility mode is provided.

## Upgrading from gridpoint-com/actions-nerves-system

This is a separate action for Nerves 2, not a drop-in replacement for Nerves 1.
To migrate an existing workflow:

1. Update the package to Nerves 2 and select compatible Erlang/OTP, Elixir, and
   `nerves_bootstrap` versions.
2. Replace the setup action in every job:

   ```diff
   - uses: gridpoint-com/actions-nerves-system@v1
   + uses: fhunleth/actions-nerves2-package@v0
   ```

3. Rename local action references from `./.actions/build-system` to
   `./actions/build-package`
4. Rename local action references from `./.actions/deploy-system` to
   `./actions/deploy-package`
5. Remove `hex-validate` from `get-br-dependencies` inputs. It remains supported
   by `build-package`.
6. Include `"checksum.exs"` in the package's Hex `:files` list and configure
   consumer checksum verification before building. Legacy `:nerves_package`
   configurations use `artifact_checksum: true`; native Nerves 2 packages use
   checksum validators in their build plan. The action now explicitly builds
   artifacts, generates `checksum.exs`, and only then builds the Hex package.
7. Keep `get-br-dependencies` for Buildroot-based packages. This step is
   optional now.
8. Automatic `mix nerves.system.lint` execution has been removed; add an
   explicit workflow step if you still need it.
9. Update any custom artifact-processing steps: the uploaded artifact
   now includes `artifacts/`, `checksum.exs`, `CHANGELOG.md`, and
   `hex/package.tar` (unless `hex-validate` is false). Draft releases include
   the package archives and `checksum.exs`; Hex publishing remains separate.

## Example

The following example shows how to build and deploy a Buildroot-based Nerves
package. For other packages, omit the `get-br-dependencies` job and remove
`needs: [get-br-dependencies]` from the build job.

```yaml
on: [push]

env:
  OTP_VERSION: 29.1.2
  ELIXIR_VERSION: 1.20.5-otp-29
  NERVES_BOOTSTRAP_VERSION: 1.17.4

permissions:
  id-token: write
  contents: read

jobs:
  get-br-dependencies:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - uses: fhunleth/actions-nerves2-package@v0
      - name: Get Buildroot Dependencies
        uses: ./.actions/get-br-dependencies
        with:
          otp-version: ${{ env.OTP_VERSION }}
          elixir-version: ${{ env.ELIXIR_VERSION }}
          nerves-bootstrap-version: ${{ env.NERVES_BOOTSTRAP_VERSION }}
          push-to-download-site: true
          download-site-url: ${{ vars.PUBLIC_S3_SITE }}
          download-site-bucket-uri: ${{ vars.S3_BUCKET }}
          aws-role: ${{ secrets.AWS_ROLE }}
          aws-region: ${{ vars.AWS_REGION }}
  build-package:
    needs: [get-br-dependencies]
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - uses: fhunleth/actions-nerves2-package@v0
      - name: Build Nerves package
        uses: ./.actions/build-package
        with:
          otp-version: ${{ env.OTP_VERSION }}
          elixir-version: ${{ env.ELIXIR_VERSION }}
          nerves-bootstrap-version: ${{ env.NERVES_BOOTSTRAP_VERSION }}
  deploy-package:
    needs: [build-package]
    if: github.ref_type == 'tag'
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v7
      - uses: fhunleth/actions-nerves2-package@v0
      - name: Deploy Nerves package
        uses: ./.actions/deploy-package
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Setup for use

To get access to the actions provided by this package, you must first add a uses
of this package to your steps. After this, the actions provided will be available
to be used within the job.

```yaml
    steps:
      - uses: actions/checkout@v7
      - uses: fhunleth/actions-nerves2-package@v0
```

### get-br-dependencies

```yaml
      - uses: fhunleth/actions-nerves2-package@v0
      - name: Get Buildroot Dependencies
        uses: ./.actions/get-br-dependencies
        with:
          # OTP, Elixir and nerves_bootstrap versions to use.
          # These are required
          otp-version: ${{ env.OTP_VERSION }}
          elixir-version: ${{ env.ELIXIR_VERSION }}
          nerves-bootstrap-version: ${{ env.NERVES_BOOTSTRAP_VERSION }}

          # Cache the packages downloaded by Buildroot (`~/.nerves/dl`)
          # Default: true
          save-dl-cache: true

          # Push Buildroot packages to an aws s3 bucket
          push-to-download-site: false

          # Public URL for downloading packages uploaded to the aws s3 bucket
          # Required only if push-to-download-site is true
          download-site-url: 'http://dl.nerves-project.org'

          # aws s3 bucket uri for uploading buildroot packages
          # Required only if push-to-download-site is true
          download-site-bucket-uri: 's3://your-s3-bucket/uri/'

          # aws role and region with write access to download-site-bucket-uri
          # Required only if push-to-download-site is true
          aws-role: ${{ secrets.AWS_ROLE }}
          aws-region: ${{ vars.AWS_REGION }}
```

#### Download cache

By default the packages downloaded by Buildroot (`~/.nerves/dl`), are cached
for use in other steps. If you would like to disable saving this cache, set
`save-dl-cache: false` in the `get-br-dependencies` job for your
Nerves package's CI workflow.

#### Package download sites

Buildroot-based Nerves packages download software from many sites on the
Internet. In order to mitigate download failures from sites going offline,
package URLs changing, slow downloads, etc, Buildroot supports primary and backup download
sites. The Buildroot project maintains the default backup download site.
Nerves-specific packages are not on the Buildroot site. Keeping an archive of
all downloaded packages is important to ensure that your project can be built
in the future.

The Nerves project maintains a package download site. This action will use it
by setting `BR2_PRIMARY_SITE` to it. Buildroot will attempt to download
packages from there first. If they don't exist, the normal download URLs will
be tried and if those fail, Buildroot's backup download site will be tried.

This action can push new packages to the download site for future builds. Only
AWS S3 is supported. To use this feature, you will need to set the following
permissions before the `jobs:` in your workflow:
```yaml
permissions:
  id-token: write
  contents: read
```

And you will need to set the following in the `./.actions/get-br-dependencies` action:
```yaml
          push-to-download-site: true

          # Public URL for downloading packages uploaded to the aws s3 bucket
          download-site-url: 'http://dl.nerves-project.org'

          # aws s3 bucket uri for uploading buildroot packages
          download-site-bucket-uri: 's3://your-s3-bucket/uri/'

          # aws role and region with write access to download-site-bucket-uri
          aws-role: ${{ secrets.AWS_ROLE }}
          aws-region: ${{ vars.AWS_REGION }}
```

- Create an AWS S3 bucket.
- Set the bucket policy to allow read-only access for anonymous users.

```json
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"PublicRead",
      "Effect":"Allow",
      "Principal": "*",
      "Action":["s3:GetObject","s3:GetObjectVersion"],
      "Resource":["arn:aws:s3:::<bucket-name>/*"]
    }
  ]
}
```

- In the AWS dashboard, create an AWS role that CI will use to access the S3 bucket.

- If you would like your Nerves package to pull sources from the download site
  when building outside of CI, set the Buildroot primary site in your Nerves
  package's `nerves_defconfig` file to the S3 bucket URL:
  `BR2_PRIMARY_SITE="https://<bucket-name>.s3.amazonaws.com"`

- For more details, reference the following documents:
  * [use iam roles to connect github actions to actions in aws](https://aws.amazon.com/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/)
  * [configuring openid connect in amazone web services](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

### build-package

```yaml
      - uses: fhunleth/actions-nerves2-package@v0
      - name: Build Nerves package
        uses: ./.actions/build-package
        with:
          # OTP, Elixir and nerves_bootstrap versions to use.
          # These are required
          otp-version: ${{ env.OTP_VERSION }}
          elixir-version: ${{ env.ELIXIR_VERSION }}
          nerves-bootstrap-version: ${{ env.NERVES_BOOTSTRAP_VERSION }}

          # Validate and save the Hex package after checksum generation.
          # Default: true
          hex-validate: true
```

The uploaded Actions artifact, `<package name>-<git commit hash>.zip` contains:

```text
artifacts/       Selected package's archives and any configured sidecars
checksum.exs    Generated archive checksums
CHANGELOG.md    Release notes source
hex/package.tar Hex package, unless hex-validate is false
```

These files are also cached for the deployment job in the same workflow run.
The Hex package includes the generated manifest when
`"checksum.exs"` is listed in the project's package files. Download the package's
Actions artifact to retain the Hex package for publishing.

The checksum task covers only archives in the active build plan and replaces
the manifest. Packages with host-specific archives need an additional
aggregation step before Hex packaging to publish a manifest for multiple hosts.

#### Compiler cache

Set `enable-ccache: true` on `build-package` to restore and save the compiler
cache between successful workflow runs. This requires a Nerves version that
supports `NERVES_CCACHE_DIR`; older Nerves versions do not mount the cache.

Nerves mounts the cache inside the build container and sets `CCACHE_DIR`.
Buildroot-based packages automatically enable ccache. Other packages must
install and invoke ccache in their container build scripts.

`ccache-initial-setup` defaults to `--max-size=1G` and controls Buildroot's initial
ccache setup. Cache keys separate repositories, runner architectures, and
`mix.lock`/`nerves_defconfig` configurations. Ccache also checks compiler and
source inputs. Compiler caching is disabled by default.

#### Clean builds

Before each artifact build, `build-package` runs
`mix nerves.artifact.clean --image` to clean the build workspace and remove the
selected package's container image. This prevents reuse of an old artifact image
restored by the runner. Docker can still reuse valid build layers and cached
base images.

#### Build logs and failures

Only the lengthy artifact-build output is hidden from the workflow log. See the
`nerves-package-logs` artifact for full logs. Log artifacts contain raw command
output; avoid printing secrets.

### deploy-package

The `./.actions/deploy-package` action should only be run after a job running the `./.actions/build-package` action and only on a pushed tag.

```yaml
  deploy-package:
    needs: [build-package]
    if: github.ref_type == 'tag'
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v7
      - uses: fhunleth/actions-nerves2-package@v0
      - name: Deploy Nerves package
        uses: ./.actions/deploy-package
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

> [!NOTE]
> `GITHUB_TOKEN` is provided in every action as a secret which needs
> to be passed to the job using it via `${{ secrets.GITHUB_TOKEN }}`
> You can also control the permissions for it which must be
> `contents: write` in order to create the release
>
> See docs for more info:
> * https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/using-github-cli-in-workflows
> * https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token

### Creating a release

To create a release for your Nerves package:
  - Update the package's version in `mix.exs`, or its `VERSION` file if it uses
    one, *without* a leading `v` (`1.0.0`).
  - Update `CHANGELOG.md`, ensuring to create a header with the version number
    that *includes* the leading `v` (`## v1.0.0`).
  - Commit these changes.
  - Add a tag to this commit named after the version that *includes* the leading
    `v` (`v1.0.0`).
  - Push the commit and tag to the git remote (GitHub).
  - The `deploy-package` job will run when the tag is pushed. It will create a
    `v<VERSION>` draft release with the `CHANGELOG.md` notes and compiled Nerves
    package artifacts and `checksum.exs`. Hex publishing remains a separate step.
  - Review the draft release in GitHub, change the name, and publish the
    release.

## Testing

Run the artifact-staging and command-logging tests with:

```sh
elixir -r 'test/*_test.exs' -e ''
```
