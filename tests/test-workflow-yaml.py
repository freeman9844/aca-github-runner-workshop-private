#!/usr/bin/env python3

from pathlib import Path
import os
import shutil
import subprocess

import yaml


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / "samples/azure-sample-deploy-workflow.yml"
SCRATCH = ROOT / ".workflow-yaml-test-scratch"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def load_workflow() -> dict:
    try:
        with WORKFLOW.open(encoding="utf-8") as stream:
            document = yaml.safe_load(stream)
    except FileNotFoundError:
        fail("samples/azure-sample-deploy-workflow.yml missing")
    if not isinstance(document, dict):
        fail("workflow must be a YAML mapping")
    return document


def get_step(steps: list[dict], name: str) -> dict:
    for step in steps:
        if isinstance(step, dict) and step.get("name") == name:
            return step
    fail(f"missing workflow step: {name}")
    raise AssertionError


def write_executable(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def run_script(script: str, *, env: dict[str, str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", "-c", script],
        cwd=cwd,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


def main() -> None:
    workflow_text = WORKFLOW.read_text(encoding="utf-8")
    for obsolete in (
        "AZURE_PRIVATE_ENDPOINT_CIDR",
        "privatelink.blob.core.windows.net",
        "Verify Blob DNS resolves to the private endpoint subnet",
    ):
        if obsolete in workflow_text:
            fail(f"workflow contains obsolete Private DNS contract: {obsolete}")

    document = load_workflow()
    try:
        deploy_workflow = document["jobs"]
        deploy_job = deploy_workflow["deploy-vnet-restricted-blob"]
        steps = deploy_job["steps"]
    except KeyError:
        fail("workflow must define jobs.deploy-vnet-restricted-blob")
    if not isinstance(deploy_job, dict):
        fail("deploy-vnet-restricted-blob job must be a mapping")
    if not isinstance(steps, list):
        fail("deploy-vnet-restricted-blob job must define steps")
    job_env = deploy_job.get("env")
    if isinstance(job_env, dict) and any(
        "runner.temp" in str(value) for value in job_env.values()
    ):
        fail("workflow must not use the unavailable runner context in job-level env")

    required_step_names = {
        "Validate runner inputs",
        "Sign in to Azure with managed identity",
        "Upload and download the VNet-restricted Blob artifact",
        "Show VNet-restricted deployment result",
    }
    actual_step_names = {
        step.get("name") for step in steps if isinstance(step, dict) and step.get("name")
    }
    missing_step_names = required_step_names - actual_step_names
    if missing_step_names:
        fail(f"missing step names: {', '.join(sorted(missing_step_names))}")

    signin_step = get_step(steps, "Sign in to Azure with managed identity")
    signin_script = signin_step.get("run")
    if not isinstance(signin_script, str):
        fail("sign-in step must contain a run script")
    if "az login --identity" not in signin_script:
        fail("sign-in step must use managed identity login")
    if 'export AZURE_CONFIG_DIR="${RUNNER_TEMP:?RUNNER_TEMP is required}/.azure"' not in signin_script:
        fail("sign-in step must derive Azure CLI config from the RUNNER_TEMP shell variable")
    if 'mkdir -p "$AZURE_CONFIG_DIR"' not in signin_script:
        fail("sign-in step must create the writable Azure CLI config directory")
    if 'printf \'AZURE_CONFIG_DIR=%s\\n\' "$AZURE_CONFIG_DIR" >> "$GITHUB_ENV"' not in signin_script:
        fail("sign-in step must persist AZURE_CONFIG_DIR for later workflow steps")

    for korean_comment in (
        "# GitHub Actions 화면에 표시할 workflow 이름입니다.",
        "# 수동 실행으로 VNet 제한 Blob 배포 검증을 시작합니다.",
        "# repository 내용은 읽기만 허용합니다.",
        "# non-root runner가 Azure CLI 설정을 기록할 임시 경로를 shell에서 구성합니다.",
        "# GitHub App bootstrap 값이 workflow 환경으로 노출되지 않았는지 확인합니다.",
        "# User-Assigned Managed Identity로 Azure에 로그인합니다.",
        "# VNet으로 제한된 Blob에 artifact를 업로드한 뒤 다시 내려받아 검증합니다.",
        "# 최종 Blob 속성과 checksum을 GitHub Actions 로그에 출력합니다.",
    ):
        if korean_comment not in workflow_text:
            fail(f"workflow missing Korean purpose comment: {korean_comment}")

    validate_script = get_step(steps, "Validate runner inputs").get("run")
    if not isinstance(validate_script, str):
        fail("validation step must contain a run script")

    blob_script = get_step(steps, "Upload and download the VNet-restricted Blob artifact").get("run")
    if not isinstance(blob_script, str):
        fail("blob step must contain a run script")

    if SCRATCH.exists():
        shutil.rmtree(SCRATCH)
    SCRATCH.mkdir(parents=True)
    try:
        bin_dir = SCRATCH / "bin"
        bin_dir.mkdir()
        calls_log = SCRATCH / "calls.log"
        sha_log = SCRATCH / "sha.log"

        write_executable(
            bin_dir / "az",
            r'''#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_CALLS"
if [[ "$1" == "login" || "$1 $2" == "account set" || "$1 $2" == "account show" ]]; then
  exit 0
fi
case "$1 $2 $3" in
  'storage blob upload'|'storage blob upload-batch')
    exit 0
    ;;
  'storage blob download')
    destination=""
    for ((i=1; i<=$#; i++)); do
      arg="${!i}"
      if [[ "$arg" == '--file' || "$arg" == '-f' ]]; then
        next_index=$((i + 1))
        destination="${!next_index}"
        break
      fi
    done
    if [[ -n "$destination" ]]; then
      printf 'downloaded blob\n' > "$destination"
    fi
    exit 0
    ;;
  'storage blob show')
    printf '%s\n' "${MOCK_BLOB_SHOW_SHA:-2222222222222222222222222222222222222222222222222222222222222222}"
    exit 0
    ;;
  *)
    printf 'unexpected az invocation: %s\n' "$*" >&2
    exit 99
    ;;
esac
''',
        )
        write_executable(
            bin_dir / "sha256sum",
            r'''#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_SHA_LOG"
file="${!#}"
printf '%s  %s\n' "${MOCK_SHA256SUM_VALUE:-1111111111111111111111111111111111111111111111111111111111111111}" "$file"
''',
        )

        base_env = os.environ.copy()
        for variable_name in (
            "GITHUB_APP_ID",
            "GITHUB_APP_INSTALLATION_ID",
            "GITHUB_APP_PRIVATE_KEY",
        ):
            base_env.pop(variable_name, None)
        base_env.update(
            {
                "PATH": f"{bin_dir}:{base_env['PATH']}",
                "AZURE_CLIENT_ID": "client-id",
                "AZURE_SUBSCRIPTION_ID": "sub-id",
                "AZURE_RESOURCE_GROUP": "rg-test",
                "AZURE_STORAGE_ACCOUNT": "stacarunnertest",
                "AZURE_STORAGE_CONTAINER": "runner-artifacts",
                "RUNNER_TEMP": str(SCRATCH / "runner-temp"),
                "GITHUB_WORKSPACE": str(SCRATCH),
                "GITHUB_ENV": str(SCRATCH / "github-env"),
                "MOCK_CALLS": str(calls_log),
                "MOCK_SHA_LOG": str(sha_log),
                "MOCK_BLOB_SHOW_SHA": "2222222222222222222222222222222222222222222222222222222222222222",
                "MOCK_SHA256SUM_VALUE": "1111111111111111111111111111111111111111111111111111111111111111",
            }
        )

        validation_success = run_script(validate_script, env=base_env, cwd=SCRATCH)
        if validation_success.returncode != 0:
            fail(
                "validation step must succeed when Azure inputs are present and App variables are absent\n"
                f"stdout: {validation_success.stdout}\nstderr: {validation_success.stderr}"
            )

        leaked_env = base_env | {"GITHUB_APP_PRIVATE_KEY": "leaked"}
        validation_failure = run_script(validate_script, env=leaked_env, cwd=SCRATCH)
        if validation_failure.returncode == 0:
            fail("validation step must fail when a GitHub App bootstrap variable leaks into the workflow")
        combined_validation_output = validation_failure.stdout + validation_failure.stderr
        expected_validation_error = (
            "ERROR: GitHub App bootstrap variable reached the workflow environment: "
            "GITHUB_APP_PRIVATE_KEY\n"
        )
        if combined_validation_output != expected_validation_error:
            fail(
                "validation step must emit the exact leaked-variable error\n"
                f"expected: {expected_validation_error!r}\n"
                f"actual: {combined_validation_output!r}"
            )

        signin_success = run_script(signin_script, env=base_env, cwd=SCRATCH)
        if signin_success.returncode != 0:
            fail(
                "managed identity sign-in step must succeed with a writable Azure config path\n"
                f"stdout: {signin_success.stdout}\nstderr: {signin_success.stderr}"
            )
        if not (Path(base_env["RUNNER_TEMP"]) / ".azure").is_dir():
            fail("managed identity sign-in step must create AZURE_CONFIG_DIR")

        result = run_script(blob_script, env=base_env, cwd=SCRATCH)
        if result.returncode == 0:
            fail("blob step must fail when checksum mismatches")
        combined_output = result.stdout + result.stderr
        if "ERROR: Downloaded Blob checksum does not match the uploaded artifact." not in combined_output:
            fail("blob step must emit the checksum mismatch error")

        calls = calls_log.read_text(encoding="utf-8")
        command_lines = calls.splitlines()
        for command in ("storage blob upload", "storage blob download", "storage blob show"):
            matches = [line for line in command_lines if command in line]
            if not matches:
                fail(f"mock call log missing command: {command}")
            for line in matches:
                if "--auth-mode login" not in line:
                    fail(f"mock call log missing auth-mode login for {command}: {line}")

    finally:
        shutil.rmtree(SCRATCH, ignore_errors=True)

    print("PASS: workflow YAML syntax and VNet-restricted Blob behavior")


if __name__ == "__main__":
    main()
