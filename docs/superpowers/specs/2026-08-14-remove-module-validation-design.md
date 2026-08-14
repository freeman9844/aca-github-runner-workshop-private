# Module Validation Section Removal Design

## Goal

Reduce workshop repetition by removing standalone end-of-module validation
and completion-summary sections while preserving checks that prevent unsafe or
incorrect workshop execution.

## Scope

### Remove

- Module 01: the final summary-only `## 8. 검증` section.
- Module 02: the standalone `## 6. 검증` section.
- Module 03: the standalone image and ACR validation section.
- Module 04: the standalone Job status validation section.
- Module 06: the final whole-workshop completion summary table.

### Preserve

- Module 01 repository, Actions, and runner-administration permission checks.
- Module 04 duplicate queue-watcher and existing Job checks.
- Module 05 in full because scale validation is the module's learning objective.
- Module 06 resource-group deletion completion and GitHub cleanup checks.
- Troubleshooting guidance that depends on observable runtime state.

## Content Restructuring

- Move ACR security, ARM authentication, and `AcrPull` checks from Module 02's
  standalone validation section into the related ACR and identity creation
  steps.
- Move image tag and ACR administrator-account checks from Module 03's
  standalone validation section into the ACR build step.
- Move the concise Job configuration and initial execution checks from Module
  04's standalone validation section into the Job creation step.
- Renumber later headings after removed sections where required.
- Remove duplicated expected-output summaries that repeat results already
  described beside their creation commands.

## Test Contract

- Documentation tests must reject reintroduction of the removed standalone
  validation or completion headings.
- Tests must continue requiring the safety-critical commands that were moved
  into earlier operational steps.
- The complete workshop validator and integrated validator must remain green.
- Navigation links and troubleshooting anchors must remain unchanged.

## Non-Goals

- Do not remove module-level expected outputs that directly help participants
  identify command failure.
- Do not simplify Module 05's `0 -> N -> 0` runtime validation.
- Do not remove PAT permission verification or cleanup completion checks.
- Do not change Azure, GitHub, KEDA, runner, or security behavior.
