#!/usr/bin/env python3
"""
run-tests.py - Robust test runner for godot-cpp test project

Usage:
    python run-tests.py [--unit-only | --reload-only]    # default: full
"""

import argparse
import os
import re
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Optional, Tuple

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────

GODOT = os.environ.get("GODOT", "godot")
PROJECT_PATH = Path("project").resolve()

END_MARKER = "==== TESTS FINISHED ===="
FAIL_MARKER = "******** FAILED ********"

ERROR_PATTERNS = [
    re.compile(r"ERROR:", re.I),
    re.compile(r"SCRIPT ERROR:", re.I),
    re.compile(re.escape(FAIL_MARKER)),
    re.compile(r"Cannot get class", re.I),
    re.compile(r"Failed to load script", re.I),
    re.compile(r"non-existent interface function", re.I),
    re.compile(r"Unable to load GDExtension", re.I),
    re.compile(r"Parse Error:", re.I),
]

TIMEOUT_SEC = 45

FILTER_PATTERNS = [
    re.compile(r"Narrowing conversion"),
    re.compile(r"at:\s+GDScript::reload"),
    re.compile(r"\[\s*\d+%\s*\]"),
    re.compile(r"first_scan_filesystem"),
    re.compile(r"loading_editor_layout"),
]

# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────

def filter_output(lines: list[str]) -> list[str]:
    """Remove noisy lines from Godot output."""
    result = []
    for line in lines:
        cleaned = line.rstrip()
        if not cleaned:
            continue
        if any(pat.search(cleaned) for pat in FILTER_PATTERNS):
            continue
        result.append(cleaned)
    return result


def has_failure_sign(output: str) -> bool:
    """Check for various failure indicators in output."""
    if FAIL_MARKER in output:
        return True
    return any(pat.search(output) for pat in ERROR_PATTERNS)


def run_godot(args: list[str], desc: str) -> Tuple[int, str, bool]:
    """
    Run Godot with timeout + output capture.
    Returns: (exit_code, full_output, timed_out)
    """
    print(f"\n{'─' * 10} {desc} {'─' * 10}")
    print(f"→ {' '.join([GODOT] + args)}")

    with tempfile.TemporaryDirectory() as tmpdir:
        stdout_path = Path(tmpdir) / "stdout.txt"
        stderr_path = Path(tmpdir) / "stderr.txt"

        cmd = [GODOT] + args

        try:
            start = time.time()
            proc = subprocess.Popen(
                cmd,
                stdout=stdout_path.open("wb"),
                stderr=stderr_path.open("wb"),
                cwd=os.getcwd(),
                start_new_session=True,  # better signal handling
            )

            while proc.poll() is None:
                if time.time() - start > TIMEOUT_SEC:
                    print(f"→ TIMEOUT after {TIMEOUT_SEC}s – killing process")
                    proc.send_signal(signal.SIGTERM)
                    time.sleep(1.0)
                    if proc.poll() is None:
                        proc.kill()
                    proc.wait()
                    return 124, "TIMEOUT", True

                time.sleep(0.2)

            exit_code = proc.returncode

            stdout = stdout_path.read_text("utf-8", errors="replace")
            stderr = stderr_path.read_text("utf-8", errors="replace")
            full_output = stdout + stderr

            print(full_output.rstrip())
            print(f"→ Exit code: {exit_code}")

            return exit_code, full_output, False

        except Exception as exc:
            msg = f"Failed to run Godot: {exc}"
            print(msg)
            return 1, msg, False


def run_tests(mode: str) -> bool:
    success = True

    if mode in ("unit", "full"):
        args = ["--path", str(PROJECT_PATH), "--debug", "--headless", "--quit"]
        exit_code, output, timed_out = run_godot(args, "Unit / headless tests")

        if timed_out or exit_code != 0:
            success = False
        if END_MARKER not in output:
            print("→ Missing end marker – treated as failure")
            success = False
        if has_failure_sign(output):
            print("→ Detected error/failure markers")
            success = False

    if mode in ("reload", "full"):
        lock_path = PROJECT_PATH / "test_reload_lock"
        lock_path.unlink(missing_ok=True)

        args = [
            "-e",
            "--path",
            str(PROJECT_PATH),
            "--scene",
            "reload.tscn",
            "--headless",
            "--debug",
            "test_reload",
        ]

        exit_code, output, timed_out = run_godot(args, "Reload test")

        filtered = filter_output(output.splitlines())
        print("\n".join(filtered))

        if timed_out or exit_code != 0:
            success = False
        if has_failure_sign(output):
            print("→ Detected error/failure markers")
            success = False

        lock_path.unlink(missing_ok=True)

    return success


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Run godot-cpp test suite")
    parser.add_argument(
        "--unit-only", action="store_const", const="unit", dest="mode",
        help="Run only unit tests (--quit)"
    )
    parser.add_argument(
        "--reload-only", action="store_const", const="reload", dest="mode",
        help="Run only reload test"
    )
    args = parser.parse_args()

    mode = args.mode or "full"

    print(f"Using Godot: {GODOT}")
    print(f"Project:    {PROJECT_PATH}")
    print(f"Mode:       {mode}\n")

    all_passed = run_tests(mode)

    print("\n" + "═" * 40)
    if all_passed:
        print("TEST SUITE PASSED")
        sys.exit(0)
    else:
        print("TEST SUITE FAILED")
        sys.exit(1)


if __name__ == "__main__":
    main()
