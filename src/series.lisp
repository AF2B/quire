(defpackage #:quire/series
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/languages
                #:language-codes
                #:language-prefix
                #:page-language)
  (:import-from #:quire/page
                #:copy-page
                #:make-page
                #:page-metadata
                #:page-path)
  (:import-from #:quire/page-map
                #:add-page
                #:find-page
                #:make-page-map
                #:page-map-pages)
  (:import-from #:quire/steps
                #:slugify)
  (:export #:+series-section-path+
           #:add-series
           #:series-url-path))

(in-package #:quire/series)

(define-constant +series-section-path+ "/series/"
  :test #'string=
  :documentation "URL path of the page that lists every series.")

(defun series-url-path (name &optional (prefix ""))
  "Return the URL path of the page of the series NAME.

NAME: the series name; \"The condition system\" yields
  \"/series/the-condition-system/\".
PREFIX: language prefix such as \"/pt-br\"; empty for the default language."
  (concatenate 'string prefix +series-section-path+ (slugify name) "/"))

(defun series-member-p (page)
  "Return true when PAGE declares a series and a part number.

PAGE: the page to inspect."
  (let ((metadata (page-metadata page)))
    (and (getf metadata :series) (getf metadata :part))))

(defun part-of (page)
  "Return the part number of PAGE.

PAGE: a series member."
  (getf (page-metadata page) :part))

(defun group-key (site page)
  "Return the key that groups PAGE with the other parts of its series.

SITE: the site being built.
PAGE: a series member."
  (cons (page-language site page)
        (getf (page-metadata page) :series)))

(defun series-groups (site pages)
  "Return the series of PAGES as a list of (KEY . MEMBERS).

Members are sorted by part, then by path. Groups are sorted by key, so the
result does not depend on the order of PAGES.

SITE: the site being built.
PAGES: every page of the site."
  (let ((table (make-hash-table :test 'equal))
        (groups '()))
    (dolist (page (remove-if-not #'series-member-p pages))
      (push page (gethash (group-key site page) table)))
    (maphash (lambda (key members)
               (push (cons key
                           (sort members
                                 (lambda (first second)
                                   (if (/= (part-of first) (part-of second))
                                       (< (part-of first) (part-of second))
                                       (string< (page-path first)
                                                (page-path second))))))
                     groups))
             table)
    (sort groups
          (lambda (first second)
            (or (string< (car (car first)) (car (car second)))
                (and (string= (car (car first)) (car (car second)))
                     (string< (cdr (car first)) (cdr (car second)))))))))

(defun declared-total (members)
  "Return the number of parts the series of MEMBERS will have.

It is the largest of the :SERIES-TOTAL values written by the members, the
highest part number and the number of members.

MEMBERS: the pages of one series."
  (max (length members)
       (reduce #'max members :key #'part-of)
       (reduce #'max members
               :key (lambda (page)
                      (or (getf (page-metadata page) :series-total) 0)))))

(defun annotate-member (page members total series-path)
  "Return PAGE with its place in the series written in its metadata.

Sets :SERIES-PATH, :SERIES-TOTAL, :SERIES-PUBLISHED, :SERIES-PREVIOUS and
:SERIES-NEXT; the last two are paths, or NIL at either end.

PAGE: one member of the series.
MEMBERS: every member, in order.
TOTAL: the number of parts the series will have.
SERIES-PATH: URL path of the page of the series."
  (let* ((index (position page members))
         (metadata (copy-list (page-metadata page))))
    (setf (getf metadata :series-path) series-path
          (getf metadata :series-total) total
          (getf metadata :series-published) (length members)
          (getf metadata :series-previous)
          (when (plusp index) (page-path (nth (1- index) members)))
          (getf metadata :series-next)
          (when (< (1+ index) (length members))
            (page-path (nth (1+ index) members))))
    (copy-page page :metadata metadata)))

(defun add-series (page-map site)
  "Return PAGE-MAP with series navigation and the pages that list the series.

Pages that set :SERIES (a name) and :PART (a number) form a series within their
language. Each member gets its neighbours and the size of the series in its
metadata. A page per series (layout :SERIES) and, per language, a listing
(layout :SERIES-INDEX) at /series/ are added, unless the path is taken. A site
without series is returned unchanged.

PAGE-MAP: the page map to transform.
SITE: the site being built."
  (let* ((pages (page-map-pages page-map))
         (groups (series-groups site pages)))
    (if (null groups)
        page-map
        (let ((result (make-page-map))
              (replacements (make-hash-table :test 'eq))
              (added '()))
          (loop for ((code . name) . members) in groups
                for prefix = (language-prefix site code)
                for path = (series-url-path name prefix)
                for total = (declared-total members)
                do (dolist (member members)
                     (setf (gethash member replacements)
                           (annotate-member member members total path)))
                   (unless (find-page page-map path)
                     (push (make-page :path path
                                      :body ""
                                      :metadata (list :title name
                                                      :layout :series
                                                      :series name
                                                      :series-paths
                                                      (mapcar #'page-path
                                                              members)
                                                      :series-total total))
                           added)))
          (dolist (page pages)
            (add-page result (gethash page replacements page)))
          (dolist (code (language-codes site))
            (let ((path (concatenate 'string
                                     (language-prefix site code)
                                     +series-section-path+)))
              (when (and (find code groups :key #'caar :test #'string=)
                         (not (find-page result path)))
                (push (make-page :path path
                                 :body ""
                                 :metadata (list :title "Series"
                                                 :layout :series-index))
                      added))))
          (dolist (page (nreverse added) result)
            (add-page result page))))))
