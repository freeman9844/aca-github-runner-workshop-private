# Workshop Redundancy Cleanup Design

## 목적

README와 Module 01~07의 실행 흐름을 유지하면서, 같은 정보를 반복하는 범례·복구 변수·workflow 원문을 제거해 초보자가 실제 수행 단계에 집중할 수 있도록 한다.

## 정리 원칙

- 실행 결과, 보안 경고, 트러블슈팅, service endpoint/firewall/RBAC 검증은 유지한다.
- 한 단계에서 이미 출력하는 checked-in sample은 같은 문서에 다시 전체 수록하지 않는다.
- 세션 복구 블록은 해당 모듈에서 실제 사용하는 변수만 복원한다.
- 보안 경계 이해에 필요한 Module 03 Dockerfile과 entrypoint 전체 disclosure는 유지한다.
- README의 태그 범례를 유일한 공통 범례로 사용한다.

## 변경 범위

### 공통 태그 범례

README의 `## 태깅 범례`는 유지한다. Module 01~07의 `## 태그 범례` 제목과 네 행짜리 반복 표는 모두 삭제한다.

### Module 03

세션 복구 블록을 image build에 필요한 값으로 축소한다.

- 입력: `SUFFIX`, 실제 `ACR`
- 파생: `RG`, `IMAGE`
- Azure 조회: `ACR_SERVER`, `ACR_ID`
- 제거: Storage, Key Vault, Log Analytics, ACA Environment, VNet, subnet, UAMI, subscription, Resource Group ID 조회와 export

`runner/Dockerfile`과 `runner/entrypoint.sh` 전체 disclosure 및 byte-match 검증은 유지한다.

### Module 05

세션 복구 블록을 scale과 로그 조회에 필요한 값으로 축소한다.

- 입력: `SUFFIX`
- 파생: `RG`, `LOG`, `JOB`
- Azure 조회: `LOG_ID`
- 제거: ACR, Storage, Key Vault, subnet, GitHub App 식별자 복구와 출력

Step 1에서 `samples/parallel-runner-workflow.yml` 전체를 출력하고 GitHub 웹 UI에 반영하므로, 같은 YAML을 다시 수록하는 Step 2는 삭제한다. 기존 Step 3~9는 Step 2~8로 재번호화한다.

### Module 06

세션 복구 블록을 Blob 검증에 필요한 값으로 축소한다.

- 입력: `SUFFIX`, 원래 workshop subscription ID
- 파생: `RG`, `VNET`, `INFRA_SUBNET`, 기본 Storage 이름, container 이름, UAMI 이름
- 선택 입력: 이름 충돌 복구가 있었던 실제 Storage 이름
- Azure 조회: `STORAGE_ID`, `UAMI_PID`, `UAMI_CLIENT_ID`, `SUBNET_ID`
- 제거: ACR, Key Vault, secret URI, ACA Environment 관련 복구

Step 2의 `sed` 명령이 `samples/azure-sample-deploy-workflow.yml` 전체를 출력하므로 접힌 workflow 전체 disclosure는 삭제한다. 다음 설명은 유지한다.

- GitHub App bootstrap variable leak guard
- job-level `${{ runner.temp }}` 금지
- `$RUNNER_TEMP`와 `$GITHUB_ENV`를 통한 writable Azure CLI configuration
- trusted workflow author 경계

## 테스트 변경

- 각 문서 테스트에서 삭제된 태그 범례가 다시 생기지 않도록 검사한다.
- Module 03 복구 테스트는 축소된 변수 계약을 검증하고 제거된 조회가 없는지 확인한다.
- Module 05 테스트는 중복 YAML 단계 부재, Step 1~8 순서, 축소된 복구 계약을 검증한다.
- Module 06 테스트는 workflow disclosure byte-match 요구를 제거하고 sample 출력·핵심 설명·축소된 복구 계약을 검증한다.
- 실행 Bash 블록 총개수 기준을 실제 문서 구조에 맞춘다.
- 전체 `tests/validate-workshop.sh`와 `git diff --check`를 통과해야 한다.

## 비목표

- 워크숍 아키텍처, Azure 리소스 구성, GitHub App 인증, runner image, workflow 동작은 변경하지 않는다.
- Module 04 Event Job 생성 명령, Module 05 KQL 대기 로직, Module 06 Blob 검증 workflow는 변경하지 않는다.
- 보안 경고를 중앙 문서로만 옮겨 실행 단계에서 제거하지 않는다.
- 예상 시간 150분은 변경하지 않는다.
