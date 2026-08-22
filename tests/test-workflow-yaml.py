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
    document = load_workflow()
    try:
        deploy_workflow = document["jobs"]
        deploy_job = deploy_workflow["deploy-private-blob"]
        steps = deploy_job["steps"]
    except KeyError as exc:
        fail("workflow must define jobs.deploy-private-blob")
    if not isinstance(deploy_job, dict):
        fail("deploy-private-blob job must be a mapping")
    if not isinstance(steps, list):
        fail("deploy-private-blob job must define steps")

    required_step_names = {
        "Validate runner inputs",
        "Sign in to Azure with managed identity",
        "Verify Blob DNS resolves to the private endpoint subnet",
        "Upload and download the private Blob artifact",
        "Show private deployment result",
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

    validate_script = get_step(steps, "Validate runner inputs").get("run")
    if not isinstance(validate_script, str):
        fail("validation step must contain a run script")

    dns_script = get_step(steps, "Verify Blob DNS resolves to the private endpoint subnet").get("run")
    if not isinstance(dns_script, str):
        fail("DNS step must contain a run script")
    if "ipaddress" not in dns_script or "startswith(" in dns_script:
        fail("DNS step must use Python ipaddress instead of shell prefix matching")

    blob_script = get_step(steps, "Upload and download the private Blob artifact").get("run")
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
            bin_dir / "getent",
            r'''#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_CALLS"
case "${MOCK_GETENT_CASE:-}" in
  private)
    printf '%s %s\n' "${MOCK_GETENT_IP:-10.20.1.4}" "$2"
    exit 0
    ;;
  public)
    printf '%s %s\n' "${MOCK_GETENT_IP:-20.60.1.4}" "$2"
    exit 0
    ;;
  unresolved)
    exit 2
    ;;
  *)
    printf 'unexpected getent scenario\n' >&2
    exit 99
    ;;
esac
''',
        )
        write_executable(
            bin_dir / "az",
            r'''#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_CALLS"
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
        base_env.update(
            {
                "PATH": f"{bin_dir}:{base_env['PATH']}",
                "AZURE_CLIENT_ID": "client-id",
                "AZURE_SUBSCRIPTION_ID": "sub-id",
                "AZURE_RESOURCE_GROUP": "rg-test",
                "AZURE_CONTAINERAPPS_ENVIRONMENT": "env-test",
                "AZURE_STORAGE_ACCOUNT": "stacarunnertest",
                "AZURE_STORAGE_CONTAINER": "runner-artifacts",
                "AZURE_PRIVATE_ENDPOINT_CIDR": "10.20.1.0/24",
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

        dns_cases = {
            "private": ("10.20.1.4", 0),
            "public": ("20.60.1.4", 1),
            "unresolved": ("", 1),
        }
        for case_name, (ip_value, expected_rc) in dns_cases.items():
            env = base_env | {"MOCK_GETENT_CASE": case_name, "MOCK_GETENT_IP": ip_value}
            result = run_script(dns_script, env=env, cwd=SCRATCH)
            if result.returncode != expected_rc:
                fail(
                    f"DNS step returned {result.returncode} for {case_name}; expected {expected_rc}\n"
                    f"stdout: {result.stdout}\nstderr: {result.stderr}"
                )

        env = base_env | {"MOCK_GETENT_CASE": "private", "MOCK_GETENT_IP": "10.20.1.4"}
        result = run_script(blob_script, env=env, cwd=SCRATCH)
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

    print("PASS: workflow YAML syntax and private Blob behavior")


if __name__ == "__main__":
    main()
