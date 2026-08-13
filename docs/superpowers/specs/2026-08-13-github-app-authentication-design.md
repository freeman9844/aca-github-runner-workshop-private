# GitHub App Authentication Migration Design

## Goal

Replace the workshop's Fine-grained PAT authentication with a repository-scoped GitHub App for both:

- KEDA `github-runner` queue monitoring.
- Ephemeral runner registration and removal.

The migration must also correct the review findings that can block or mislead workshop participants while keeping the workshop practical in Azure Cloud Shell.

## Scope

This change covers:

- Workshop overview, timing, prerequisites, security guidance, and cleanup.
- GitHub App creation, installation, and credential verification in module 01.
- Azure resource naming and RBAC prerequisite corrections in module 02.
- Runner image dependencies and GitHub App authentication logic.
- KEDA and Azure Container Apps Job configuration in module 04.
- Scale-validation screenshot wording in module 05.
- Automated tests and repository CI.

The workshop remains repository-scoped and private-repository-only. It does not add Azure Key Vault, an external token broker, or organization-scoped runner groups.

## Authentication Architecture

The participant creates a GitHub App owned by their personal account or organization and installs it only on the `aca-runner-lab` repository.

Required repository permissions:

| Permission | Access |
|---|---|
| Actions | Read-only |
| Administration | Read and write |
| Metadata | Read-only |

Webhooks are disabled because the workshop polls the GitHub API through KEDA.

The participant records:

- GitHub App ID.
- GitHub App installation ID.
- Downloaded private key PEM path.
- Repository owner and repository name.

The Azure Container Apps Job stores the PEM as an ACA secret. KEDA uses that secret through the `appKey` authentication parameter together with `applicationID` and `installationID`.

The runner container receives the same secret only during bootstrap. A later human-approved cleanup amendment supersedes the earlier pre-acquired removal-token draft: the entrypoint keeps the PEM only in a non-exported wrapper-shell variable, removes the exported secret variable before the runner starts, and mints fresh cleanup credentials only when cleanup runs. Its entrypoint:

1. Copies the PEM into a non-exported wrapper-shell variable and unsets the exported `GITHUB_APP_PRIVATE_KEY`.
2. Creates a short-lived RS256 GitHub App JWT with OpenSSL.
3. Exchanges the JWT for a one-hour installation access token and requests a repository runner registration token.
4. Configures the runner with `--ephemeral --disableupdate`.
5. Starts the runner without exporting the private key, App JWT, or installation token into workflow process environments.
6. During cleanup, mints a fresh JWT, installation token, and removal token when local runner state remains.

The private key and installation token must not be inherited by workflow processes.

## Runner Implementation

`runner/Dockerfile` explicitly installs `openssl` in addition to the existing tools.

`runner/entrypoint.sh` replaces `GITHUB_PAT` with:

- `GITHUB_APP_ID`
- `GITHUB_APP_INSTALLATION_ID`
- `GITHUB_APP_PRIVATE_KEY`
- `GH_URL`
- `REGISTRATION_TOKEN_API_URL`

The script validates numeric IDs, a PEM-shaped private key, and the registration-token URL before making API calls. It retains the PEM only in a wrapper-shell variable after startup and keeps installation tokens scoped to command substitutions or cleanup locals rather than exported environment variables. GitHub REST calls use API version `2026-03-10`.

Authentication failures must stop runner configuration. Cleanup failures remain visible in logs without replacing the runner process exit code.

## Workshop Documentation

### Overview

The workshop duration changes from approximately 90 minutes to approximately 105 minutes to account for GitHub App creation and installation.

Azure prerequisites state that participants need:

- Contributor access for resource creation.
- `Microsoft.Authorization/roleAssignments/write` at the ACR scope or a role such as Role Based Access Control Administrator, User Access Administrator, or Owner.

### Module 01

Fine-grained PAT instructions are removed. The replacement module documents:

- Creating a private GitHub App.
- Disabling webhooks.
- Assigning the three repository permissions.
- Installing the app only on `aca-runner-lab`.
- Generating and downloading a private key.
- Finding App ID and installation ID.
- Loading values into Cloud Shell without printing the PEM.
- Generating a JWT and installation token to verify repository access.

### Module 02

The suffix uses six hexadecimal characters generated with OpenSSL. If an ACR name still conflicts, the participant changes only the ACR name or restarts resource creation consistently; they do not rerun the full naming block midway through the module.

### Module 04

PAT inputs and secrets are removed. The job uses:

- KEDA metadata `applicationID` and `installationID`.
- KEDA auth `appKey=github-app-private-key`.
- ACA secret `github-app-private-key`.
- Container environment variables for App ID, installation ID, and the secret reference.

The module includes safe recovery guidance for an existing partially created Job instead of implying that `job create` is always rerunnable.

### Modules 05 and 06

The module 05 screenshot description is changed to match the actual in-progress screenshot.

Module 06 receives continuous section numbering and replaces PAT revocation with:

- Removing the GitHub App installation from the lab repository.
- Deleting the workshop-only GitHub App if no longer needed.
- Deleting downloaded and Cloud Shell private-key copies.

Production guidance continues to recommend Key Vault or an external token broker when stronger key isolation is required.

## Testing

The entrypoint test mocks:

- OpenSSL JWT signing.
- Installation access-token creation.
- Registration-token creation.
- Removal-token creation.
- Runner configuration and execution.

It verifies:

- Missing or malformed GitHub App inputs fail clearly.
- API failures prevent runner configuration.
- Ephemeral and update-disable flags remain present.
- Runner exit status is preserved.
- Cleanup is attempted.
- Private key, JWT, and installation token do not appear in output or the runner process environment.

Documentation tests verify GitHub App instructions and KEDA configuration. An integrated check rejects remaining `GITHUB_PAT`, Fine-grained PAT, and personal-access-token configuration references in workshop artifacts.

A repository GitHub Actions workflow runs `bash tests/validate-workshop.sh` for pushes and pull requests.

## Out of Scope

- Provisioning Azure Key Vault.
- Building an external installation-token service.
- JIT runner configuration.
- Organization or enterprise runner scope.
- Automatically creating the GitHub App through a manifest flow.
- Live Azure integration tests that create billable resources.

## Acceptance Criteria

- The workshop contains no PAT-based authentication path.
- KEDA and runner registration both authenticate through the same repository-scoped GitHub App.
- Workflow processes cannot inherit the App private key or installation token.
- Correct Azure RBAC prerequisites are documented.
- ACR collision recovery does not switch all resource names midway through the workshop.
- Screenshot wording matches the checked-in image.
- All repository tests and CI validation pass.
- The updated workshop timeline totals approximately 105 minutes.
