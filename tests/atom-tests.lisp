(defpackage #:quire/tests/atom
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/atom
                #:add-atom-feed)
  (:import-from #:quire/dates
                #:format-iso-date
                #:parse-date)
  (:import-from #:quire/feed
                #:+feed-item-limit+)
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

(in-package #:quire/tests/atom)

(def-suite atom-suite
  :description "Atom feed generation."
  :in quire-suite)

(in-suite atom-suite)

(defvar *site* (make-site :title "My & Site"
                          :description "About <things>"
                          :base-url "https://example.com/"
                          :language "pt-BR"
                          :author "Ana")
  "The site the feeds are built for.")

(defun post (path title date)
  "Return a dated post at PATH."
  (make-page :path path
             :body "<p>Hello & <b>bye</b></p>"
             :metadata (list :title title
                             :layout :post
                             :timestamp (parse-date date))))

(defun atom-of (&rest pages)
  "Return the text of the Atom feed built from PAGES, or NIL when there is none."
  (let ((page-map (make-page-map)))
    (dolist (page pages)
      (add-page page-map page))
    (let ((page (find-page (add-atom-feed page-map *site*) "/atom.xml")))
      (and page (page-body page)))))

(defun count-of (needle haystack)
  "Return how many times NEEDLE occurs in HAYSTACK."
  (loop with start = 0
        for position = (search needle haystack :start2 start)
        while position
        count t
        do (setf start (1+ position))))

(test no-dated-pages-means-no-atom-feed
  (is-false (atom-of (make-page :path "/a/" :body "x"))))

(test feed-describes-the-site
  (let ((feed (atom-of (post "/a/" "A" "2026-01-01"))))
    (is-true (search "<feed xmlns=\"http://www.w3.org/2005/Atom\" xml:lang=\"pt-BR\">"
                     feed))
    (is-true (search "<title>My &amp; Site</title>" feed))
    (is-true (search "<subtitle>About &lt;things&gt;</subtitle>" feed))
    (is-true (search "rel=\"self\" type=\"application/atom+xml\" href=\"https://example.com/atom.xml\""
                     feed))
    (is-true (search "<author><name>Ana</name></author>" feed))))

(test entries-are-newest-first-with-id-date-and-escaped-content
  (let* ((feed (atom-of (post "/old/" "Old" "2026-01-01")
                        (post "/new/" "Tom & Jerry" "2026-03-01")))
         (new (search "<id>https://example.com/new/</id>" feed))
         (old (search "<id>https://example.com/old/</id>" feed)))
    (is-true (and new old (< new old)))
    (is-true (search "<title>Tom &amp; Jerry</title>" feed))
    (is-true (search "<updated>2026-03-01T00:00:00Z</updated>" feed))
    (is-true (search "&lt;p&gt;Hello &amp; &lt;b&gt;bye&lt;/b&gt;&lt;/p&gt;" feed))))

(test feed-updated-is-the-newest-entry-date-not-the-build-time
  (is-true (search "<updated>2026-03-01T00:00:00Z</updated>
  <author>"
                   (atom-of (post "/a/" "A" "2026-01-01")
                            (post "/b/" "B" "2026-03-01")))))

(test feed-lists-at-most-the-item-limit
  (let ((feed (apply #'atom-of
                     (loop for day from 1 to (+ +feed-item-limit+ 5)
                           collect (post (format nil "/p~D/" day)
                                         (format nil "P~D" day)
                                         (format-iso-date
                                          (+ (parse-date "2026-01-01")
                                             (* day 86400))))))))
    (is (= +feed-item-limit+ (count-of "<entry>" feed)))))

(test feed-is-deterministic
  (let ((pages (list (post "/a/" "A" "2026-01-01")
                     (post "/b/" "B" "2026-01-01"))))
    (is (string= (apply #'atom-of pages) (apply #'atom-of (reverse pages))))))

(test author-defaults-to-the-site-title
  (let ((feed (let ((*site* (make-site :title "Solo"
                                       :base-url "https://example.com")))
                (atom-of (post "/a/" "A" "2026-01-01")))))
    (is-true (search "<author><name>Solo</name></author>" feed))))
