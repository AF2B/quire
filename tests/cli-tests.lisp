(defpackage #:quire/tests/cli
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/cli
                #:parse-options)
  (:import-from #:quire/conditions
                #:cli-usage-error)
  (:import-from #:quire/files
                #:read-file-text)
  (:import-from #:quire/tests/suite
                #:quire-suite)
  (:import-from #:quire/tests/support
                #:with-temp-directory
                #:write-text-file))

(in-package #:quire/tests/cli)

(def-suite cli-suite
  :description "Command line parsing and the build command."
  :in quire-suite)

(in-suite cli-suite)

(defun run-captured (&rest arguments)
  "Run the CLI with ARGUMENTS; return the exit code, stdout and stderr."
  (let* ((standard (make-string-output-stream))
         (errors (make-string-output-stream))
         (code (let ((*standard-output* standard)
                     (*error-output* errors))
                 (quire/cli:run arguments))))
    (values code
            (get-output-stream-string standard)
            (get-output-stream-string errors))))

(defun contains-p (needle haystack)
  "Return true when HAYSTACK contains NEEDLE."
  (and (search needle haystack) t))

(defun write-site (root)
  "Write a one-page themed site under ROOT and return its site file."
  (write-text-file root "content/index.md"
                   (format nil "---~%(:title \"Home\" :layout :home)~%---~%Hi"))
  (write-text-file root "site.lisp"
                   "(in-package #:quire-user)
(setf *site*
      (make-site :title \"CLI test\"
                 :layouts (quire/theme-borba:layouts)
                 :steps (quire/theme-borba:steps)))
"))

(test options-are-parsed-into-a-plist
  (let ((options (parse-options '("--site" "a.lisp" "--clean")
                                '("--site")
                                '("--clean"))))
    (is (string= "a.lisp" (getf options :site)))
    (is-true (getf options :clean))
    (is-false (getf options :drafts))))

(test bad-options-are-usage-errors
  (signals cli-usage-error (parse-options '("--nope") '("--site") '()))
  (signals cli-usage-error (parse-options '("--site") '("--site") '()))
  (signals cli-usage-error (parse-options '("stray") '("--site") '())))

(test version-prints-the-system-version
  (multiple-value-bind (code out) (run-captured "version")
    (is (= 0 code))
    (is-true (contains-p "quire 0.1.0" out))))

(test help-and-no-arguments-print-usage
  (dolist (arguments '(() ("help") ("--help") ("-h")))
    (multiple-value-bind (code out) (apply #'run-captured arguments)
      (is (= 0 code))
      (is-true (contains-p "Usage: quire" out)))))

(test unknown-commands-exit-with-the-usage-code
  (multiple-value-bind (code out err) (run-captured "frobnicate")
    (is (= 2 code))
    (is (string= "" out))
    (is-true (contains-p "Unknown command" err))
    (is-true (contains-p "Usage: quire" err))))

(test invalid-port-is-a-usage-error
  (with-temp-directory (root)
    (write-site root)
    (multiple-value-bind (code out err)
        (run-captured "serve" "--site"
                      (uiop:native-namestring (merge-pathnames "site.lisp" root))
                      "--port" "abc")
      (declare (ignore out))
      (is (= 2 code))
      (is-true (contains-p "Invalid port" err)))))

(test missing-site-file-exits-with-failure
  (with-temp-directory (root)
    (multiple-value-bind (code out err)
        (run-captured "build" "--site"
                      (uiop:native-namestring (merge-pathnames "nope.lisp" root)))
      (declare (ignore out))
      (is (= 1 code))
      (is-true (contains-p "file not found" err)))))

(test site-file-that-sets-no-site-exits-with-failure
  (with-temp-directory (root)
    (write-text-file root "site.lisp" "(in-package #:quire-user)")
    (multiple-value-bind (code out err)
        (run-captured "build" "--site"
                      (uiop:native-namestring (merge-pathnames "site.lisp" root)))
      (declare (ignore out))
      (is (= 1 code))
      (is-true (contains-p "did not set" err)))))

(test build-writes-the-site
  (with-temp-directory (root)
    (write-site root)
    (let ((site-file (uiop:native-namestring (merge-pathnames "site.lisp" root)))
          (output (uiop:native-namestring (merge-pathnames "out/" root))))
      (multiple-value-bind (code out err)
          (run-captured "build" "--site" site-file "--out" output)
        (is (= 0 code) "stderr: ~A" err)
        (is-true (contains-p "Built " out))
        (is-true (contains-p "Hi" (read-file-text
                                   (merge-pathnames "out/index.html" root))))
        (is-true (probe-file (merge-pathnames "out/css/quire-borba.css" root)))))))

(test build-defaults-to-public-next-to-the-site
  (with-temp-directory (root)
    (write-site root)
    (let ((code (run-captured "build" "--site"
                              (uiop:native-namestring
                               (merge-pathnames "site.lisp" root)))))
      (is (= 0 code))
      (is-true (probe-file (merge-pathnames "public/index.html" root))))))

(test clean-protects-directories-quire-did-not-create
  (with-temp-directory (root)
    (write-site root)
    (write-text-file root "out/precious.txt" "keep")
    (multiple-value-bind (code out err)
        (run-captured "build" "--clean" "--site"
                      (uiop:native-namestring (merge-pathnames "site.lisp" root))
                      "--out"
                      (uiop:native-namestring (merge-pathnames "out/" root)))
      (declare (ignore out))
      (is (= 1 code))
      (is-true (contains-p "Refusing to clean" err))
      (is (string= "keep" (read-file-text
                           (merge-pathnames "out/precious.txt" root)))))))
