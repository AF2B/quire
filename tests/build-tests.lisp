(defpackage #:quire/tests/build
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/build
                #:build-site
                #:default-steps
                #:run-steps)
  (:import-from #:quire/export
                #:export-site)
  (:import-from #:quire/page
                #:page-path
                #:resolve-body)
  (:import-from #:quire/page-map
                #:add-page
                #:find-page
                #:make-page-map
                #:page-map-pages)
  (:import-from #:quire/site
                #:make-site)
  (:import-from #:quire/tests/suite
                #:quire-suite)
  (:import-from #:quire/tests/support
                #:directory-snapshot
                #:with-temp-directory
                #:write-text-file)
  (:import-from #:quire/theme-borba
                #:layouts
                #:steps))

(in-package #:quire/tests/build)

(def-suite build-suite
  :description "Building a whole site end to end, with the Borba theme."
  :in quire-suite)

(in-suite build-suite)

(defun write-sample-content (root)
  "Write a small site under ROOT."
  (write-text-file root "content/index.md"
                   (format nil "---~%(:layout :home)~%---~%Welcome."))
  (write-text-file root "content/about.md"
                   (format nil "---~%(:title \"About me\")~%---~%About."))
  (write-text-file root "content/posts/first.md"
                   (format nil "---~%(:title \"First\" :date \"2026-01-10\" ~
                                :tags (\"lisp\" \"meta\") :description ~
                                \"Opening post\")~%---~%# Hi~%~%text"))
  (write-text-file root "content/posts/second.md"
                   (format nil "---~%(:title \"Second\" :date \"2026-02-20\" ~
                                :tags (\"lisp\"))~%---~%more"))
  (write-text-file root "content/posts/wip.md"
                   (format nil "---~%(:title \"WIP\" :draft t ~
                                :date \"2026-03-01\")~%---~%x"))
  (write-text-file root "static/robots.txt" "User-agent: *"))

(defun sample-site (root)
  "Return a themed site rooted at ROOT."
  (make-site :title "Sample"
             :description "A sample site"
             :base-url "https://example.com"
             :root root
             :layouts (layouts)
             :steps (steps)
             :extra '(:nav (("Home" . "/") ("Posts" . "/posts/")
                            ("Tags" . "/tags/") ("About" . "/about/")))))

(defun built-paths (page-map)
  "Return the URL paths of PAGE-MAP in order, without theme assets."
  (remove-if (lambda (path)
               (or (search "/css/" path) (search "/fonts/" path)))
             (mapcar #'page-path (page-map-pages page-map))))

(test default-steps-end-with-layouts
  (is (eq 'quire/steps:apply-layouts (car (last (default-steps))))))

(test run-steps-threads-the-page-map-through-each-step
  (let ((trace '()))
    (run-steps (list (lambda (page-map site)
                       (declare (ignore site))
                       (push :first trace)
                       page-map)
                     (lambda (page-map site)
                       (declare (ignore site))
                       (push :second trace)
                       page-map))
               (make-page-map)
               (make-site :title "T"))
    (is (equal '(:second :first) trace))))

(test whole-site-is-built
  (with-temp-directory (root)
    (write-sample-content root)
    (let ((page-map (build-site (sample-site root))))
      (is (equal '("/" "/about/" "/atom.xml" "/feed.xml" "/posts/" "/posts/first/"
                   "/posts/second/" "/robots.txt" "/sitemap.xml" "/tags/"
                   "/tags/lisp/" "/tags/meta/")
                 (built-paths page-map)))
      (is-false (find-page page-map "/posts/wip/")))))

(test rendered-pages-carry-theme-and-content
  (with-temp-directory (root)
    (write-sample-content root)
    (let* ((page-map (build-site (sample-site root)))
           (post (resolve-body (find-page page-map "/posts/first/")))
           (home (resolve-body (find-page page-map "/")))
           (index (resolve-body (find-page page-map "/posts/")))
           (tag (resolve-body (find-page page-map "/tags/lisp/"))))
      (is-true (search "<h1>Hi</h1>" post))
      (is-true (search "2026-01-10" post))
      (is-true (search "/tags/meta/" post))
      (is-true (search "Welcome." home))
      (is-true (search "Second" home))
      (is-false (search "WIP" home))
      (is-true (search "Opening post" index))
      (is-true (and (search "Second" index)
                    (search "First" index)
                    (< (search "Second" index) (search "First" index))))
      (is-true (search "First" tag))
      (is-true (search "Second" tag)))))

(test builds-are-deterministic
  (with-temp-directory (root)
    (write-sample-content root)
    (with-temp-directory (first)
      (with-temp-directory (second)
        (export-site (build-site (sample-site root)) first)
        (export-site (build-site (sample-site root)) second)
        (is (equalp (directory-snapshot first) (directory-snapshot second)))
        (is (< 10 (length (directory-snapshot first))))))))

(test user-static-files-override-theme-assets
  (with-temp-directory (root)
    (write-text-file root "static/css/quire-borba.css" "/* mine */")
    (let ((page-map (build-site (sample-site root))))
      (is (equalp (map 'vector #'char-code "/* mine */")
                  (quire/page:page-body
                   (find-page page-map "/css/quire-borba.css")))))))
