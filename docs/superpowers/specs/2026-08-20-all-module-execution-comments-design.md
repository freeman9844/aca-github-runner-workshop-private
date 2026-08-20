# 전체 모듈 실행 블록 한글 주석 설계

## 상태

사용자 승인 설계. 구현 전 문서 검토 대기.

## 배경

Module 02의 `🟢 실행` Bash 블록은 명령 그룹마다 한글 주석이 있어 참가자가 명령의 목적과 다음 단계에서의 사용처를 코드 안에서 바로 이해할 수 있다. 다른 모듈은 본문 설명은 충분하지만 실행 블록의 주석 수준이 일정하지 않다. 특히 세션 복구, 권한 확인, 로그 조회, cleanup처럼 여러 명령이 이어지는 블록은 참가자가 명령 간 관계를 다시 본문과 대조해야 한다.

현재 문서에는 `🟢 실행` 표시 43개와 그중 Bash 블록 36개가 있다. Module 02의 Bash 블록 6개는 모두 주석으로 시작하며 총 26개의 그룹 주석을 포함한다. 나머지 모듈의 Bash 블록 30개 중 29개는 주석으로 시작하지 않는다. Module 04의 Event Job 인자 배열에는 이미 16개의 내부 그룹 주석이 있으므로 이를 유지하고 부족한 블록 시작·주변 그룹 설명만 보강한다.

## 목표

- Module 01·03·04·05·06·07의 모든 `🟢 실행` Bash 블록을 한글 목적 주석으로 시작한다.
- 하나의 블록에 여러 작업이 있으면 변수 입력, 리소스 조회, 생성·변경, 권한 확인, 결과 검증, 보안 정리 같은 논리적 그룹마다 1~2줄 주석을 둔다.
- 참가자가 본문을 왕복하지 않아도 각 명령 그룹을 실행하는 이유와 다음 사용처를 이해할 수 있게 한다.
- Module 02에서 사용한 짧고 목적 중심인 주석 스타일을 전체 워크숍에 일관되게 적용한다.
- 기존 명령, 변수, 실행 순서, 예상 출력과 보안 경계를 그대로 유지한다.

## 비목표

- UI에서 수행하는 `🟢 실행` 단계에 Bash 코드나 가상 명령을 추가하지 않는다.
- `📋 예상 출력`, troubleshooting, 샘플 source, workflow YAML의 내용을 이 작업 때문에 변경하지 않는다.
- 명령 옵션을 한글로 그대로 다시 읽어 주는 장황한 주석을 추가하지 않는다.
- 기존 인증, 네트워크, RBAC, runner lifecycle 또는 cleanup 동작을 변경하지 않는다.
- Module 02의 이미 충족된 주석을 재작성하지 않는다.

## 범위

| 모듈 | 대상 Bash 블록 | 주요 주석 그룹 |
|---|---:|---|
| Module 01 | 5 | subscription 선택, CLI/provider 준비, source clone, PAT 입력, GitHub API 권한 확인 |
| Module 03 | 4 | 세션 변수 복구, 정적 검사, ACR build, image tag·ACR 보안 검증 |
| Module 04 | 5 | Azure·GitHub 변수 복구, 중복 watcher 검사, Event Job 생성, 배포 결과 확인 |
| Module 05 | 8 | 세션 복구, workflow 확인, baseline·scale-out·로그·scale-in 검증 |
| Module 06 | 5 | subscription 복구, RBAC 조회·부여·전파 확인, workflow source 확인, internal ingress 검증 |
| Module 07 | 3 | cleanup 대상 복구, Resource Group 삭제 요청, 삭제 완료 확인 |

Module 02의 6개 Bash 블록은 기준 구현으로 사용하고 수정하지 않는다.

## 주석 작성 규칙

1. 각 대상 Bash 블록의 첫 번째 비어 있지 않은 줄은 `# `로 시작하는 한글 주석이어야 한다.
2. 주석은 “무엇을 입력하는가”보다 “왜 실행하며 결과를 어디에 쓰는가”를 설명한다.
3. 빈 줄로 나뉜 명령 묶음이 서로 다른 목적을 가지면 각 묶음 앞에 주석을 둔다.
4. 긴 복구 블록은 다음 순서를 기준으로 그룹화한다.
   - 저장 값 입력
   - 이름 변수 복원
   - Azure resource ID·client ID 조회
   - 이후 모듈에 필요한 값 출력 또는 export
5. 조회·검증 블록은 조회 대상과 성공 기준을 주석에 포함한다.
6. 보안 관련 블록은 PAT 비출력, 최소 RBAC scope, secret 제거처럼 참가자가 지켜야 할 경계를 설명한다.
7. 기존에 정확한 주석이 있으면 유지하고 중복 설명을 추가하지 않는다.
8. 영문 제품명과 변수명은 기존 문서 표기를 유지하고, 나머지 설명은 자연스러운 한글로 작성한다.

## 문서별 적용

### Module 01

- subscription 목록 조회, 사용자 선택, active subscription 확인을 분리한다.
- extension 설치와 각 provider 등록 목적을 묶어 설명한다.
- public workshop source clone과 고정 작업 경로 이동을 설명한다.
- PAT를 shell-local로 읽고 비어 있는 값을 재입력받는 이유를 설명한다.
- repository, Actions, runner administration API를 최소 권한 순서로 검증하고 임시 header를 제거하는 이유를 설명한다.

### Module 03

- 저장한 `SUFFIX`와 실제 ACR 이름을 복원하는 이유를 강조한다.
- 조회형 Azure 변수의 사용처와 export 범위를 묶어 설명한다.
- 문법 검사, entrypoint 동작 테스트, artifact parity 검사를 구분한다.
- ACR Tasks build와 tag·관리자 계정·ARM authentication 검증을 구분한다.

### Module 04

- Azure 변수 복구와 GitHub PAT 입력 블록을 각각 설명한다.
- 같은 repository와 label을 감시하는 Job을 먼저 찾는 이유를 명시한다.
- `JOB_CREATE_ARGS` 내부의 기존 주석은 유지하고 배열 생성, create 실행, PAT 제거를 연결한다.
- 생성된 Event Job의 trigger, scaler metadata, image와 초기 execution 상태를 확인하는 목적을 설명한다.

### Module 05

- workflow source 확인, baseline 0, scale-out 관찰, 최신 execution 선택, CLI 로그 조회, Log Analytics 수집 대기, scale-in 0 확인을 각각 설명한다.
- 기존 조건 기반 Log Analytics 대기 주석을 유지하고 상세 query와 `$EXECUTION` 연계를 보강한다.
- 실행마다 달라지는 execution 이름을 고정값으로 오해하지 않도록 조회 목적을 명시한다.

### Module 06

- 저장한 subscription을 먼저 복원해야 identity 조회가 올바른 구독에서 동작함을 설명한다.
- environment 존재 확인, UAMI principal 조회, 현재 role 조회를 구분한다.
- role이 없을 때만 생성하고 전파를 조건 기반으로 기다리는 이유를 설명한다.
- workflow source를 웹 UI에 복사하기 전에 reviewed sample을 확인하는 목적을 설명한다.
- environment, subnet, ingress, Private DNS와 Cloud Shell 접근 실패를 함께 검증하는 이유를 설명한다.

### Module 07

- 저장한 suffix에서 cleanup 대상 Resource Group만 복원함을 설명한다.
- 비동기 Resource Group 삭제를 요청하고 즉시 완료로 간주하지 않음을 설명한다.
- `ResourceGroupNotFound`와 빈 resource 목록으로 삭제 완료를 확인하는 목적을 설명한다.

## 검증 전략

1. 문서 구조 테스트를 먼저 추가해 모든 `🟢 실행` Bash 블록이 한글 주석으로 시작하도록 요구하고, 현재 문서에서 실패하는 것을 확인한다.
2. 각 모듈의 기존 문서 테스트를 유지해 명령, 변수, 보안 문구와 예상 출력이 바뀌지 않았음을 확인한다.
3. 모듈별 변경 후 해당 targeted test를 실행한다.
4. 전체 `tests/test-validate-workshop.sh`를 실행한다.
5. `git diff --check`와 최종 diff review로 명령 줄 변경이 없는지 확인한다.
6. 자동 검사는 블록 시작 주석의 구조적 일관성을 보장하고, 논리적 그룹별 주석 충족 여부는 설계 범위 표를 기준으로 사람 review에서 확인한다. 정확한 문구나 주석 개수를 테스트에 고정하지 않는다.

## 위험과 완화

- **명령이 우연히 변경될 위험:** 주석만 추가하고 기존 module contract test와 diff review로 확인한다.
- **주석이 지나치게 장황해질 위험:** 그룹당 1~2줄로 제한하고 옵션 재진술을 피한다.
- **기존 주석과 중복될 위험:** Module 02와 Module 04의 기존 그룹 주석을 기준으로 재사용하고 중복 문구를 추가하지 않는다.
- **Markdown code block 구조가 깨질 위험:** fence와 disclosure 구조를 변경하지 않고 기존 문서 구조 테스트를 실행한다.
- **보안 설명이 약화될 위험:** PAT, RBAC, secret cleanup 관련 기존 문장을 삭제하지 않으며 주석은 기존 경계를 강화하는 방향으로만 추가한다.

## 완료 기준

- Module 01·03·04·05·06·07의 대상 Bash 블록 30개가 모두 한글 주석으로 시작한다.
- 각 범위 표의 논리적 명령 그룹에 목적 주석이 있다.
- Module 02의 기존 명령과 주석은 변경되지 않는다.
- 문서 외 source, workflow, 실행 동작에는 변경이 없다.
- targeted tests, 전체 validator와 diff 검사가 통과한다.
