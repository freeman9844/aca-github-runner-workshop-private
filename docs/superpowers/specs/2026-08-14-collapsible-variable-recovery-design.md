# Collapsible Variable Recovery Sections Design

## Goal

Make session variable recovery visibly optional and less disruptive by
standardizing the existing recovery content in Modules 03 through 06 as a
collapsed Step 0.

## Scope

- Modify only Modules 03, 04, 05, and 06, which already contain session
  variable recovery instructions.
- Do not add recovery sections to Modules 01 or 02.
- Preserve the existing recovery commands, resource-name derivation, PAT
  non-echoing input, expected output, and safety guidance.

## Common Presentation

Each affected module will use this visible top-level heading:

```markdown
## 0. 세션 재연결 시 변수 복구 (선택)
```

The explanatory text, commands, expected output, and warnings will be hidden
by default inside one GitHub-rendered disclosure block:

```markdown
<details>
<summary>세션이 끊겼다면 변수 복구 명령 보기</summary>

</details>
```

The heading remains outside the disclosure block so participants can see that
Step 0 exists and is optional without expanding it. The first required
workshop action in each module starts at Step 1.

## Module Changes

### Module 03

- Rename the current Azure variable recovery Step 1 to the common Step 0.
- Wrap its full body in the common disclosure block.
- Renumber the current Steps 2 through 5 to Steps 1 through 4.
- Keep the saved `SUFFIX` and actual `ACR` recovery behavior unchanged.

### Module 04

- Combine the current Azure recovery Step 1 and Fine-grained PAT reload Step 2
  into one common Step 0 disclosure block.
- Keep two clear subsections inside the disclosure body:
  - Azure resource variables
  - GitHub owner, repository, and Fine-grained PAT variables
- Preserve non-echoing PAT input and the `GITHUB_PAT=SET` output behavior.
- Renumber the current Steps 3 through 5 to Steps 1 through 3.

### Module 05

- Keep the existing Step 0 position and optional meaning.
- Standardize its heading and wrap its full body in the common disclosure
  block.
- Leave Steps 1 through 11 unchanged.

### Module 06

- Rename the current cleanup-specific Step 0 to the common Step 0 heading.
- Wrap its full body in the common disclosure block.
- Preserve the warning that the original suffix must identify the exact
  cleanup target.
- Leave Steps 1 through 6 unchanged.

## Markdown and Rendering Requirements

- Use HTML `<details>` and `<summary>` because GitHub Markdown supports native
  click-to-expand disclosure blocks.
- Include blank lines after `<summary>` and before `</details>` so Markdown
  paragraphs, lists, and fenced code blocks render correctly.
- Use exactly one disclosure block per affected module.
- Do not place required non-recovery actions inside a collapsed block.

## Tests

Update the existing documentation contract tests to verify:

- Modules 03 through 06 each contain the exact common Step 0 heading.
- Each affected module contains the common `<details>` and `<summary>` markers.
- The previous recovery headings are absent.
- Module 03 required steps are consecutively numbered 1 through 4.
- Module 04 required steps are consecutively numbered 1 through 3.
- Module 04 retains both Azure and GitHub/PAT recovery commands inside Step 0.
- Existing safety-sensitive recovery commands and PAT non-disclosure markers
  remain present.

Run the focused documentation tests followed by the complete workshop
validators and shell syntax check.

## Non-Goals

- No changes to resource creation, image build, Event Job, scale validation,
  or cleanup behavior.
- No new persistent variable storage mechanism.
- No changes to Module 01 PAT creation or Module 02 initial variable creation.
- No JavaScript or custom UI is added for disclosure behavior.
