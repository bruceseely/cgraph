#!/usr/bin/env bash
#
# run-tests.sh -- run cgraph's own test suite (cg::test-all) in a fresh SBCL.
#
# The suite swaps type catalogs in and out of *CGRAPH-TYPES-DIRECTORY* as it
# runs, so this points that at a throwaway temp directory: ~/.cgraph is never
# read or written. It needs Quicklisp in your SBCL init, and cgraph somewhere
# ASDF can find it (e.g. ~/quicklisp/local-projects/).
#
# This is the cgraph step of cg-from-parse's test/run-all-suites.sh, on its
# own. (cg::test-all t) also passes by hand, from any package, after an
# ordinary SETUP-CGRAPH; this is the version with nothing else in the image.
#
# Usage:   test/run-tests.sh            (per-suite pass/fail lines)
# Env:     SBCL=/path/to/sbcl           (default: sbcl on PATH)
# Exit:    0 iff every suite passed.
set -u
SBCL="${SBCL:-sbcl}"

CGTYPES_DIR="$(mktemp -d)/"
export CGTYPES_DIR
trap 'rm -rf "${CGTYPES_DIR%/}"' EXIT

"$SBCL" --non-interactive --disable-debugger \
  --eval '(ql:quickload :cgraph :silent t)' \
  --eval '(in-package :conceptual-graphs)' \
  --eval '(setf *cgraph-types-directory* (uiop:getenv "CGTYPES_DIR"))' \
  --eval '(handler-bind ((warning (function muffle-warning)))
            (load (merge-pathnames "test/test-all.lisp"
                                   (asdf:system-source-directory :cgraph))))' \
  --eval '(sb-ext:exit :code (if (test-all t) 0 1))'
