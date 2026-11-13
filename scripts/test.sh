#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p build/module-cache

run_suite() {
    local suite="$1"
    shift
    xcrun swiftc "$@" -module-cache-path "$PWD/build/module-cache" -o "build/$suite"
    "build/$suite"
}

run_suite report-tests Sources/DualSenseReport.swift tools/report-tests.swift
run_suite motion-tests Sources/CursorMotion.swift tools/motion-tests.swift
run_suite gesture-tests Sources/DualSenseReport.swift Sources/TouchGestures.swift tools/gesture-tests.swift
run_suite click-tests Sources/ClickSequence.swift tools/click-tests.swift
run_suite permission-tests Sources/PermissionChange.swift tools/permission-tests.swift
