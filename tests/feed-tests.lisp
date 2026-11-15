(defpackage #:quire/tests/feed
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/dates
                #:format-iso-date
                #:parse-date)
  (:import-from #:quire/feed
                #:+feed-item-limit+
                #:add-feed)
  (:import-from #:quire/page
                #:make-page
                #:page-body)
  (:import-from #:quire/page-map
                #:add-page
                #:find-page
                #:make-page-map)
  (:import-from #:quire/site
                #:make-site)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/feed)

(def-suite feed-suite
  :description "RSS feed generation."
  :in quire-suite)

(in-suite feed-suite)

(defvar *site* (make-site :title "My & Site"
                          :description "About <things>"
                          :base-url "https://example.com/"
                          :language "pt-BR")
  "The site the feeds are built for.")

(defun post (path title date)
  "Return a dated post at PATH."
  (make-page :path path
             :body "<p>Hello & <b>bye</b></p>"
             :metadata (list :title title
                             :layout :post
                             :timestamp (parse-date date))))

(defun feed-of (&rest pages)
  "Return the text of the feed built from PAGES, or NIL when there is none."
  (let ((page-map (make-page-map)))
    (dolist (page pages)
      (add-page page-map page))
    (let ((page (find-page (add-feed page-map *site*) "/feed.xml")))
      (and page (page-body page)))))

(defun count-of (needle haystack)
  "Return how many times NEEDLE occurs in HAYSTACK."
  (loop with start = 0
        for position = (search needle haystack :start2 start)
        while position
        count t
        do (setf start (1+ position))))

(test no-dated-pages-means-no-feed
  (is-false (feed-of (make-page :path "/a/" :body "x"))))

(test channel-describes-the-site
  (let ((feed (feed-of (post "/a/" "A" "2026-01-01"))))
    (is-true (search "<title>My &amp; Site</title>" feed))
    (is-true (search "<link>https://example.com/</link>" feed))
    (is-true (search "<description>About &lt;things&gt;</description>" feed))
    (is-true (search "<language>pt-BR</language>" feed))
    (is-true (search "href=\"https://example.com/feed.xml\"" feed))))

(test items-are-newest-first-with-absolute-links
  (let* ((feed (feed-of (post "/old/" "Old" "2026-01-01")
                        (post "/new/" "New" "2026-03-01")))
         (new (search "https://example.com/new/" feed))
         (old (search "https://example.com/old/" feed)))
    (is-true (and new old (< new old)))))

(test item-carries-date-guid-and-escaped-content
  (let ((feed (feed-of (post "/a/" "Tom & Jerry" "2026-11-14"))))
    (is-true (search "<title>Tom &amp; Jerry</title>" feed))
    (is-true (search "<pubDate>Sat, 14 Nov 2026 00:00:00 +0000</pubDate>" feed))
    (is-true (search "<guid isPermaLink=\"true\">https://example.com/a/</guid>"
                     feed))
    (is-true (search "&lt;p&gt;Hello &amp; &lt;b&gt;bye&lt;/b&gt;&lt;/p&gt;"
                     feed))))

(test last-build-date-is-the-newest-item-date
  (is-true (search "<lastBuildDate>Sun, 01 Mar 2026 00:00:00 +0000"
                   (feed-of (post "/a/" "A" "2026-01-01")
                            (post "/b/" "B" "2026-03-01")))))

(test feed-lists-at-most-the-item-limit
  (let ((feed (apply #'feed-of
                     (loop for day from 1 to (+ +feed-item-limit+ 5)
                           collect (post (format nil "/p~D/" day)
                                         (format nil "P~D" day)
                                         (format-iso-date
                                          (+ (parse-date "2026-01-01")
                                             (* day 86400))))))))
    (is (= +feed-item-limit+ (count-of "<item>" feed)))))

(test feed-is-deterministic
  (let ((pages (list (post "/a/" "A" "2026-01-01")
                     (post "/b/" "B" "2026-01-01"))))
    (is (string= (apply #'feed-of pages) (apply #'feed-of (reverse pages))))))
