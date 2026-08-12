Task 5 round 1/5 fix evidence:
- Extended `tests/docs/test-build-deploy.sh` to assert the Task 5 Job doc includes `--replica-timeout 900`, `--mi-user-assigned "$UAMI_RID"`, `--cpu 2.0`, and `--memory 4Gi`, while keeping the existing exact KEDA/secret/registry checks.
- Verified `docs/04-event-job-keda.md` already contains those exact values, so no doc change was needed.
