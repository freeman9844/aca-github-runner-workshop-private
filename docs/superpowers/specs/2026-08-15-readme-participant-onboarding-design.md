# README Participant Onboarding Enhancement Design

## Goal

Make the repository README a reliable starting point for a first-time
participant by clearly explaining what to prepare, which repository is used
for each purpose, how to begin, what must be saved between sessions, and how
to know the workshop is complete.

## Audience and Scope

The primary audience is a participant opening the workshop repository for the
first time. The README remains an overview and navigation document; detailed
commands, expected outputs, and remediation procedures stay in Modules 01
through 06.

Keep the current README structure and visual elements. Add focused participant
onboarding sections and strengthen existing summaries rather than rewriting
the entire document.

## Quick Start

Add `## 빠른 시작` near the beginning, after the introductory paragraph and
before the architecture section.

The section will give the minimum path:

1. Open Azure Cloud Shell Bash.
2. Confirm HTTPS Git authentication for the private workshop source repository.
3. Clone the source repository to
   `~/aca-github-runner-workshop`.
4. Change to that directory.
5. Open Module 01 and continue modules in order.

Use the exact clone command documented in Module 01:

```bash
git clone https://github.com/jungwoonlee_microsoft/aca-github-runner-workshop-private.git ~/aca-github-runner-workshop
cd ~/aca-github-runner-workshop
```

The README must not duplicate the full Module 01 setup commands.

## Repository Roles

Add `## 두 GitHub 저장소 구분` with a concise table:

| Repository | Purpose | Created by | Used for |
|---|---|---|---|
| `aca-github-runner-workshop-private` | Workshop documents, runner source, samples, and tests | Workshop maintainer | Clone and read/build source |
| `aca-runner-lab` | Participant-owned private lab repository | Participant in Module 01 | Workflow queue, KEDA monitoring, ephemeral runner registration |

State explicitly that the Fine-grained PAT is scoped to `aca-runner-lab`, not
the workshop source repository.

## Prerequisite Checklist

Retain the current prerequisite table and clarify these start conditions:

- The participant can authenticate over HTTPS to clone the private workshop
  source repository.
- The participant can create or use a private `aca-runner-lab` repository.
- Enterprise Managed User and organization policies may require approval for
  a Fine-grained PAT.
- Azure resource creation access and
  `Microsoft.Authorization/roleAssignments/write` are separate requirements.

Keep the Private repository and Docker-in-Docker warnings.

## Module Journey

Keep the existing module table and timing. Strengthen each module summary so
it identifies the main output passed to the next module:

- Module 01: private lab repository and validated GitHub variables/PAT.
- Module 02: resource names, saved `SUFFIX`, actual `ACR` name, and Azure IDs.
- Module 03: built runner image in ACR.
- Module 04: repository-scoped ACA Event Job and KEDA rule.
- Module 05: matrix run and `0 → N → 0` evidence.
- Module 06: security review and confirmed cleanup.

Do not change the 90-minute total unless module timings change.

## Session Recovery

Add `## 세션이 끊겼을 때` after the module journey or timetable.

Explain:

- Cloud Shell variables do not persist across a new session.
- Participants must retain the original `SUFFIX` and the actual `ACR` name.
- Modules 03 through 06 expose
  `0. 세션 재연결 시 변수 복구 (선택)`.
- The recovery details are collapsed and can be expanded only when needed.
- A new suffix must not be generated when continuing an existing workshop.

## Completion Criteria

Add `## 완료 기준` with an actionable checklist:

- The runner image tag exists in ACR.
- The ACA Event Job uses the expected image and repository-scoped KEDA rule.
- Four matrix jobs complete successfully.
- Active executions return from `0` to `N` and back to `0`.
- Runner lifecycle markers appear in CLI or Log Analytics.
- No permanent online ephemeral runner remains in GitHub.
- The Azure resource group reaches `ResourceGroupNotFound` after cleanup.
- The lab Fine-grained PAT and GitHub lab artifacts are cleaned up as directed.

## Validation Scope

Rewrite the current long validation paragraph as a concise participant-facing
`검증된 범위와 남은 전제` note.

Preserve these facts:

- Checked-in validators cover document contracts and script interfaces.
- Live execution verified `koreacentral`, runner `2.336.0`, matrix four jobs,
  image pull, `0 → 4 → 0`, runner shutdown, Log Analytics collection, and
  resource-group deletion.
- Fine-grained PAT organization approval and minimum-permission behavior still
  depend on the participant's GitHub enterprise/organization policy.

Remove implementation-history phrasing about using an existing GitHub OAuth
credential because it does not help a participant execute the current path.

## Troubleshooting Index

Keep the existing index and add direct entries for:

- Workshop source clone authentication or incorrect clone path → Module 01.
- Empty, expired, or unapproved PAT / GitHub 401 or 403 → Module 01.
- ACR global-name collision → Module 02.
- Duplicate Event Job queue watcher → Module 04.
- Event Job secret or PAT failure → Module 04.
- Existing scale, logs, runner cleanup, and Azure deletion entries remain.

All links must target an existing `## 트러블슈팅` anchor.

## Testing

Update `tests/docs/test-overview.sh` to require:

- `## 빠른 시작`
- `## 두 GitHub 저장소 구분`
- `## 세션이 끊겼을 때`
- `## 완료 기준`
- The exact source clone destination.
- Both repository names and their distinct purposes.
- The saved `SUFFIX` and actual `ACR` recovery guidance.
- Completion markers including four matrix jobs, `0 → N → 0`,
  lifecycle logs, permanent runner absence, and `ResourceGroupNotFound`.
- New troubleshooting index entries.
- The concise validation scope and policy-dependent PAT statement.

The test must reject:

- Guidance that scopes the Fine-grained PAT to the workshop source repository.
- A clone destination ending in
  `~/aca-github-runner-workshop-private`.
- The old phrase `기존 GitHub OAuth credential`.
- Reintroduction of GitHub App setup as the workshop authentication path.

Run the focused README contract followed by the complete workshop validators
and shell syntax check.

## Repository Hygiene

The repository policy ignores `docs/superpowers/` and requires it to remain
untracked in the final implementation state. The implementation may use this
local design as planning input, but the final README change must not re-track
internal design or plan documents.

## Non-Goals

- Do not change module commands or behavior.
- Do not change the architecture diagram's topology.
- Do not add operator-only facilitation notes.
- Do not add fixed Azure price estimates.
- Do not add a second README or duplicate module documentation.
