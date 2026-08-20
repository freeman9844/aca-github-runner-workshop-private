#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
docs = sorted((root / "docs").glob("0[1-7]-*.md"))
korean = re.compile(r"[가-힣]")
failures = []
block_count = 0

for doc in docs:
    lines = doc.read_text(encoding="utf-8").splitlines()
    for marker_index, line in enumerate(lines):
        if line != "🟢 **실행**":
            continue

        fence_index = None
        for index in range(marker_index + 1, min(len(lines), marker_index + 40)):
            candidate = lines[index]
            if candidate.startswith("## ") or candidate in {
                "🟢 **실행**",
                "👁️ **설명**",
                "📋 **예상 출력**",
                "⚠️ **주의**",
            }:
                break
            if candidate == "```bash":
                fence_index = index
                break

        if fence_index is None:
            continue

        block_count += 1
        closing_index = next(
            index
            for index in range(fence_index + 1, len(lines))
            if lines[index] == "```"
        )
        first_line = next(
            (candidate.strip() for candidate in lines[fence_index + 1:closing_index] if candidate.strip()),
            "",
        )
        if not first_line.startswith("# ") or not korean.search(first_line):
            failures.append(
                f"{doc.relative_to(root)}:{fence_index + 2}: "
                "execution Bash block must start with a Korean purpose comment"
            )

if block_count != 36:
    failures.append(f"expected 36 execution Bash blocks, found {block_count}")

if failures:
    print("\n".join(f"FAIL: {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)

print("PASS: execution Bash blocks start with Korean comments")
PY
