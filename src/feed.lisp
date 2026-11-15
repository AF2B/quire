(defpackage #:quire/feed
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/dates
                #:format-rfc-822)
  (:import-from #:quire/page
                #:make-page
                #:page-body
                #:page-metadata
                #:page-path)
  (:import-from #:quire/page-map
                #:page-map-pages)
  (:import-from #:quire/site
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
  (:export #:+feed-item-limit+
           #:+feed-path+
           #:add-feed))

(in-package #:quire/feed)

(define-constant +feed-path+ "/feed.xml"
  :test #'string=
  :documentation "URL path of the generated RSS feed.")

(defconstant +feed-item-limit+ 20
  "Most recent pages that the feed lists.")

(defun write-item (out page site)
  "Write the RSS item element of PAGE to the stream OUT.

OUT: the output stream.
PAGE: a dated page.
SITE: the site being built."
  (let ((metadata (page-metadata page))
        (link (xml-escape (site-url site (page-path page)))))
    (format out "    <item>~%")
    (format out "      <title>~A</title>~%" (xml-escape (getf metadata :title)))
    (format out "      <link>~A</link>~%" link)
    (format out "      <guid isPermaLink=\"true\">~A</guid>~%" link)
    (format out "      <pubDate>~A</pubDate>~%"
            (format-rfc-822 (getf metadata :timestamp)))
    (when (stringp (page-body page))
      (format out "      <description>~A</description>~%"
              (xml-escape (page-body page))))
    (format out "    </item>~%")))

(defun render-feed (items site)
  "Return the RSS 2.0 document, as a string, that lists ITEMS.

ITEMS: dated pages, newest first.
SITE: the site being built."
  (with-output-to-string (out)
    (format out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%")
    (format out "<rss version=\"2.0\" ~
                 xmlns:atom=\"http://www.w3.org/2005/Atom\">~%")
    (format out "  <channel>~%")
    (format out "    <title>~A</title>~%" (xml-escape (site-title site)))
    (format out "    <link>~A</link>~%" (xml-escape (site-url site "/")))
    (format out "    <description>~A</description>~%"
            (xml-escape (site-description site)))
    (format out "    <language>~A</language>~%" (xml-escape (site-language site)))
    (format out "    <lastBuildDate>~A</lastBuildDate>~%"
            (format-rfc-822 (getf (page-metadata (first items)) :timestamp)))
    (format out "    <atom:link href=\"~A\" rel=\"self\" ~
                 type=\"application/rss+xml\"/>~%"
            (xml-escape (site-url site +feed-path+)))
    (dolist (item items)
      (write-item out item site))
    (format out "  </channel>~%</rss>~%")))

(defun add-feed (page-map site)
  "Return PAGE-MAP plus an RSS feed of its most recent dated pages.

The feed lives at /feed.xml. The date written as lastBuildDate is the date of
the newest item, never the build time, so the output is deterministic. When no
page is dated the map is returned unchanged. Run this before APPLY-LAYOUTS so
the item descriptions are the rendered Markdown.

PAGE-MAP: the page map to extend.
SITE: the site being built."
  (let ((items (newest-first (dated-pages (page-map-pages page-map)))))
    (if (null items)
        page-map
        (with-added-pages
            page-map
          (list (make-page :path +feed-path+
                           :body (render-feed
                                  (subseq items
                                          0
                                          (min +feed-item-limit+
                                               (length items)))
                                  site)))))))
