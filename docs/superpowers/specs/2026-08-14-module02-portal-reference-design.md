# Module 02 Azure Portal Reference Design

## Goal

Add an optional Azure Portal reference at the end of Module 02 so participants
can visually confirm the resources created by the Cloud Shell commands.

## Placement

- Insert an unnumbered section immediately before `## 트러블슈팅`.
- Use the heading:
  `## 참고: Azure 관리 포털에서 생성된 리소스 확인`
- Keep the section outside the numbered workshop execution flow.

## Content

- State that Azure Portal use is optional and Cloud Shell remains the primary
  workshop interface.
- Direct participants to:
  **Resource groups → `$RG` → Overview → Resources**
- State that the page shows the resources created in Module 02:
  - Azure Container Registry
  - Container Apps Environment
  - Managed Identity
  - Log Analytics workspace

## Image

- Copy the supplied screenshot to:
  `docs/images/02-azure-portal-resource-group-resources.png`
- Reference it with descriptive alternative text explaining that the resource
  group overview lists the four Module 02 resource types.
- Do not present the screenshot's sample suffix or resource names as values
  participants must reproduce.

## Test Contract

- `tests/docs/test-prerequisites-foundation.sh` requires the reference heading,
  optional-reference wording, portal navigation, four resource types, image
  link, and image file.
- The reference section must appear before `## 트러블슈팅`.
- Existing Module 02 safety checks and the removal of standalone validation
  sections remain unchanged.
