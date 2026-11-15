(defpackage #:quire/tests/page
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/conditions
                #:invalid-path)
  (:import-from #:quire/page
                #:make-page
                #:page-body
                #:page-metadata
                #:page-path
                #:page-source)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/page)

(def-suite page-suite
  :description "Page construction and validation."
  :in quire-suite)

(in-suite page-suite)

(test page-exposes-its-slots
  (let ((page (make-page :path "/blog/"
                         :body "<p>hi</p>"
                         :metadata '(:title "Blog")
                         :source #p"content/blog.md")))
    (is (string= "/blog/" (page-path page)))
    (is (string= "<p>hi</p>" (page-body page)))
    (is (equal '(:title "Blog") (page-metadata page)))
    (is (equal #p"content/blog.md" (page-source page)))))

(test metadata-and-source-default-to-nil
  (let ((page (make-page :path "/" :body "")))
    (is-false (page-metadata page))
    (is-false (page-source page))))

(test body-may-be-a-string-octets-or-a-function
  (is-true (make-page :path "/a/" :body "text"))
  (is-true (make-page :path "/a.bin"
                      :body (make-array 3
                                        :element-type '(unsigned-byte 8)
                                        :initial-element 0)))
  (is-true (make-page :path "/a/" :body (lambda (page) (page-path page)))))

(test invalid-body-is-a-type-error
  (signals type-error (make-page :path "/a/" :body 42))
  (signals type-error (make-page :path "/a/" :body nil)))

(test invalid-path-is-rejected
  (signals invalid-path (make-page :path "no-slash" :body "x")))

(test missing-path-is-a-type-error
  (signals type-error (make-page :body "x")))

(test odd-length-metadata-is-a-type-error
  (signals type-error (make-page :path "/a/" :body "x" :metadata '(:title))))
