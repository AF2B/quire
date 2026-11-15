(defpackage #:quire/tests/export
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/conditions
                #:unsafe-output-directory
                #:unsafe-output-directory-reason)
  (:import-from #:quire/export
                #:+output-marker-name+
                #:export-site)
  (:import-from #:quire/files
                #:read-file-octets
                #:read-file-text)
  (:import-from #:quire/page
                #:make-page)
  (:import-from #:quire/page-map
                #:add-page
                #:make-page-map)
  (:import-from #:quire/tests/suite
                #:quire-suite)
  (:import-from #:quire/tests/support
                #:directory-snapshot
                #:with-temp-directory
                #:write-text-file))

(in-package #:quire/tests/export)

(def-suite export-suite
  :description "Writing a page map to disk."
  :in quire-suite)

(in-suite export-suite)

(defun sample-map ()
  "Return a page map with a string, a function and a bytes page."
  (let ((page-map (make-page-map)))
    (add-page page-map (make-page :path "/" :body "home ✓"))
    (add-page page-map (make-page :path "/blog/x/"
                                  :body (lambda (page)
                                          (declare (ignore page))
                                          "computed")))
    (add-page page-map (make-page :path "/img/a.bin"
                                  :body (coerce #(0 128 255)
                                                '(vector (unsigned-byte 8)))))
    page-map))

(test pages-are-written-at-their-output-paths
  (with-temp-directory (directory)
    (multiple-value-bind (written count) (export-site (sample-map) directory)
      (is (equal '("blog/x/index.html" "img/a.bin" "index.html") written))
      (is (= 3 count)))
    (is (string= "home ✓" (read-file-text (merge-pathnames "index.html"
                                                             directory))))
    (is (string= "computed"
                 (read-file-text (merge-pathnames "blog/x/index.html"
                                                  directory))))
    (is (equalp #(0 128 255)
                (read-file-octets (merge-pathnames "img/a.bin" directory))))))

(test output-is-a-pure-function-of-the-page-map
  (with-temp-directory (first)
    (with-temp-directory (second)
      (export-site (sample-map) first)
      (export-site (sample-map) second)
      (is (equalp (directory-snapshot first) (directory-snapshot second))))))

(test export-creates-a-missing-directory-with-a-marker
  (with-temp-directory (directory)
    (let ((target (merge-pathnames "out/" directory)))
      (export-site (sample-map) target)
      (is-true (probe-file (merge-pathnames +output-marker-name+ target))))))

(test clean-removes-stale-files-from-a-quire-directory
  (with-temp-directory (directory)
    (export-site (sample-map) directory)
    (write-text-file directory "stale.html" "old")
    (write-text-file directory "old-dir/page.html" "old")
    (export-site (sample-map) directory :clean t)
    (is-false (probe-file (merge-pathnames "stale.html" directory)))
    (is-false (probe-file (merge-pathnames "old-dir/" directory)))
    (is-true (probe-file (merge-pathnames "index.html" directory)))
    (is-true (probe-file (merge-pathnames +output-marker-name+ directory)))))

(test clean-refuses-a-directory-quire-did-not-create
  (with-temp-directory (directory)
    (write-text-file directory "precious.txt" "keep me")
    (handler-case (export-site (sample-map) directory :clean t)
      (unsafe-output-directory (condition)
        (is (eq :not-quire-output (unsafe-output-directory-reason condition)))))
    (is (string= "keep me"
                 (read-file-text (merge-pathnames "precious.txt" directory))))
    (is-false (probe-file (merge-pathnames "index.html" directory)))))

(test export-without-clean-keeps-foreign-files-and-writes-no-marker
  (with-temp-directory (directory)
    (write-text-file directory "precious.txt" "keep me")
    (export-site (sample-map) directory)
    (is-true (probe-file (merge-pathnames "precious.txt" directory)))
    (is-true (probe-file (merge-pathnames "index.html" directory)))
    (is-false (probe-file (merge-pathnames +output-marker-name+ directory)))))

(test clean-refuses-a-regular-file
  (with-temp-directory (directory)
    (write-text-file directory "out" "i am a file")
    (handler-case (export-site (sample-map) (merge-pathnames "out/" directory)
                               :clean t)
      (unsafe-output-directory (condition)
        (is (eq :not-a-directory (unsafe-output-directory-reason condition)))))))

(test clean-accepts-a-missing-directory
  (with-temp-directory (directory)
    (is (= 3 (nth-value 1 (export-site (sample-map)
                                       (merge-pathnames "new/" directory)
                                       :clean t))))))
