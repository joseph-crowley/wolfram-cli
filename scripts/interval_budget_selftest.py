#!/usr/bin/env python3
from __future__ import annotations

"""Interval budget verification harness for multi-scheme IR positivity bounds.

Runs baseline and stressed configurations through the guarded wrapper,
parses JSON outputs, and reports whether interval tolerances are satisfied.
"""

import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
GUARDED = REPO_ROOT / "scripts" / "guarded_run.sh"
WOLFRAM = "/Applications/Wolfram.app/Contents/MacOS/wolframscript"
SCRIPT = REPO_ROOT / "problems" / "positivity-ir-multischeme" / "multi_scheme_ir_bounds.wls"


def run_scenario(label: str, extra_args: list[str]) -> dict:
    """Execute the positivity script with the provided arguments."""
    cmd = [
        str(GUARDED),
        "90",
        "120",
        "--",
        WOLFRAM,
        "-file",
        str(SCRIPT),
    ] + extra_args
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=180,
            cwd=REPO_ROOT,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return {
            "status": "error",
            "label": label,
            "reason": "timeout",
        }
    if proc.returncode != 0:
        return {
            "status": "error",
            "label": label,
            "reason": "nonzero_exit",
            "returncode": proc.returncode,
            "stderr": proc.stderr.strip(),
        }
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {
            "status": "error",
            "label": label,
            "reason": "json_decode",
            "stderr": proc.stderr.strip(),
            "stdout": proc.stdout,
        }
    aggregate = data.get("aggregate", {})
    interval = aggregate.get("intervalCompliance", {})
    summary = {
        "label": label,
        "allSchemesWithinTolerance": bool(
            interval.get("allSchemesWithinTolerance")
        ),
        "baseWithinTolerance": bool(interval.get("baseWithinTolerance")),
        "maxWidth": interval.get("maxWidth"),
        "maxAllowedWidth": interval.get("maxAllowedWidth"),
        "spread": aggregate.get("spread"),
    }
    return {"status": "ok", "summary": summary}


BASELINE_ARGS: list[str] = []
STRESS_ARGS: list[str] = [
    "--heavyStrength=2.5",
    "--heavyScale=4.0",
    "--heavyThreshold=1.2",
    "--growthPower=2.8",
    "--tailExponent=6.2",
    "--schemes="
    "'[{\"scheme\":\"analytic\"},{\"scheme\":\"cutoff\",\"sCut\":0.2},"
    "{\"scheme\":\"cutoff\",\"sCut\":0.12},{\"scheme\":\"excludeBelow\","
    "\"sMin\":1.8},{\"scheme\":\"bandGap\",\"sMin\":1.8,\"sMax\":2.6},"
    "{\"scheme\":\"bandGap\",\"sMin\":2.2,\"sMax\":3.6}]'",
    "--cRen=0.008",
]


def main() -> int:
    baseline = run_scenario("baseline", BASELINE_ARGS)
    if baseline.get("status") != "ok":
        print(
            json.dumps({"status": "failure", "stage": "baseline", "details": baseline}),
            end="",
        )
        return 1

    stress = run_scenario("stress", STRESS_ARGS)
    if stress.get("status") != "ok":
        print(
            json.dumps({"status": "failure", "stage": "stress", "details": stress}),
            end="",
        )
        return 1

    if not baseline["summary"]["allSchemesWithinTolerance"] or not baseline[
        "summary"
    ]["baseWithinTolerance"]:
        print(
            json.dumps(
                {"status": "failure", "stage": "baselineIntervals", "details": baseline}
            ),
            end="",
        )
        return 1

    if not stress["summary"]["allSchemesWithinTolerance"] or not stress["summary"][
        "baseWithinTolerance"
    ]:
        print(
            json.dumps(
                {"status": "failure", "stage": "stressIntervals", "details": stress}
            ),
            end="",
        )
        return 1

    result = {
        "status": "ok",
        "baseline": baseline["summary"],
        "stress": stress["summary"],
    }
    print(json.dumps(result), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
