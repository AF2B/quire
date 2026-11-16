(defpackage #:quire/tests/series
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/page
                #:make-page
                #:page-metadata
                #:page-path)
  (:import-from #:quire/page-map
                #:add-page
                #:find-page
                #:make-page-map
                #:page-map-count)
  (:import-from #:quire/series
                #:add-series
                #:series-url-path)
  (:import-from #:quire/site
                #:make-site)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/series)

(def-suite series-suite
  :description "Series of posts: navigation and listing pages."
  :in quire-suite)

(in-suite series-suite)

(defvar *site* (make-site :title "Test"
                          :languages '((:code "en" :name "English")
                                       (:code "pt-br" :name "Portugues")))
  "A bilingual site.")

(defun part (path name number &rest metadata)
  "Return a post at PATH that is part NUMBER of the series NAME."
  (make-page :path path
             :body "x"
             :metadata (append (list :title path
                                     :layout :post
                                     :series name
                                     :part number)
                               metadata)))

(defun built (&rest pages)
  "Return the page map ADD-SERIES makes from PAGES."
  (let ((page-map (make-page-map)))
    (dolist (page pages)
      (add-page page-map page))
    (add-series page-map *site*)))

(defun metadata-of (page-map path)
  "Return the metadata of the page at PATH in PAGE-MAP."
  (page-metadata (find-page page-map path)))

(test series-url-paths-use-the-slug-and-the-language-prefix
  (is (string= "/series/the-condition-system/"
               (series-url-path "The condition system")))
  (is (string= "/pt-br/series/a/" (series-url-path "A" "/pt-br"))))

(test members-know-their-neighbours
  (let ((result (built (part "/posts/b/" "S" 2)
                       (part "/posts/a/" "S" 1)
                       (part "/posts/c/" "S" 3))))
    (is (null (getf (metadata-of result "/posts/a/") :series-previous)))
    (is (string= "/posts/b/" (getf (metadata-of result "/posts/a/") :series-next)))
    (is (string= "/posts/a/" (getf (metadata-of result "/posts/b/") :series-previous)))
    (is (string= "/posts/c/" (getf (metadata-of result "/posts/b/") :series-next)))
    (is (null (getf (metadata-of result "/posts/c/") :series-next)))))

(test the-total-comes-from-the-largest-declaration
  (let ((result (built (part "/posts/a/" "S" 1 :series-total 5)
                       (part "/posts/b/" "S" 2))))
    (is (= 5 (getf (metadata-of result "/posts/a/") :series-total)))
    (is (= 2 (getf (metadata-of result "/posts/a/") :series-published)))))

(test the-total-is-never-below-the-highest-part
  (is (= 4 (getf (metadata-of (built (part "/posts/a/" "S" 4)) "/posts/a/")
                 :series-total))))

(test a-series-page-and-a-listing-are-added
  (let* ((result (built (part "/posts/a/" "My Series" 1)
                        (part "/posts/b/" "My Series" 2)))
         (series (find-page result "/series/my-series/")))
    (is-true series)
    (is (eq :series (getf (page-metadata series) :layout)))
    (is (equal '("/posts/a/" "/posts/b/")
               (getf (page-metadata series) :series-paths)))
    (is (eq :series-index
            (getf (metadata-of result "/series/") :layout)))))

(test series-do-not-cross-languages
  (let ((result (built (part "/posts/a/" "S" 1)
                       (part "/pt-br/posts/a/" "S" 1))))
    (is-true (find-page result "/series/s/"))
    (is-true (find-page result "/pt-br/series/s/"))
    (is-true (find-page result "/pt-br/series/"))
    (is (null (getf (metadata-of result "/posts/a/") :series-next)))))

(test a-site-without-series-is-returned-unchanged
  (let ((page-map (make-page-map)))
    (add-page page-map (make-page :path "/a/" :body "x"))
    (is (eq page-map (add-series page-map *site*)))))

(test pages-with-a-series-but-no-part-are-ignored
  (let ((result (built (make-page :path "/a/"
                                  :body "x"
                                  :metadata '(:series "S")))))
    (is (= 1 (page-map-count result)))))
