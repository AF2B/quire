(defpackage #:quire/tests/sitemap
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/dates
                #:parse-date)
  (:import-from #:quire/page
                #:make-page
                #:page-body)
  (:import-from #:quire/page-map
                #:add-page
                #:find-page
                #:make-page-map)
  (:import-from #:quire/site
                #:make-site)
  (:import-from #:quire/sitemap
                #:add-sitemap)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/sitemap)

(def-suite sitemap-suite
  :description "Sitemap generation."
  :in quire-suite)

(in-suite sitemap-suite)

(defun sitemap-of (&rest pages)
  "Return the sitemap text built from PAGES."
  (let ((page-map (make-page-map))
        (site (make-site :title "T" :base-url "https://example.com")))
    (dolist (page pages)
      (add-page page-map page))
    (page-body (find-page (add-sitemap page-map site) "/sitemap.xml"))))

(defun html-page (path &rest metadata)
  "Return a page at PATH that renders through the :PAGE layout."
  (make-page :path path :body "x" :metadata (list* :layout :page metadata)))

(test pages-with-a-layout-are-listed-in-path-order
  (let* ((sitemap (sitemap-of (html-page "/b/") (html-page "/a/")))
         (a (search "<loc>https://example.com/a/</loc>" sitemap))
         (b (search "<loc>https://example.com/b/</loc>" sitemap)))
    (is-true (and a b (< a b)))))

(test assets-and-noindex-pages-are-left-out
  (let ((sitemap (sitemap-of (html-page "/a/")
                             (html-page "/hidden/" :noindex t)
                             (make-page :path "/style.css" :body "a{}"))))
    (is-false (search "hidden" sitemap))
    (is-false (search "style.css" sitemap))))

(test dated-pages-carry-lastmod
  (let ((sitemap (sitemap-of (html-page "/a/"
                                        :timestamp (parse-date "2026-11-14")))))
    (is-true (search "<lastmod>2026-11-14</lastmod>" sitemap))))

(test sitemap-is-a-urlset-document
  (let ((sitemap (sitemap-of (html-page "/a/"))))
    (is-true (search "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" sitemap))
    (is-true (search "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"
                     sitemap))
    (is-true (search "</urlset>" sitemap))))
