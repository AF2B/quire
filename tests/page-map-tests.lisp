(defpackage #:quire/tests/page-map
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/conditions
                #:path-conflict
                #:path-conflict-output-path
                #:path-conflict-path
                #:path-conflict-reason)
  (:import-from #:quire/page
                #:make-page
                #:page-body
                #:page-path)
  (:import-from #:quire/page-map
                #:add-page
                #:find-page
                #:keep-existing
                #:make-page-map
                #:map-pages
                #:merge-page-maps
                #:page-map-count
                #:page-map-pages
                #:replace-existing
                #:skip-page)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/page-map)

(def-suite page-map-suite
  :description "Page map storage, ordering and conflict handling."
  :in quire-suite)

(in-suite page-map-suite)

(defun page-at (path &optional (body "x"))
  "Return a page at PATH whose body is BODY."
  (make-page :path path :body body))

(defun map-of (&rest paths)
  "Return a page map holding one page for each of PATHS, in the given order."
  (let ((page-map (make-page-map)))
    (dolist (path paths page-map)
      (add-page page-map (page-at path)))))

(defun add-resolving (page-map page restart-name)
  "Add PAGE to PAGE-MAP, resolving any path conflict with RESTART-NAME."
  (handler-bind ((path-conflict (lambda (condition)
                                  (declare (ignore condition))
                                  (invoke-restart restart-name))))
    (add-page page-map page)))

(defun conflict-reason-of (page-map page)
  "Return the reason adding PAGE to PAGE-MAP conflicts, or NIL when it does not."
  (handler-case (progn (add-page page-map page) nil)
    (path-conflict (condition) (path-conflict-reason condition))))

(test new-map-is-empty
  (is (zerop (page-map-count (make-page-map))))
  (is-false (page-map-pages (make-page-map))))

(test add-page-returns-the-map-and-stores-the-page
  (let* ((page-map (make-page-map))
         (page (page-at "/a/")))
    (is (eq page-map (add-page page-map page)))
    (is (= 1 (page-map-count page-map)))
    (is (eq page (find-page page-map "/a/")))))

(test find-page-returns-nil-when-absent
  (is-false (find-page (map-of "/a/") "/b/")))

(test find-page-resolves-through-the-output-path
  (let ((page-map (map-of "/a/")))
    (is (eq (find-page page-map "/a/")
            (find-page page-map "/a/index.html")))))

(test pages-are-ordered-by-path-whatever-the-insertion-order
  (let ((expected '("/" "/a/" "/a/b.html" "/feed.xml" "/z/")))
    (dolist (insertion-order '(("/" "/a/" "/a/b.html" "/feed.xml" "/z/")
                               ("/z/" "/feed.xml" "/a/b.html" "/a/" "/")
                               ("/feed.xml" "/" "/z/" "/a/" "/a/b.html")))
      (is (equal expected
                 (mapcar #'page-path
                         (page-map-pages (apply #'map-of insertion-order))))))))

(test map-pages-visits-pages-in-order
  (let ((visited '()))
    (map-pages (lambda (page) (push (page-path page) visited))
               (map-of "/b/" "/a/"))
    (is (equal '("/a/" "/b/") (nreverse visited)))))

(test duplicate-path-signals-a-same-output-conflict
  (let ((page-map (map-of "/a/")))
    (is (eq :same-output (conflict-reason-of page-map (page-at "/a/"))))))

(test directory-and-index-file-share-an-output-path
  (let ((page-map (map-of "/a/")))
    (is (eq :same-output
            (conflict-reason-of page-map (page-at "/a/index.html"))))))

(test conflict-condition-reports-both-views-of-the-path
  (let ((page-map (map-of "/a/")))
    (handler-case (add-page page-map (page-at "/a/index.html"))
      (path-conflict (condition)
        (is (string= "/a/index.html" (path-conflict-path condition)))
        (is (string= "a/index.html"
                     (path-conflict-output-path condition)))))))

(test keep-existing-restart-retains-the-first-page
  (let ((page-map (make-page-map)))
    (add-page page-map (page-at "/a/" "first"))
    (add-resolving page-map (page-at "/a/" "second") 'keep-existing)
    (is (= 1 (page-map-count page-map)))
    (is (string= "first" (page-body (find-page page-map "/a/"))))))

(test replace-existing-restart-retains-the-last-page
  (let ((page-map (make-page-map)))
    (add-page page-map (page-at "/a/" "first"))
    (add-resolving page-map (page-at "/a/" "second") 'replace-existing)
    (is (= 1 (page-map-count page-map)))
    (is (string= "second" (page-body (find-page page-map "/a/"))))))

(test skip-page-restart-leaves-the-map-unchanged
  (let ((page-map (map-of "/a/")))
    (add-resolving page-map (page-at "/a/" "second") 'skip-page)
    (is (= 1 (page-map-count page-map)))
    (is (string= "x" (page-body (find-page page-map "/a/"))))))

(test file-colliding-with-an-existing-directory-is-a-conflict
  (let ((page-map (map-of "/a.html/")))
    (is (eq :file-directory
            (conflict-reason-of page-map (page-at "/a.html"))))))

(test directory-colliding-with-an-existing-file-is-a-conflict
  (let ((page-map (map-of "/a.html")))
    (is (eq :file-directory
            (conflict-reason-of page-map (page-at "/a.html/"))))))

(test file-below-an-existing-file-is-a-conflict
  (let ((page-map (map-of "/a.html")))
    (is (eq :file-directory
            (conflict-reason-of page-map (page-at "/a.html/b.html"))))))

(test only-skip-page-resolves-a-file-directory-conflict
  (let ((page-map (map-of "/a.html")))
    (signals control-error
      (add-resolving page-map (page-at "/a.html/") 'keep-existing))
    (signals control-error
      (add-resolving page-map (page-at "/a.html/") 'replace-existing))
    (add-resolving page-map (page-at "/a.html/") 'skip-page)
    (is (= 1 (page-map-count page-map)))))

(test sibling-paths-do-not-conflict
  (let ((page-map (map-of "/a/" "/a.html" "/a/b/" "/a/c.html")))
    (is (= 4 (page-map-count page-map)))))

(test merge-returns-a-new-map-and-leaves-inputs-untouched
  (let* ((first (map-of "/a/"))
         (second (map-of "/b/"))
         (merged (merge-page-maps first second)))
    (is (= 2 (page-map-count merged)))
    (is (= 1 (page-map-count first)))
    (is (= 1 (page-map-count second)))
    (is (not (eq merged first)))))

(test merge-propagates-conflicts
  (signals path-conflict
    (merge-page-maps (map-of "/a/") (map-of "/a/"))))

(test merge-conflicts-can-be-resolved-with-restarts
  (let ((merged (handler-bind ((path-conflict
                                 (lambda (condition)
                                   (declare (ignore condition))
                                   (invoke-restart 'skip-page))))
                  (merge-page-maps (map-of "/a/") (map-of "/a/" "/b/")))))
    (is (= 2 (page-map-count merged)))))

(test merge-with-no-maps-is-empty
  (is (zerop (page-map-count (merge-page-maps)))))
