#!/usr/bin/env python3

from pathlib import Path
import os
import subprocess
import tempfile

import yaml


ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = (
    ROOT / ".github/workflows/validate-workshop.yml",
    ROOT / "samples/parallel-runner-workflow.yml",
    ROOT / "samples/azure-sample-deploy-workflow.yml",
)


for workflow in WORKFLOWS:
    with workflow.open(encoding="utf-8") as stream:
        document = yaml.load(stream, Loader=yaml.BaseLoader)

    if not isinstance(document, dict):
        raise SystemExit(f"FAIL: {workflow.relative_to(ROOT)} is not a YAML mapping")

    missing = {"name", "on", "jobs"} - document.keys()
    if missing:
        raise SystemExit(
            f"FAIL: {workflow.relative_to(ROOT)} missing keys: {', '.join(sorted(missing))}"
        )

    if not isinstance(document["jobs"], dict) or not document["jobs"]:
        raise SystemExit(f"FAIL: {workflow.relative_to(ROOT)} has no jobs")

with (ROOT / "samples/azure-sample-deploy-workflow.yml").open(
    encoding="utf-8"
) as stream:
    deploy_workflow = yaml.safe_load(stream)

deploy_script = deploy_workflow["jobs"]["deploy-sample"]["steps"][2]["run"]

with tempfile.TemporaryDirectory() as temp_dir:
    temp = Path(temp_dir)
    bin_dir = temp / "bin"
    bin_dir.mkdir()
    mock_az = bin_dir / "az"
    mock_az.write_text(
        """#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >> "$MOCK_CALLS"

if [[ "$1 $2" == "containerapp show" ]]; then
  case "$MOCK_SCENARIO" in
    inspection-error)
      printf '(AuthorizationFailed) denied\\n' >&2
      exit 3
      ;;
    absent)
      printf '(ResourceNotFound) absent\\n' >&2
      exit 3
      ;;
    existing-delete)
      if [[ -f "$MOCK_DELETED" ]]; then
        printf '(ResourceNotFound) deleted\\n' >&2
        exit 3
      fi
      exit 0
      ;;
  esac
fi

if [[ "$1 $2" == "containerapp delete" ]]; then
  touch "$MOCK_DELETED"
  exit 0
fi

if [[ "$1 $2" == "containerapp create" ]]; then
  printf 'hello.example.azurecontainerapps.io\\n'
  exit 0
fi

exit 99
""",
        encoding="utf-8",
    )
    mock_az.chmod(0o755)

    base_environment = os.environ | {
        "PATH": f"{bin_dir}:{os.environ['PATH']}",
        "AZURE_SAMPLE_APP": "hello-test",
        "AZURE_RESOURCE_GROUP": "rg-test",
        "AZURE_CONTAINERAPPS_ENVIRONMENT": "env-test",
        "MOCK_CALLS": str(temp / "az-calls.log"),
        "MOCK_DELETED": str(temp / "deleted"),
    }

    def run_deploy_step(scenario: str) -> subprocess.CompletedProcess[str]:
        github_env = temp / f"github-env-{scenario}"
        environment = base_environment | {
            "GITHUB_ENV": str(github_env),
            "MOCK_SCENARIO": scenario,
        }
        return subprocess.run(
            ["bash", "-c", deploy_script],
            check=False,
            capture_output=True,
            env=environment,
            text=True,
        )

    inspection_error = run_deploy_step("inspection-error")
    if inspection_error.returncode != 2:
        raise SystemExit("FAIL: inspection errors must stop deployment")
    if "ERROR: Failed to inspect Container App hello-test." not in inspection_error.stderr:
        raise SystemExit("FAIL: inspection errors must remain visible")
    if "containerapp create" in (temp / "az-calls.log").read_text(encoding="utf-8"):
        raise SystemExit("FAIL: deployment continued after an inspection error")

    (temp / "az-calls.log").unlink()
    absent = run_deploy_step("absent")
    if absent.returncode != 0 or "No existing Container App" not in absent.stdout:
        raise SystemExit("FAIL: ResourceNotFound must allow first deployment")

    (temp / "az-calls.log").unlink()
    existing = run_deploy_step("existing-delete")
    if existing.returncode != 0 or "Confirmed existing Container App deletion" not in existing.stdout:
        raise SystemExit("FAIL: existing app deletion was not confirmed")

print("PASS: workflow YAML syntax and deploy behavior")
