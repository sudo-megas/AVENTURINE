#!/bin/sh
# Drives tests/portal-test against tests/mock-portal on a private session bus.
#
# Each case gets its own bus and its own mock, so a wedged request in one case
# cannot affect the next. gdbus wait replaces sleeping on a guess.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

status=0

# No portal at all: the probe must fail rather than hang or throw.
echo "--- no portal on the bus ---"
if ! dbus-run-session -- ./portal-test expect-absent; then
    status=1
fi

run_case() {
    mode="$1"
    expectation="$2"
    extra="${3:-}"
    echo "--- mock portal, mode $mode $extra ---"
    if ! dbus-run-session -- sh -c '
        ./mock-portal --mode "$1" $3 >/dev/null 2>&1 &
        mock=$!
        gdbus wait --session org.freedesktop.portal.Desktop --timeout 10
        ./portal-test "$2"
        result=$?
        kill "$mock" 2>/dev/null || true
        exit $result
    ' sh "$mode" "$expectation" "$extra"; then
        status=1
    fi
}

run_case success "#C8963E"
run_case cancel  expect-cancel
run_case error   expect-error

# The Response beats the method reply down the wire. This crashed the client
# until the resume handle stopped being taken before the PickColor call.
run_case success "#C8963E" --fast

if [ "$status" -eq 0 ]; then
    echo "portal backend: all cases passed"
else
    echo "portal backend: FAILURES"
fi
exit "$status"
