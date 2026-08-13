# Fine-Grained PAT Authentication Migration Design

## Goal

Replace the workshop's GitHub App authentication with one repository-scoped
Fine-grained personal access token (PAT) for:

- KEDA `github-runner` queue monitoring.
- Ephemeral runner registration and removal.

This removes the GitHub App installation requirement that blocks Enterprise
Managed User (EMU) participants when their account policy prohibits App
installation. Fine-grained PAT creation and use remain subject to the
participant's enterprise and organization policies.

## Scope

The migration covers:

- Fine-grained PAT creation and verification in module 01.
- Secure PAT handling in the runner entrypoint.
- PAT-based KEDA and Azure Container Apps Job configuration in module 04.
- Authentication terminology, timing, troubleshooting, security, and cleanup
  across the workshop.
- Runner, documentation, artifact, and integrated validation tests.
- Replacement of the previous GitHub App design and implementation-plan
  records with PAT-specific documents.

The runner remains repository-scoped, the lab repository remains private, and
all existing Azure resource, ACR recovery, scaling, runner-version, and CI
decisions remain unchanged unless explicitly described here.

## Authentication Architecture

The participant creates one Fine-grained PAT with access limited to the single
lab repository.

Required repository permissions:

| Permission | Access |
|---|---|
| Actions | Read-only |
| Administration | Read and write |
| Metadata | Read-only |

A 30-day expiration is recommended for the workshop. If the resource owner
requires token approval, the participant must obtain that approval before
continuing.

The PAT is stored once as an Azure Container Apps secret. KEDA references that
secret through its `personalAccessToken` authentication parameter. The runner
container receives the same secret as `GITHUB_PAT` only for bootstrap and
cleanup.

At process startup, `runner/entrypoint.sh`:

1. Validates the required non-secret inputs and confirms `GITHUB_PAT` is
   present.
2. Copies `GITHUB_PAT` into a non-exported wrapper-shell variable.
3. Immediately unsets the exported `GITHUB_PAT` environment variable.
4. Uses the private shell variable to request a repository runner registration
   token.
5. Configures the runner with `--ephemeral --disableupdate`.
6. Starts `run.sh` without the PAT in its inherited environment.
7. After the runner exits, uses the private shell variable to request a fresh
   removal token when local runner state requires cleanup.

Registration and removal tokens are short-lived and must also remain
non-exported. The entrypoint must never print the PAT or include it in
diagnostic output.

## Runner Behavior

`runner/entrypoint.sh` consumes:

- `GITHUB_PAT`
- `GH_URL`
- `REGISTRATION_TOKEN_API_URL`
- Optional runner label and name inputs already supported by the workshop.

GitHub REST requests continue to use API version `2026-03-10`. Authentication,
registration-token, or runner-configuration failures stop startup with a clear
non-secret error. Cleanup failures remain visible but do not replace the
runner process exit status.

Signal forwarding, ephemeral registration, update disabling, and the existing
runner naming and labeling behavior remain intact.

OpenSSL is no longer required by the runner image for GitHub App JWT signing.
It may be removed from the runner-specific dependency list if no other runner
operation uses it. Cloud Shell instructions continue using OpenSSL to generate
random Azure resource suffixes.

## Workshop Documentation

### Overview

The estimated workshop duration returns from approximately 105 minutes to
approximately 90 minutes because GitHub App creation, installation, private-key
download, and installation-ID discovery are removed.

### Module 01

GitHub App instructions are replaced with:

- Creating a Fine-grained PAT.
- Choosing the correct resource owner.
- Selecting only the lab repository.
- Assigning Actions read-only, Administration read and write, and Metadata
  read-only permissions.
- Using a 30-day expiration unless workshop policy requires a shorter period.
- Completing organization approval when required.
- Loading the PAT with non-echoing shell input and avoiding command history,
  screenshots, logs, and committed files.
- Verifying repository access and required API operations without displaying
  the PAT or returned runner token.

The module explains that this avoids the EMU GitHub App installation path but
does not override enterprise restrictions on PAT creation or approval.

### Module 04

GitHub App ID, installation ID, and PEM inputs are removed. The Job uses:

- One ACA secret containing the Fine-grained PAT.
- KEDA authentication
  `personalAccessToken=<ACA secret name>`.
- Container environment variable `GITHUB_PAT=secretref:<ACA secret name>`.

The document keeps existing safe recovery guidance for partially created Jobs
and must not print the secret in examples or verification output.

### Security and Cleanup

Production guidance explains the trade-off of one shared PAT: it is simple for
the workshop, but compromise affects both queue monitoring and runner
registration. More isolated production designs may use separate credentials or
a token broker.

Cleanup instructions revoke or delete the workshop PAT after Azure resources
are removed and remove any transient Cloud Shell variable. Rotation guidance
updates the ACA secret before revoking an expiring token when the environment
must remain operational.

## Error Handling

- Missing required variables fail before any runner configuration.
- GitHub API HTTP failures and malformed responses fail with a concise,
  non-secret message.
- PAT values and returned short-lived tokens are never echoed.
- A failed registration-token request prevents `config.sh` and `run.sh`.
- Cleanup is attempted only when local runner state exists.
- Cleanup errors are reported without masking the original runner exit code.
- Enterprise policy or pending token approval is documented as an external
  prerequisite, not handled with a success-shaped fallback.

## Testing

Runner tests mock GitHub REST calls, runner configuration, runner execution,
and cleanup. They verify:

- Missing PAT and required inputs fail clearly.
- Registration and removal token requests use PAT authentication.
- API failures prevent runner configuration.
- `--ephemeral` and `--disableupdate` remain present.
- Runner exit status and signal behavior remain preserved.
- Cleanup is attempted when appropriate.
- `run.sh` cannot read `GITHUB_PAT` or the wrapper's private PAT variable.
- PAT and short-lived tokens do not appear in output.

Documentation tests enforce:

- The required Fine-grained PAT permissions.
- Single-repository selection and recommended expiration.
- Safe non-echoing input and enterprise approval guidance.
- PAT-based KEDA authentication and ACA secret references.
- PAT revocation and rotation guidance.

The integrated validator rejects operational GitHub App variables, KEDA App
metadata, PEM handling, JWT generation, and installation-token instructions.
It also checks that PAT naming and secret references are consistent across
runner code and workshop documentation.

## Out of Scope

- Azure Key Vault provisioning.
- An external token broker.
- Separate scaler and runner PATs.
- Classic personal access tokens.
- Organization or enterprise runner scope.
- JIT runner configuration.
- Live Azure tests that create billable resources.
- Bypassing enterprise PAT restrictions or approval policies.

## Acceptance Criteria

- KEDA and runner registration both use the same repository-scoped Fine-grained
  PAT.
- The PAT grants only Actions read-only, Administration read and write, and
  Metadata read-only access to the selected lab repository.
- Workflow processes cannot inherit `GITHUB_PAT`.
- Operational workshop files contain no GitHub App authentication path.
- Module 01 provides an EMU-aware PAT creation and verification path.
- Module 04 consistently configures the ACA secret, KEDA authentication, and
  runner secret reference.
- Cleanup and rotation guidance covers the PAT lifecycle.
- Existing Azure naming, RBAC, ACR recovery, scaling, and runner behavior remain
  correct.
- All repository tests and CI validation pass.
- The workshop timeline totals approximately 90 minutes.
