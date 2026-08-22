# Key Vault Module Restructure Design

**Date:** 2026-08-22  
**Status:** Approved

## Goal

Move GitHub App private key bootstrap into Module 01 so participants finish GitHub App setup with its private key already stored in Azure Key Vault. Renumber the current Module 01 step 7 to step 8 and make it authenticate the App ID and Installation ID using the Key Vault secret created in the new step 7.

Key Vault private networking and runtime identity configuration remain in Module 02 because they depend on the VNet, Private Endpoint subnet, and UAMI created there.

## Module 01 Flow

### Steps 1-6

Keep the current subscription, provider, repository, GitHub App, installation, and identifier-loading flow.

### Step 7: Create Key Vault and upload the GitHub App private key

Step 7 has two execution contexts.

#### 7-C: Cloud Shell bootstrap

1. Generate the shared six-character `SUFFIX`.
2. Set `LOC`, `RG`, `KEY_VAULT`, and `GITHUB_APP_KEY_SECRET`.
3. Create the workshop Resource Group.
4. Create an RBAC-enabled Key Vault with:
   - public network access temporarily enabled;
   - default network action `Deny`;
   - no trusted-service bypass;
   - seven-day soft-delete retention;
   - purge protection disabled for workshop cleanup.
5. Ask for the local workstation public IPv4 CIDR and add only that firewall exception.
6. Assign the signed-in user temporary `Key Vault Secrets Officer` access at Key Vault scope.
7. Print and require the participant to retain:
   - `SUFFIX`;
   - `RG`;
   - actual `KEY_VAULT` name;
   - `KEY_VAULT_BOOTSTRAP_CIDR`;
   - `KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID`.

The Key Vault name collision recovery procedure moves from Module 02 to Module 01.

#### 7-L: Local workstation upload

1. Run in local workstation Bash, not Cloud Shell.
2. Sign in with Azure CLI and select the Module 01 subscription.
3. Read the Key Vault name and local GitHub App PEM path.
4. Set local file mode to `600`.
5. Upload the PEM directly with `az keyvault secret set --file` and explicit UTF-8 encoding.
6. Display only secret metadata, never secret content.

The source PEM remains on the local workstation until Module 02 completes Key Vault private networking and access-lock validation.

### Step 8: Authenticate the stored GitHub App installation

Step 8 runs in local workstation Bash and uses the secret stored by step 7:

1. Download the Key Vault secret into a `mktemp` file with mode `600`.
2. Register cleanup before authentication so the temporary file and JWT are removed on success or failure.
3. Create a short-lived GitHub App JWT from the downloaded PEM.
4. Call `GET /app/installations/{installation_id}` with the JWT.
5. Require the response `app_id` to equal the entered App ID.
6. Print the App ID, Installation ID, and installation owner on success.
7. Delete the temporary downloaded PEM immediately.

This proves that the Key Vault secret contains the private key for the entered App ID and that the entered Installation ID belongs to that same GitHub App. It also proves that the uploaded Key Vault secret is readable through the temporary bootstrap path.

The original downloaded GitHub PEM is not deleted in Module 01. It remains the recovery copy until Module 02 verifies private access and then deletes it.

## Module 02 Flow

### Shared variable restoration

Module 02 must no longer generate a new `SUFFIX` or derive a new Key Vault. Its first step restores the saved Module 01 values:

- `SUFFIX`
- `RG`
- actual `KEY_VAULT`
- `KEY_VAULT_BOOTSTRAP_CIDR`
- `KEY_VAULT_BOOTSTRAP_PRINCIPAL_ID`

All remaining resource names continue to derive from `SUFFIX`. Module 02 verifies that the Resource Group and Key Vault already exist before creating additional resources.

### Resource Group handling

The current Resource Group creation moves to Module 01. Module 02 section 2 becomes Resource Group verification plus Log Analytics workspace creation.

### Key Vault private networking and runtime access

The former Module 02 section 8 keeps only operations that depend on Module 02 resources:

1. Create the Key Vault Private Endpoint in `PE_SUBNET_ID`.
2. Create and link `privatelink.vaultcore.azure.net`.
3. Assign the UAMI `Key Vault Secrets User` at Key Vault scope.
4. Disable Key Vault public network access.
5. Remove the temporary `Key Vault Secrets Officer` assignment using the saved principal ID, role name, and Key Vault scope instead of relying on an in-memory role assignment ID.
6. Remove the saved workstation firewall CIDR.
7. Set `KEY_VAULT_SECRET_URI`.
8. Verify public access, Private Endpoint approval, private DNS, and UAMI RBAC.

The final local subsection deletes the original GitHub App PEM only after these checks pass.

## Security Invariants

- The original GitHub App PEM never enters Cloud Shell.
- PEM content is never printed or stored in a shell command argument.
- Module 01 uploads with `az keyvault secret set --file`.
- Module 01 step 8 uses a protected temporary file and removes it on every exit path.
- App JWT and Key Vault secret content are never printed.
- Key Vault bootstrap access is limited to one workstation CIDR and one temporary user role.
- Module 02 removes both bootstrap grants after Private Endpoint validation.
- The original PEM is retained only until the private Key Vault path is proven operational.

## Error Handling

- Missing commands, invalid numeric IDs, missing PEM files, Azure login failures, secret upload/download failures, JWT signing failures, and GitHub API failures stop the current step with an explicit error.
- A `403` during Module 01 upload or download points participants to RBAC propagation and workstation CIDR checks.
- A GitHub `401` or `404` in step 8 points participants to App ID, Installation ID, and PEM mismatch checks.
- Key Vault name collisions are resolved in Module 01, and the actual name is carried into Module 02.
- Module 02 refuses to continue if its restored Resource Group or Key Vault does not exist.

## Documentation and Test Changes

- Update Module 01 goals and completion criteria to include Key Vault creation, PEM upload, and stored-secret authentication.
- Update Module 02 goals and introductory text to state that it reuses and hardens the Module 01 Key Vault.
- Move Key Vault creation/upload troubleshooting from Module 02 to Module 01.
- Keep Private Endpoint, UAMI, and public-access-lock troubleshooting in Module 02.
- Update the README module table from 20/40 minutes to 30/30 minutes for Modules 01/02.
- Update documentation contracts so:
  - Key Vault creation and `secret set --file` occur in Module 01 only;
  - Key Vault secret download and GitHub App installation authentication occur in Module 01 step 8;
  - Key Vault Private Endpoint, DNS, UAMI RBAC, and public access disablement remain in Module 02;
  - Module 02 restores Module 01 values instead of generating a new `SUFFIX`;
  - the total execution Bash block count remains consistent.

## Out of Scope

- Moving VNet, Private Endpoint subnet, or UAMI creation into Module 01.
- Uploading the GitHub App PEM to Cloud Shell.
- Deleting the original PEM before Module 02 private-access validation.
- Changing the runner's Key Vault secret reference or GitHub App token exchange behavior.
