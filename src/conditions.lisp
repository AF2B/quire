(defpackage #:quire/conditions
  (:use #:cl)
  (:export #:quire-error
           #:invalid-path
           #:invalid-path-path
           #:invalid-path-reason
           #:path-conflict
           #:path-conflict-path
           #:path-conflict-output-path
           #:path-conflict-reason
           #:front-matter-error
           #:front-matter-error-source
           #:front-matter-error-reason
           #:front-matter-error-detail
           #:invalid-date
           #:invalid-date-text
           #:unknown-layout
           #:unknown-layout-layout
           #:unknown-layout-page-path
           #:unsafe-output-directory
           #:unsafe-output-directory-directory
           #:unsafe-output-directory-reason
           #:site-file-error
           #:site-file-error-file
           #:site-file-error-reason
           #:cli-usage-error
           #:cli-usage-error-message
           #:skipped-file
           #:skipped-file-file))

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

(defun describe-front-matter-reason (reason)
  "Return a human-readable sentence for the front-matter REASON keyword.

REASON: one of :UNTERMINATED, :UNREADABLE, :NOT-A-PLIST, :TRAILING-FORMS or
:INVALID-VALUE."
  (ecase reason
    (:unterminated "the closing --- line is missing")
    (:unreadable "the metadata is not readable Lisp")
    (:not-a-plist "the metadata must be a property list with keyword keys")
    (:trailing-forms "the metadata holds more than one form")
    (:invalid-value "a metadata value has the wrong type")))

(define-condition front-matter-error (quire-error)
  ((source :initarg :source
           :initform nil
           :reader front-matter-error-source
           :documentation "Origin of the text, for the message; may be NIL.")
   (reason :initarg :reason
           :reader front-matter-error-reason
           :documentation "Keyword naming what is wrong with the metadata.")
   (detail :initarg :detail
           :initform nil
           :reader front-matter-error-detail
           :documentation "Extra text, such as the reader error; may be NIL."))
  (:report (lambda (condition stream)
             (format stream "Bad front matter~@[ in ~A~]: ~A~@[ (~A)~]."
                     (front-matter-error-source condition)
                     (describe-front-matter-reason
                      (front-matter-error-reason condition))
                     (front-matter-error-detail condition))))
  (:documentation "Signaled when the metadata of a content file is unusable."))

(define-condition invalid-date (quire-error)
  ((text :initarg :text
         :reader invalid-date-text
         :documentation "The rejected date string."))
  (:report (lambda (condition stream)
             (format stream "Invalid date ~S: expected YYYY-MM-DD or ~
                             YYYY-MM-DDTHH:MM:SS[Z]."
                     (invalid-date-text condition))))
  (:documentation "Signaled when a date string is not ISO 8601 or not real."))

(define-condition unknown-layout (quire-error)
  ((layout :initarg :layout
           :reader unknown-layout-layout
           :documentation "The layout keyword that has no definition.")
   (page-path :initarg :page-path
              :reader unknown-layout-page-path
              :documentation "URL path of the page that asked for it."))
  (:report (lambda (condition stream)
             (format stream "Page ~S uses unknown layout ~S."
                     (unknown-layout-page-path condition)
                     (unknown-layout-layout condition))))
  (:documentation "Signaled when a page names a layout the site lacks.
Offers the USE-VALUE restart to supply a layout function designator."))

(define-condition unsafe-output-directory (quire-error)
  ((directory :initarg :directory
              :reader unsafe-output-directory-directory
              :documentation "The directory that was refused.")
   (reason :initarg :reason
           :reader unsafe-output-directory-reason
           :documentation "Either :NOT-A-DIRECTORY or :NOT-QUIRE-OUTPUT."))
  (:report (lambda (condition stream)
             (format stream "Refusing to clean ~A: ~A."
                     (unsafe-output-directory-directory condition)
                     (ecase (unsafe-output-directory-reason condition)
                       (:not-a-directory "it is not a directory")
                       (:not-quire-output
                        "it is not empty and was not created by quire")))))
  (:documentation "Signaled when cleaning a directory could destroy user data."))

(define-condition site-file-error (quire-error)
  ((file :initarg :file
         :reader site-file-error-file
         :documentation "The site definition file.")
   (reason :initarg :reason
           :reader site-file-error-reason
           :documentation "Either :MISSING or :NO-SITE."))
  (:report (lambda (condition stream)
             (format stream "Site file ~A: ~A."
                     (site-file-error-file condition)
                     (ecase (site-file-error-reason condition)
                       (:missing "file not found")
                       (:no-site "it did not set QUIRE:*SITE* to a site")))))
  (:documentation "Signaled when the site definition file cannot be used."))

(define-condition cli-usage-error (quire-error)
  ((message :initarg :message
            :reader cli-usage-error-message
            :documentation "What is wrong with the command line."))
  (:report (lambda (condition stream)
             (write-string (cli-usage-error-message condition) stream)))
  (:documentation "Signaled when the command line is not understood."))

(define-condition skipped-file (warning)
  ((file :initarg :file
         :reader skipped-file-file
         :documentation "The file that was left out of the site."))
  (:report (lambda (condition stream)
             (format stream "Skipped ~A: its name is not a valid site path."
                     (skipped-file-file condition))))
  (:documentation "Signaled when a static file cannot become a page."))
