#!/bin/bash

GODOT=${GODOT:-godot}

END_STRING="==== TESTS FINISHED ===="
FAILURE_STRING="******** FAILED ********"

failure=0
mode="full"  # Default: run both; set via $1

# Parse flag
if [ "$1" = "--unit-only" ]; then
    mode="unit"
elif [ "$1" = "--reload-only" ]; then
    mode="reload"
fi

if [ "$mode" = "unit" ] || [ "$mode" = "full" ]; then
    # Run Godot and capture output (stdout and stderr) and exit code
    OUTPUT=$($GODOT --path project --debug --headless --quit 2>&1)
    ERRCODE=$?

    echo "$OUTPUT"
    echo

    # Check if tests completed
    if ! echo "$OUTPUT" | grep -q "$END_STRING"; then
        failure=1
    fi

    # Check for test failures
    if echo "$OUTPUT" | grep -q "$FAILURE_STRING"; then
        failure=1
    fi
fi

if [ "$mode" = "reload" ] || [ "$mode" = "full" ]; then
    # Lock file path (relative to project dir)
    LOCK_PATH="project/test_reload_lock"

    # Delete lock file before reload test if it exists
    rm -f "$LOCK_PATH"

    # Run Godot reload test and capture output (stdout and stderr) and exit code
    OUTPUT=$($GODOT -e --path project --scene reload.tscn --headless --debug test_reload 2>&1)
    ERRCODE=$?

    # Filter spam from output
    filtered=$(echo "$OUTPUT" | sed 's/[ \t]*$//' | grep -v -E "Narrowing conversion|at:.*GDScript::reload|\[ *[0-9]+% *\]|first_scan_filesystem|loading_editor_layout")

    # Output the filtered results
    echo "$filtered"
    echo

    # Check for test failures
    if echo "$OUTPUT" | grep -q "$FAILURE_STRING"; then
        failure=1
    fi

    # Delete lock file after reload test if it exists
    rm -f "$LOCK_PATH"
fi

if [ $failure -ne 0 ]; then
    echo "ERROR: Tests failed to complete"
    exit 1
fi

# Success!
exit 0
