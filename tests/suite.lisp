(defpackage #:quire/tests/suite
  (:use #:cl)
  (:import-from #:fiveam
                #:def-suite
                #:results-status
                #:run
                #:explain!)
  (:export #:quire-suite
           #:run-tests
           #:tests-failed))

(in-package #:quire/tests/suite)

(def-suite quire-suite
  :description "Root suite for every quire test.")

(define-condition tests-failed (error)
  ()
  (:report "One or more quire tests failed.")
  (:documentation "Signaled by RUN-TESTS when the suite does not pass."))

(defun run-tests ()
  "Run QUIRE-SUITE, print the report and return T when every test passes.

Signals TESTS-FAILED otherwise, so that a non-interactive run exits non-zero."
  (let ((results (run 'quire-suite)))
    (explain! results)
    (unless (results-status results)
      (error 'tests-failed))
    t))
