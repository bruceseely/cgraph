#!/usr/bin/env bash
#
# run-tests.sh -- run cgraph's own test suite in a fresh SBCL.
#
# This is (asdf:test-system :cgraph): it loads the cgraph/tests system and runs
# every suite against the test type catalog in test/test-types/, so ~/.cgraph
# is never read or written. Then (asdf:test-system :cgraph-editor), the graph
# editor's suites, in a second SBCL: they need Hunchentoot, which the engine's
# don't. It needs Quicklisp in your SBCL init, and cgraph somewhere ASDF can
# find it (e.g. ~/quicklisp/local-projects/).
#
# In a loaded image, (cg::test-all t) and (cg::editor-test t) do the same, from
# any package.
#
# Usage:   test/run-tests.sh            (per-suite pass/fail lines)
# Env:     SBCL=/path/to/sbcl           (default: sbcl on PATH)
# Exit:    0 iff every suite, engine and editor, passed.
set -u
SBCL="${SBCL:-sbcl}"

status=0

"$SBCL" --non-interactive --disable-debugger \
  --eval '(ql:quickload :cgraph :silent t)' \
  --eval '(handler-bind ((warning (function muffle-warning)))
            (asdf:test-system :cgraph))' || status=1

"$SBCL" --non-interactive --disable-debugger \
  --eval '(ql:quickload "cgraph-editor/tests" :silent t)' \
  --eval '(handler-bind ((warning (function muffle-warning)))
            (asdf:test-system :cgraph-editor))' || status=1

exit $status
