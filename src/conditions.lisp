(defpackage #:quire/conditions
  (:use #:cl)
  (:export #:quire-error
           #:invalid-path
           #:invalid-path-path
           #:invalid-path-reason
           #:path-conflict
           #:path-conflict-path
           #:path-conflict-output-path
           #:path-conflict-reason))

(in-package #:quire/conditions)

(define-condition quire-error (error)
  ()
  (:documentation "Root of every error condition signaled by quire."))

(defun describe-invalid-path-reason (reason)
  "Return a human-readable sentence for the invalid path REASON keyword.

REASON: one of :EMPTY, :NOT-ABSOLUTE, :ILLEGAL-CHARACTER, :BAD-SEGMENT or
:MISSING-EXTENSION."
  (ecase reason
    (:empty "the path is empty")
    (:not-absolute "the path must start with a slash")
    (:illegal-character "the path contains a control character, ?, # or \\")
    (:bad-segment "the path has an empty, \".\" or \"..\" segment")
    (:missing-extension
     "a path that is not a directory must end in a file with an extension")))

(define-condition invalid-path (quire-error)
  ((path :initarg :path
         :reader invalid-path-path
         :documentation "The rejected path string.")
   (reason :initarg :reason
           :reader invalid-path-reason
           :documentation "Keyword naming the rule the path breaks."))
  (:report (lambda (condition stream)
             (format stream "Invalid path ~S: ~A."
                     (invalid-path-path condition)
                     (describe-invalid-path-reason
                      (invalid-path-reason condition)))))
  (:documentation "Signaled when a string is not a valid site URL path.
Offers the USE-VALUE restart to supply a replacement path."))

(defun describe-conflict-reason (reason)
  "Return a human-readable sentence for the path conflict REASON keyword.

REASON: one of :SAME-OUTPUT or :FILE-DIRECTORY."
  (ecase reason
    (:same-output "another page already writes to that output path")
    (:file-directory "that output path is both a file and a directory")))

(define-condition path-conflict (quire-error)
  ((path :initarg :path
         :reader path-conflict-path
         :documentation "URL path of the page that could not be added.")
   (output-path :initarg :output-path
                :reader path-conflict-output-path
                :documentation "Relative output path in contention.")
   (reason :initarg :reason
           :reader path-conflict-reason
           :documentation "Either :SAME-OUTPUT or :FILE-DIRECTORY."))
  (:report (lambda (condition stream)
             (format stream "Path conflict for ~S (output ~S): ~A."
                     (path-conflict-path condition)
                     (path-conflict-output-path condition)
                     (describe-conflict-reason
                      (path-conflict-reason condition)))))
  (:documentation "Signaled when a page cannot be added to a page map.
Restarts: SKIP-PAGE always; KEEP-EXISTING and REPLACE-EXISTING when the
reason is :SAME-OUTPUT."))
