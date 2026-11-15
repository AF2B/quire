(defpackage #:quire/tests/paths
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/conditions
                #:invalid-path
                #:invalid-path-path
                #:invalid-path-reason)
  (:import-from #:quire/paths
                #:parse-path
                #:path->output-path
                #:path-directory-p)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/paths)

(def-suite paths-suite
  :description "URL path validation and output path mapping."
  :in quire-suite)

(in-suite paths-suite)

(defun reason-of (path)
  "Return the reason PARSE-PATH rejects PATH, or NIL when PATH is valid."
  (handler-case (progn (parse-path path) nil)
    (invalid-path (condition) (invalid-path-reason condition))))

(test valid-paths-are-returned-unchanged
  (dolist (path '("/"
                  "/blog/"
                  "/blog/first-post/"
                  "/feed.xml"
                  "/a/b.html"
                  "/.nojekyll"
                  "/olá/"))
    (is (string= path (parse-path path))
        "~S should be valid" path)))

(test empty-path-is-rejected
  (is (eq :empty (reason-of ""))))

(test relative-path-is-rejected
  (is (eq :not-absolute (reason-of "blog/")))
  (is (eq :not-absolute (reason-of "feed.xml"))))

(test file-path-without-extension-is-rejected
  (is (eq :missing-extension (reason-of "/blog")))
  (is (eq :missing-extension (reason-of "/a/b")))
  (is (eq :missing-extension (reason-of "/a."))))

(test empty-and-dot-segments-are-rejected
  (is (eq :bad-segment (reason-of "/a//b/")))
  (is (eq :bad-segment (reason-of "/a/./b/")))
  (is (eq :bad-segment (reason-of "/a/../b/")))
  (is (eq :bad-segment (reason-of "/.."))))

(test illegal-characters-are-rejected
  (dolist (path (list "/a?b/"
                      "/a#b/"
                      "/a\\b/"
                      (format nil "/a~Cb/" (code-char 0))
                      (format nil "/a~Cb/" (code-char 10))
                      (format nil "/a~Cb/" (code-char 127))))
    (is (eq :illegal-character (reason-of path))
        "~S should be rejected" path)))

(test non-string-path-is-a-type-error
  (signals type-error (parse-path nil))
  (signals type-error (parse-path 42)))

(test invalid-path-condition-carries-the-offending-path
  (handler-case (parse-path "blog/")
    (invalid-path (condition)
      (is (string= "blog/" (invalid-path-path condition))))))

(test use-value-restart-replaces-the-path
  (let ((result (handler-bind ((invalid-path
                                 (lambda (condition)
                                   (declare (ignore condition))
                                   (invoke-restart 'use-value "/fixed/"))))
                  (parse-path "broken"))))
    (is (string= "/fixed/" result))))

(test use-value-replacement-is-validated-again
  (let ((attempts 0))
    (signals invalid-path
      (handler-bind ((invalid-path
                       (lambda (condition)
                         (declare (ignore condition))
                         ;; Offer a bad replacement once, then decline so the
                         ;; second INVALID-PATH reaches SIGNALS.
                         (when (= 1 (incf attempts))
                           (invoke-restart 'use-value "still broken")))))
        (parse-path "broken")))
    (is (= 2 attempts))))

(test directory-paths-end-with-a-separator
  (is-true (path-directory-p "/"))
  (is-true (path-directory-p "/blog/"))
  (is-false (path-directory-p "/feed.xml"))
  (is-false (path-directory-p "")))

(test output-path-maps-directories-to-index-files
  (is (string= "index.html" (path->output-path "/")))
  (is (string= "blog/index.html" (path->output-path "/blog/")))
  (is (string= "blog/x/index.html" (path->output-path "/blog/x/")))
  (is (string= "olá/index.html" (path->output-path "/olá/"))))

(test output-path-keeps-file-paths
  (is (string= "feed.xml" (path->output-path "/feed.xml")))
  (is (string= "a/b.html" (path->output-path "/a/b.html")))
  (is (string= ".nojekyll" (path->output-path "/.nojekyll"))))

(test output-path-rejects-invalid-paths
  (signals invalid-path (path->output-path "blog/")))
