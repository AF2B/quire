(defpackage #:quire/tests/steps
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/conditions
                #:path-conflict
                #:unknown-layout)
  (:import-from #:quire/dates
                #:parse-date)
  (:import-from #:quire/page
                #:make-page
                #:page-body
                #:page-metadata
                #:page-path
                #:resolve-body)
  (:import-from #:quire/page-map
                #:add-page
                #:find-page
                #:make-page-map
                #:page-map-count
                #:page-map-pages)
  (:import-from #:quire/site
                #:make-site)
  (:import-from #:quire/steps
                #:add-section-indexes
                #:add-tag-pages
                #:all-tags
                #:apply-layouts
                #:newest-first
                #:slugify
                #:tag-url-path)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/steps)

(def-suite steps-suite
  :description "Build steps: tags, section indexes and layouts."
  :in quire-suite)

(in-suite steps-suite)

(defvar *site* (make-site :title "Test")
  "A site without layouts, for steps that do not render.")

(defun post (path date &rest metadata)
  "Return a dated post page at PATH, written on DATE, with extra METADATA."
  (make-page :path path
             :body "<p>body</p>"
             :metadata (append (list :title path
                                     :section "posts"
                                     :layout :post
                                     :timestamp (parse-date date))
                               metadata)))

(defun map-of-pages (&rest pages)
  "Return a page map holding PAGES."
  (let ((page-map (make-page-map)))
    (dolist (page pages page-map)
      (add-page page-map page))))

(defun paths-of (page-map)
  "Return the URL paths of PAGE-MAP in order."
  (mapcar #'page-path (page-map-pages page-map)))

(test slugify-lowercases-and-hyphenates
  (is (string= "common-lisp" (slugify "Common Lisp")))
  (is (string= "c-lisp" (slugify "  C++ & Lisp! ")))
  (is (string= "olá-mundo" (slugify "Olá Mundo")))
  (is (string= "a-b" (slugify "a---b")))
  (is (string= "" (slugify "---"))))

(test tag-urls-use-the-slug
  (is (string= "/tags/common-lisp/" (tag-url-path "Common Lisp"))))

(test all-tags-are-unique-and-sorted
  (is (equal '("clojure" "lisp")
             (all-tags (list (post "/a/" "2026-01-01" :tags '("lisp" "clojure"))
                             (post "/b/" "2026-01-02" :tags '("lisp")))))))

(test newest-first-orders-by-date-then-path
  (is (equal '("/c/" "/a/" "/b/")
             (mapcar #'page-path
                     (newest-first (list (post "/b/" "2026-01-01")
                                         (post "/c/" "2026-03-01")
                                         (post "/a/" "2026-01-01")))))))

(test tag-pages-are-generated
  (let ((result (add-tag-pages (map-of-pages
                                (post "/a/" "2026-01-01" :tags '("Lisp" "CL")))
                               *site*)))
    (is (equal '("/a/" "/tags/" "/tags/cl/" "/tags/lisp/") (paths-of result)))
    (is (eq :tag (getf (page-metadata (find-page result "/tags/lisp/")) :layout)))
    (is (string= "Lisp"
                 (getf (page-metadata (find-page result "/tags/lisp/")) :tag)))
    (is (eq :tags (getf (page-metadata (find-page result "/tags/")) :layout)))))

(test no-tags-means-no-tag-pages
  (let ((input (map-of-pages (post "/a/" "2026-01-01"))))
    (is (eq input (add-tag-pages input *site*)))))

(test steps-do-not-modify-their-input
  (let ((input (map-of-pages (post "/a/" "2026-01-01" :tags '("x")))))
    (add-tag-pages input *site*)
    (is (= 1 (page-map-count input)))))

(test tags-with-the-same-slug-conflict
  (signals path-conflict
    (add-tag-pages (map-of-pages (post "/a/" "2026-01-01" :tags '("C++" "c")))
                   *site*)))

(test an-existing-tags-page-is-kept
  (let* ((own (make-page :path "/tags/" :body "mine"
                         :metadata '(:title "Mine" :layout :page)))
         (result (add-tag-pages
                  (map-of-pages (post "/a/" "2026-01-01" :tags '("x")) own)
                  *site*)))
    (is (eq own (find-page result "/tags/")))))

(test section-indexes-are-generated-for-dated-sections
  (let ((result (add-section-indexes
                 (map-of-pages (post "/posts/a/" "2026-01-01")
                               (make-page :path "/about/" :body "x"
                                          :metadata '(:section "about")))
                 *site*)))
    (is (equal '("/about/" "/posts/" "/posts/a/") (paths-of result)))
    (is (eq :index (getf (page-metadata (find-page result "/posts/")) :layout)))
    (is (string= "Posts" (getf (page-metadata (find-page result "/posts/"))
                               :title)))))

(test an-existing-section-index-is-kept
  (let* ((own (make-page :path "/posts/" :body "mine"
                         :metadata '(:section "posts" :layout :page)))
         (result (add-section-indexes
                  (map-of-pages (post "/posts/a/" "2026-01-01") own)
                  *site*)))
    (is (eq own (find-page result "/posts/")))))

(defun recording-layout (page site pages)
  "Return a string that names PAGE, SITE and the number of PAGES."
  (format nil "[~A ~A ~D]" (page-path page) (type-of site) (length pages)))

(defun layout-site (&rest layouts)
  "Return a site whose layouts are the plist LAYOUTS."
  (make-site :title "Test" :layouts layouts))

(test layouts-wrap-pages-lazily
  (let* ((input (map-of-pages (post "/a/" "2026-01-01")
                              (make-page :path "/data.json" :body "{}")))
         (result (apply-layouts input (layout-site :post 'recording-layout)))
         (page (find-page result "/a/")))
    (is-true (functionp (page-body page)))
    (is (string= "[/a/ SITE 2]" (resolve-body page)))
    (is (string= "{}" (page-body (find-page result "/data.json"))))
    (is (eq :post (getf (page-metadata page) :layout)))))

(test layouts-are-late-bound
  (let* ((input (map-of-pages (post "/a/" "2026-01-01")))
         (result (apply-layouts input (layout-site :post 'mutable-layout)))
         (page (find-page result "/a/")))
    (setf (symbol-function 'mutable-layout)
          (lambda (page site pages)
            (declare (ignore page site pages))
            "first"))
    (is (string= "first" (resolve-body page)))
    (setf (symbol-function 'mutable-layout)
          (lambda (page site pages)
            (declare (ignore page site pages))
            "second"))
    (is (string= "second" (resolve-body page)))))

(test unknown-layout-is-reported-early
  (signals unknown-layout
    (apply-layouts (map-of-pages (post "/a/" "2026-01-01"))
                   (layout-site))))

(test unknown-layout-can-be-replaced-with-use-value
  (let* ((result (handler-bind ((unknown-layout
                                  (lambda (condition)
                                    (declare (ignore condition))
                                    (invoke-restart 'use-value
                                                    'recording-layout))))
                   (apply-layouts (map-of-pages (post "/a/" "2026-01-01"))
                                  (layout-site)))))
    (is (string= "[/a/ SITE 1]" (resolve-body (find-page result "/a/"))))))

(test layout-must-return-a-string
  (let* ((result (apply-layouts (map-of-pages (post "/a/" "2026-01-01"))
                                (layout-site :post
                                             (lambda (page site pages)
                                               (declare (ignore page site pages))
                                               42)))))
    (signals type-error (resolve-body (find-page result "/a/")))))
