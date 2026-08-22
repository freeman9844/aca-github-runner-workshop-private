# ACA Service Endpoint Foundation Design

## Context

Module 02 currently creates a dedicated Private Endpoint subnet, Blob and Key
Vault Private Endpoints, two Private DNS zones, VNet links, zone groups, and
private DNS validation. This provides strong Private Link isolation, but the
number of networking concepts and commands makes the workshop difficult for
first-time participants.

The revised workshop prioritizes a simpler, repeatable learning path. Storage
and Key Vault will remain restricted to the Azure Container Apps (ACA)
infrastructure subnet by using virtual network service endpoints and resource
firewall rules.

## Goals

- Remove Private Endpoint and Private DNS creation from the workshop.
- Use one delegated ACA infrastructure subnet for the required data-plane
  network boundary.
- Allow Storage and Key Vault data-plane traffic only from the ACA subnet.
- Preserve managed identity authentication and least-privilege Azure RBAC.
- Reduce Module 02 to seven required Cloud Shell steps.
- Keep runtime validation for Key Vault secret references and Blob access.

## Non-goals

- Provide Private Link or private-IP-only connectivity.
- Make Storage or Key Vault data planes available from Azure Cloud Shell after
  their firewalls are locked.
- Add NAT Gateway, Azure Firewall, Network Security Perimeter, or service
  endpoint policies.
- Provide an automated in-place migration from an older workshop deployment
  that already contains Private Endpoints and Private DNS zones.
- Change the external ACA Environment, ACR authentication, GitHub App, KEDA,
  or runner trust model.

## Architecture

The custom VNet contains only `snet-aca-infra`, delegated to
`Microsoft.App/environments`. The subnet enables these service endpoints:

- `Microsoft.Storage`
- `Microsoft.KeyVault`

Storage and Key Vault retain their public service endpoints because classic
virtual network service endpoints use those endpoints. Both resources use:

- `publicNetworkAccess=Enabled`
- firewall `defaultAction=Deny`
- firewall `bypass=None`
- one virtual network rule for `snet-aca-infra`

DNS continues to resolve the standard Storage and Key Vault host names to
public service IP addresses. Traffic originating from the ACA subnet uses the
service endpoint route over the Azure backbone, and the destination resource
firewall recognizes the subnet identity. Requests still require managed
identity authentication and the correct Azure RBAC role.

The dedicated Private Endpoint subnet, Private Endpoint resources, Private DNS
zones, VNet links, zone groups, and all related variables are removed.

## Identity and Data Flow

One user-assigned managed identity remains attached to the ACA Job and receives
only these resource-scoped roles:

- `AcrPull` on the Azure Container Registry
- `Storage Blob Data Contributor` on the Storage account
- `Key Vault Secrets User` on the Key Vault

The runtime flows are:

1. ACA pulls the runner image from ACR by using the managed identity.
2. The ACA Job resolves the standard Key Vault host name and retrieves the
   GitHub App private key reference through the Key Vault service endpoint.
3. The runner resolves the standard Blob host name and uploads or downloads
   artifacts through the Storage service endpoint.
4. Key Vault and Storage firewalls reject equivalent data-plane requests that
   do not originate from the allowed ACA subnet.

Module 01 continues to create the Key Vault and upload the GitHub App PEM before
Module 02 restricts the vault network. Module 02 removes the bootstrap
`Key Vault Secrets Officer` assignment only after the ACA subnet rule and
runtime managed identity role are configured and verified.

## Module 02 Step Structure

### Step 1: Restore Module 01 variables

Keep the existing Resource Group lookup and actual Key Vault name restoration.
Remove all Private Endpoint and Private DNS variable definitions.

### Step 2: Confirm the Resource Group and create Log Analytics

No architectural change.

### Step 3: Create the VNet and ACA subnet

Create only `snet-aca-infra`, delegate it to
`Microsoft.App/environments`, and enable `Microsoft.Storage` and
`Microsoft.KeyVault` service endpoints. Save `VNET_ID` and `SUBNET_ID`.

### Step 4: Create the external custom VNet ACA Environment

No behavioral change. Continue to use `SUBNET_ID`.

### Step 5: Create ACR

No behavioral change. ACR remains reachable through the existing public
outbound path and uses ARM authentication with `AcrPull`.

### Step 6: Create and restrict Storage

Create the Storage account with shared key and public Blob access disabled.
Create the Blob container through the management plane. Add the ACA subnet
network rule and enforce:

- `publicNetworkAccess=Enabled`
- `defaultAction=Deny`
- `bypass=None`

Validate the Storage firewall rule and the subnet's Storage service endpoint.
Do not create a Private Endpoint or any Private DNS resource.

### Step 7: Create the UAMI and complete runtime access

Create the user-assigned managed identity and assign all three resource-scoped
roles. Add the ACA subnet rule to the existing Key Vault and enforce:

- `publicNetworkAccess=Enabled`
- `defaultAction=Deny`
- `bypass=None`

Set `KEY_VAULT_SECRET_URI`, validate both resource network rules and all three
role assignments, then delete the bootstrap `Key Vault Secrets Officer`
assignment.

Module 02 has no numbered Step 8. The local original PEM deletion remains a
short, unnumbered optional security-cleanup note at the end of the module.

## Workshop-Wide Documentation Changes

- `README.md`: replace Private Endpoint and Private DNS architecture,
  objectives, module summary, cost, and security wording with the service
  endpoint model.
- `docs/02-azure-foundation.md`: implement the seven-step structure and remove
  all Private Endpoint and Private DNS commands, variables, expected output,
  troubleshooting, and resource-list references.
- `docs/04-event-job-keda.md`: describe Key Vault access as an ACA subnet
  service endpoint plus firewall and RBAC path.
- `docs/05-parallel-scale-validation.md`: remove Private Endpoint and Private
  DNS restoration and diagnostics.
- `docs/06-azure-sample-deployment.md`: replace private-IP DNS validation with
  service endpoint and subnet-rule validation while retaining Blob
  upload/download and checksum runtime evidence.
- `docs/07-security-limitations-cleanup.md`: describe the lower isolation level,
  retained public service endpoints, ACA-subnet-only firewall policy, revised
  cost model, and simplified cleanup.
- `samples/azure-sample-deploy-workflow.yml`: remove Private DNS and Private
  Endpoint checks and retain the authenticated Blob data-plane test.
- Remove the Module 02 Portal resource-list image because it shows resources
  that no longer exist. Keep a text-only resource checklist unless a current
  replacement image is supplied.

## Error Handling and Troubleshooting

- A Cloud Shell `403` from the Storage or Key Vault data plane after Step 6 or
  Step 7 is expected because Cloud Shell is outside `snet-aca-infra`.
- Control-plane commands such as resource inspection, RBAC listing, and
  management-plane Blob container creation remain the documented Cloud Shell
  validation path.
- If the ACA Job cannot resolve or reach Storage or Key Vault, verify the
  subnet service endpoint first, then the destination virtual network rule,
  then `defaultAction`, `bypass`, and `publicNetworkAccess`.
- If the network configuration is correct but access is denied, verify the
  managed identity assignment and the resource-scoped RBAC role.
- Key Vault reference synchronization in Module 04 is the runtime proof for
  Key Vault access.
- Blob upload, download, and checksum validation in Module 06 is the runtime
  proof for Storage access.
- Participants who previously completed the Private Endpoint version should
  clean up that deployment and start with a fresh workshop suffix. The revised
  module does not silently reuse old Private DNS links or Private Endpoints.

## Testing

Update the shell documentation tests to require:

- both service endpoints on `snet-aca-infra`
- Storage and Key Vault virtual network rules for `SUBNET_ID`
- `publicNetworkAccess=Enabled`, `defaultAction=Deny`, and `bypass=None`
- all three resource-scoped managed identity roles
- seven numbered Module 02 steps and no numbered Step 8
- updated Module 04 and Module 06 runtime validation wording

Tests must reject remaining operational references to:

- `snet-private-endpoints`
- `az network private-endpoint`
- `az network private-dns`
- `privatelink.blob.core.windows.net`
- `privatelink.vaultcore.azure.net`
- Private Endpoint and Private DNS variables

Run the targeted documentation tests followed by `tests/validate-workshop.sh`.
The repository tests validate curriculum consistency and command contracts;
the Module 04 and Module 06 participant runs provide live Azure data-plane
validation.

## Acceptance Criteria

- A new participant can complete Module 02 with one VNet subnet and seven
  numbered steps.
- Module 02 creates no Private Endpoint or Private DNS resource.
- Storage and Key Vault accept data-plane access from the ACA subnet and deny
  unlisted networks.
- Key Vault secret references work from the ACA Job with
  `Key Vault Secrets User`.
- The ACA runner can upload and download Blob artifacts with
  `Storage Blob Data Contributor`.
- README, all affected modules, the sample workflow, and tests describe the
  same service endpoint architecture without stale Private Link instructions.
