(defpackage #:quire/atom
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/dates
                #:format-iso-datetime)
  (:import-from #:quire/feed
                #:+feed-item-limit+)
  (:import-from #:quire/page
                #:make-page
                #:page-body
                #:page-metadata
                #:page-path)
  (:import-from #:quire/page-map
                #:page-map-pages)
  (:import-from #:quire/site
                #:site-author
                #:site-description
                #:site-language
                #:site-title
                #:site-url)
  (:import-from #:quire/steps
                #:dated-pages
                #:newest-first
                #:with-added-pages)
  (:import-from #:quire/xml
                #:xml-escape)
  (:export #:+atom-path+
           #:add-atom-feed))

(in-package #:quire/atom)

(define-constant +atom-path+ "/atom.xml"
  :test #'string=
  :documentation "URL path of the generated Atom feed.")

(defun write-entry (out page site)
  "Write the Atom entry element of PAGE to the stream OUT.

OUT: the output stream.
PAGE: a dated page.
SITE: the site being built."
  (let ((metadata (page-metadata page))
        (link (xml-escape (site-url site (page-path page)))))
    (format out "  <entry>~%")
    (format out "    <title>~A</title>~%" (xml-escape (getf metadata :title)))
    (format out "    <link href=\"~A\"/>~%" link)
    (format out "    <id>~A</id>~%" link)
    (format out "    <updated>~A</updated>~%"
            (format-iso-datetime (getf metadata :timestamp)))
    (when (stringp (page-body page))
      (format out "    <content type=\"html\">~A</content>~%"
              (xml-escape (page-body page))))
    (format out "  </entry>~%")))

(defun render-atom (entries site)
  "Return the Atom 1.0 document, as a string, that lists ENTRIES.

ENTRIES: dated pages, newest first.
SITE: the site being built."
  (with-output-to-string (out)
    (format out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%")
    (format out "<feed xmlns=\"http://www.w3.org/2005/Atom\" xml:lang=\"~A\">~%"
            (xml-escape (site-language site)))
    (format out "  <title>~A</title>~%" (xml-escape (site-title site)))
    (format out "  <subtitle>~A</subtitle>~%"
            (xml-escape (site-description site)))
    (format out "  <link href=\"~A\"/>~%" (xml-escape (site-url site "/")))
    (format out "  <link rel=\"self\" type=\"application/atom+xml\" ~
                 href=\"~A\"/>~%"
            (xml-escape (site-url site +atom-path+)))
    (format out "  <id>~A</id>~%" (xml-escape (site-url site "/")))
    (format out "  <updated>~A</updated>~%"
            (format-iso-datetime
             (getf (page-metadata (first entries)) :timestamp)))
    (format out "  <author><name>~A</name></author>~%"
            (xml-escape (or (site-author site) (site-title site))))
    (dolist (entry entries)
      (write-entry out entry site))
    (format out "</feed>~%")))

(defun add-atom-feed (page-map site)
  "Return PAGE-MAP plus an Atom 1.0 feed of its most recent dated pages.

The feed lives at /atom.xml and lists as many pages as the RSS feed. The updated
date is the date of the newest entry, never the build time, so the output is
deterministic. When no page is dated the map is returned unchanged. Run this
before APPLY-LAYOUTS so the entry content is the rendered Markdown.

PAGE-MAP: the page map to extend.
SITE: the site being built."
  (let ((entries (newest-first (dated-pages (page-map-pages page-map)))))
    (if (null entries)
        page-map
        (with-added-pages
            page-map
          (list (make-page :path +atom-path+
                           :body (render-atom
                                  (subseq entries
                                          0
                                          (min +feed-item-limit+
                                               (length entries)))
                                  site)))))))
