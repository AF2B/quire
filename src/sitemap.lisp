(defpackage #:quire/sitemap
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/dates
                #:format-iso-date)
  (:import-from #:quire/page
                #:make-page
                #:page-metadata
                #:page-path)
  (:import-from #:quire/page-map
                #:page-map-pages)
  (:import-from #:quire/site
                #:site-url)
  (:import-from #:quire/steps
                #:with-added-pages)
  (:import-from #:quire/xml
                #:xml-escape)
  (:export #:+sitemap-path+
           #:add-sitemap))

(in-package #:quire/sitemap)

(define-constant +sitemap-path+ "/sitemap.xml"
  :test #'string=
  :documentation "URL path of the generated sitemap.")

(defun listed-p (page)
  "Return true when PAGE belongs in the sitemap.

Only pages that render through a layout are listed, and not those marked
:NOINDEX.

PAGE: the page to test."
  (let ((metadata (page-metadata page)))
    (and (getf metadata :layout)
         (not (getf metadata :noindex)))))

(defun write-url (out page site)
  "Write the url element of PAGE to the stream OUT.

OUT: the output stream.
PAGE: the page to list.
SITE: the site being built."
  (let ((timestamp (getf (page-metadata page) :timestamp)))
    (format out "  <url>~%    <loc>~A</loc>~%"
            (xml-escape (site-url site (page-path page))))
    (when timestamp
      (format out "    <lastmod>~A</lastmod>~%" (format-iso-date timestamp)))
    (format out "  </url>~%")))

(defun add-sitemap (page-map site)
  "Return PAGE-MAP plus a sitemap.xml that lists its pages.

Pages are listed in path order. Run this before APPLY-LAYOUTS so that pages
still carry their :LAYOUT marker.

PAGE-MAP: the page map to extend.
SITE: the site being built."
  (with-added-pages
      page-map
    (list (make-page
           :path +sitemap-path+
           :body (with-output-to-string (out)
                   (format out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%")
                   (format out "<urlset ~
                                xmlns=\"http://www.sitemaps.org/schemas/~
                                sitemap/0.9\">~%")
                   (dolist (page (remove-if-not #'listed-p
                                                (page-map-pages page-map)))
                     (write-url out page site))
                   (format out "</urlset>~%"))))))
