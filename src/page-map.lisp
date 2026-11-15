(defpackage #:quire/page-map
  (:use #:cl)
  (:import-from #:quire/conditions
                #:path-conflict)
  (:import-from #:quire/page
                #:page
                #:page-path)
  (:import-from #:quire/paths
                #:+path-separator+
                #:path->output-path)
  (:export #:page-map
           #:make-page-map
           #:add-page
           #:find-page
           #:map-pages
           #:page-map-count
           #:page-map-pages
           #:merge-page-maps
           #:keep-existing
           #:replace-existing
           #:skip-page))

(in-package #:quire/page-map)

(defclass page-map ()
  ((files :initform (make-hash-table :test 'equal)
          :reader files
          :documentation "Output path to page.")
   (directories :initform (make-hash-table :test 'equal)
                :reader directories
                :documentation "Set of output paths that act as directories."))
  (:documentation "Pages of a site, keyed by the output path they write to.
Iteration is always sorted by URL path, never by insertion order."))

(defun make-page-map ()
  "Return a new, empty page map."
  (make-instance 'page-map))

(defun page-map-count (page-map)
  "Return the number of pages stored in PAGE-MAP.

PAGE-MAP: the page map to count."
  (hash-table-count (files page-map)))

(defun ancestor-directories (output-path)
  "Return the directory prefixes of OUTPUT-PATH, shallowest first.

OUTPUT-PATH: a relative output path; \"a/b/c.html\" yields (\"a\" \"a/b\")."
  (loop for position = (position +path-separator+ output-path)
          then (position +path-separator+ output-path :start (1+ position))
        while position
        collect (subseq output-path 0 position)))

(defun find-conflict (page-map output-path)
  "Return the reason OUTPUT-PATH cannot be added to PAGE-MAP, or NIL.

The reason is :SAME-OUTPUT when a page already writes to OUTPUT-PATH, and
:FILE-DIRECTORY when OUTPUT-PATH would be both a file and a directory.

PAGE-MAP: the page map to check.
OUTPUT-PATH: the relative output path the new page would write to."
  (let ((files (files page-map)))
    (cond ((gethash output-path files)
           :same-output)
          ((gethash output-path (directories page-map))
           :file-directory)
          ((some (lambda (ancestor) (gethash ancestor files))
                 (ancestor-directories output-path))
           :file-directory))))

(defun store-page (page-map output-path page)
  "Store PAGE under OUTPUT-PATH and register its ancestor directories.

PAGE-MAP: the page map to modify.
OUTPUT-PATH: the relative output path of PAGE.
PAGE: the page to store."
  (setf (gethash output-path (files page-map)) page)
  (dolist (ancestor (ancestor-directories output-path))
    (setf (gethash ancestor (directories page-map)) t)))

(defun add-page (page-map page)
  "Add PAGE to PAGE-MAP and return PAGE-MAP.

Signals PATH-CONFLICT when PAGE collides with a stored page. Restarts:
SKIP-PAGE drops PAGE; KEEP-EXISTING and REPLACE-EXISTING, offered only for a
:SAME-OUTPUT conflict, keep the stored page or store PAGE in its place.

PAGE-MAP: the page map to modify.
PAGE: the page to add."
  (check-type page-map page-map)
  (check-type page page)
  (let* ((output-path (path->output-path (page-path page)))
         (reason (find-conflict page-map output-path)))
    (if (null reason)
        (store-page page-map output-path page)
        ;; The restart tests close over REASON because a restart found by
        ;; name receives NIL instead of the condition (CLHS 9.1.4.2).
        (restart-case (error 'path-conflict
                             :path (page-path page)
                             :output-path output-path
                             :reason reason)
          (skip-page ()
            :report "Skip the new page."
            nil)
          (keep-existing ()
            :report "Keep the page already stored."
            :test (lambda (condition)
                    (declare (ignore condition))
                    (eq :same-output reason))
            nil)
          (replace-existing ()
            :report "Replace the stored page with the new one."
            :test (lambda (condition)
                    (declare (ignore condition))
                    (eq :same-output reason))
            (store-page page-map output-path page))))
    page-map))

(defun find-page (page-map path)
  "Return the page of PAGE-MAP that writes to the output of PATH, or NIL.

PAGE-MAP: the page map to search.
PATH: URL path; \"/a/\" and \"/a/index.html\" find the same page."
  (values (gethash (path->output-path path) (files page-map))))

(defun page-map-pages (page-map)
  "Return the pages of PAGE-MAP as a list sorted by URL path.

The order depends only on the paths, never on insertion order, so builds are
deterministic. Paths are unique within a map, so the order is total.

PAGE-MAP: the page map to list."
  (sort (loop for page being the hash-values of (files page-map)
              collect page)
        #'string<
        :key #'page-path))

(defun map-pages (function page-map)
  "Call FUNCTION on each page of PAGE-MAP, sorted by URL path. Return NIL.

FUNCTION: a function of one argument, the page.
PAGE-MAP: the page map to traverse."
  (mapc function (page-map-pages page-map))
  nil)

(defun merge-page-maps (&rest page-maps)
  "Return a new page map with the pages of every one of PAGE-MAPS.

The inputs are not modified. Conflicts signal PATH-CONFLICT and offer the
same restarts as ADD-PAGE.

PAGE-MAPS: the page maps to merge, in priority order."
  (let ((merged (make-page-map)))
    (dolist (page-map page-maps merged)
      (map-pages (lambda (page) (add-page merged page))
                 page-map))))
