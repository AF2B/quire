(defpackage #:quire/tests/content
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/conditions
                #:front-matter-error
                #:front-matter-error-reason
                #:invalid-date
                #:skipped-file)
  (:import-from #:quire/content
                #:read-content
                #:read-static-directory
                #:source-path->url-path
                #:title-from-slug)
  (:import-from #:quire/page
                #:page-body
                #:page-metadata
                #:page-path)
  (:import-from #:quire/page-map
                #:find-page
                #:page-map-count
                #:page-map-pages)
  (:import-from #:quire/site
                #:make-site
                #:site-link
                #:site-url)
  (:import-from #:quire/tests/suite
                #:quire-suite)
  (:import-from #:quire/tests/support
                #:with-temp-directory
                #:write-octet-file
                #:write-text-file))

(in-package #:quire/tests/content)

(def-suite content-suite
  :description "Reading content and static directories into page maps."
  :in quire-suite)

(in-suite content-suite)

(defun site-in (directory &rest options)
  "Return a site rooted at DIRECTORY, built with the extra OPTIONS."
  (apply #'make-site :title "Test" :root directory options))

(defun metadata-of (page-map path)
  "Return the metadata of the page at PATH in PAGE-MAP."
  (page-metadata (find-page page-map path)))

(test source-paths-map-to-directory-urls
  (is (string= "/" (source-path->url-path "index.md")))
  (is (string= "/about/" (source-path->url-path "about.md")))
  (is (string= "/posts/" (source-path->url-path "posts/index.md")))
  (is (string= "/posts/hello/" (source-path->url-path "posts/hello.md")))
  (is (string= "/a/b/c/" (source-path->url-path "a/b/c.md"))))

(test titles-come-from-slugs
  (is (string= "Hello World" (title-from-slug "hello-world")))
  (is (string= "About" (title-from-slug "about"))))

(test markdown-files-become-pages
  (with-temp-directory (root)
    (write-text-file root "content/index.md" "# Home")
    (write-text-file root "content/posts/hello.md"
                     (format nil "---~%(:title \"Hello\" :date \"2026-11-14\" ~
                                  :tags (\"lisp\"))~%---~%Body~%"))
    (let ((page-map (read-content (site-in root))))
      (is (= 2 (page-map-count page-map)))
      (is (equal '("/" "/posts/hello/")
                 (mapcar #'page-path (page-map-pages page-map))))
      (is-true (search "<h1>Home</h1>" (page-body (find-page page-map "/"))))
      (let ((metadata (metadata-of page-map "/posts/hello/")))
        (is (string= "Hello" (getf metadata :title)))
        (is (equal '("lisp") (getf metadata :tags)))
        (is (string= "posts" (getf metadata :section)))
        (is (eq :post (getf metadata :layout)))
        (is (= (encode-universal-time 0 0 0 14 11 2026 0)
               (getf metadata :timestamp)))))))

(test pages-outside-the-posts-section-use-the-page-layout
  (with-temp-directory (root)
    (write-text-file root "content/about.md" "About")
    (write-text-file root "content/posts/index.md" "Listing")
    (let ((page-map (read-content (site-in root))))
      (is (eq :page (getf (metadata-of page-map "/about/") :layout)))
      (is (eq :page (getf (metadata-of page-map "/posts/") :layout)))
      (is (string= "About" (getf (metadata-of page-map "/about/") :title))))))

(test front-matter-can-override-layout-and-path
  (with-temp-directory (root)
    (write-text-file root "content/x.md"
                     (format nil "---~%(:layout :wide :path \"/custom/\")~%---~%x"))
    (let ((page-map (read-content (site-in root))))
      (is (eq :wide (getf (metadata-of page-map "/custom/") :layout)))
      (is-false (find-page page-map "/x/")))))

(test drafts-are-left-out-unless-requested
  (with-temp-directory (root)
    (write-text-file root "content/a.md" (format nil "---~%(:draft t)~%---~%x"))
    (write-text-file root "content/b.md" "y")
    (is (equal '("/b/")
               (mapcar #'page-path
                       (page-map-pages (read-content (site-in root))))))
    (is (equal '("/a/" "/b/")
               (mapcar #'page-path
                       (page-map-pages
                        (read-content (site-in root :include-drafts-p t))))))))

(test other-files-are-copied-as-bytes
  (with-temp-directory (root)
    (let ((octets (coerce #(0 1 2 255) '(vector (unsigned-byte 8)))))
      (write-octet-file root "content/img/logo.bin" octets)
      (let ((page (find-page (read-content (site-in root)) "/img/logo.bin")))
        (is (equalp octets (page-body page)))))))

(test hidden-files-are-ignored
  (with-temp-directory (root)
    (write-text-file root "content/.secret.md" "x")
    (write-text-file root "content/.git/config.txt" "x")
    (write-text-file root "content/a.md" "x")
    (is (= 1 (page-map-count (read-content (site-in root)))))))

(test well-known-extensionless-and-hidden-files-are-copied
  (with-temp-directory (root)
    (write-text-file root "static/CNAME" "example.com")
    (write-text-file root "static/.nojekyll" "")
    (write-text-file root "static/.well-known/security.txt" "Contact: x")
    (write-text-file root "static/.git/config.txt" "x")
    (let ((page-map (read-static-directory
                     (merge-pathnames "static/" root))))
      (is (equal '("/.nojekyll" "/.well-known/security.txt" "/CNAME")
                 (sort (mapcar #'page-path (page-map-pages page-map))
                       #'string<))))))

(test files-with-invalid-site-paths-are-skipped-with-a-warning
  (with-temp-directory (root)
    (write-text-file root "content/NOTES" "no extension")
    (write-text-file root "content/a.md" "x")
    (let ((skipped 0))
      (handler-bind ((skipped-file (lambda (condition)
                                     (incf skipped)
                                     (muffle-warning condition))))
        (is (= 1 (page-map-count (read-content (site-in root))))))
      (is (= 1 skipped)))))

(test invalid-metadata-is-reported-with-its-source
  (with-temp-directory (root)
    (write-text-file root "content/a.md"
                     (format nil "---~%(:tags \"lisp\")~%---~%x"))
    (handler-case (read-content (site-in root))
      (front-matter-error (condition)
        (is (eq :invalid-value (front-matter-error-reason condition)))))))

(test invalid-dates-are-rejected
  (with-temp-directory (root)
    (write-text-file root "content/a.md"
                     (format nil "---~%(:date \"2026-02-30\")~%---~%x"))
    (signals invalid-date (read-content (site-in root)))))

(test static-directory-pages-live-at-their-relative-path
  (with-temp-directory (root)
    (write-text-file root "static/css/site.css" "a{}")
    (write-text-file root "static/robots.txt" "x")
    (let ((page-map (read-static-directory (merge-pathnames "static/" root))))
      (is (equal '("/css/site.css" "/robots.txt")
                 (mapcar #'page-path (page-map-pages page-map)))))))

(test missing-static-directory-is-empty
  (with-temp-directory (root)
    (is (zerop (page-map-count
                (read-static-directory (merge-pathnames "nope/" root)))))))

(test site-urls-and-links-honor-the-base-url
  (let ((plain (make-site :title "T"))
        (hosted (make-site :title "T" :base-url "https://example.com/"))
        (nested (make-site :title "T" :base-url "https://example.com/blog")))
    (is (string= "/a/" (site-link plain "/a/")))
    (is (string= "/a/" (site-link hosted "/a/")))
    (is (string= "/blog/a/" (site-link nested "/a/")))
    (is (string= "/a/" (site-url plain "/a/")))
    (is (string= "https://example.com/a/" (site-url hosted "/a/")))
    (is (string= "https://example.com/blog/a/" (site-url nested "/a/")))))
