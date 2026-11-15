(defpackage #:quire/steps
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/conditions
                #:unknown-layout)
  (:import-from #:quire/page
                #:copy-page
                #:make-page
                #:page-metadata
                #:page-path)
  (:import-from #:quire/page-map
                #:add-page
                #:find-page
                #:make-page-map
                #:merge-page-maps
                #:page-map-pages)
  (:import-from #:quire/site
                #:site-layouts)
  (:export #:add-section-indexes
           #:add-tag-pages
           #:all-tags
           #:apply-layouts
           #:dated-pages
           #:newest-first
           #:pages-in-section
           #:pages-with-tag
           #:slugify
           #:tag-url-path
           #:with-added-pages))

(in-package #:quire/steps)

(define-constant +tags-section-path+ "/tags/"
  :test #'string=
  :documentation "URL path of the page that lists every tag.")

(defconstant +word-separator+ #\-
  "Separator written between the words of a slug.")

(defun with-added-pages (page-map pages)
  "Return a new page map holding the pages of PAGE-MAP plus PAGES.

PAGE-MAP is not modified. Conflicts signal PATH-CONFLICT with its restarts.

PAGE-MAP: the page map to extend.
PAGES: a list of pages to add."
  (let ((result (merge-page-maps page-map)))
    (dolist (page pages result)
      (add-page result page))))

(defun slugify (text)
  "Return TEXT as a lowercase slug of letters and digits joined by hyphens.

Letters keep their accents; every other run of characters becomes one hyphen
and hyphens never start or end the slug. \"Common Lisp!\" yields \"common-lisp\".

TEXT: the string to convert."
  (check-type text string)
  (let ((pending-separator nil)
        (started nil))
    (with-output-to-string (out)
      (loop for character across text
            do (cond ((alphanumericp character)
                      (when (and pending-separator started)
                        (write-char +word-separator+ out))
                      (write-char (char-downcase character) out)
                      (setf started t
                            pending-separator nil))
                     (t (setf pending-separator t)))))))

(defun tag-url-path (tag)
  "Return the URL path of the page that lists the pages tagged TAG.

TAG: the tag string; \"Common Lisp\" yields \"/tags/common-lisp/\"."
  (concatenate 'string +tags-section-path+ (slugify tag) "/"))

(defun page-timestamp (page)
  "Return the universal time of PAGE, or 0 when it has no date.

PAGE: the page to inspect."
  (or (getf (page-metadata page) :timestamp) 0))

(defun dated-pages (pages)
  "Return the pages of PAGES that have a date, keeping their order.

PAGES: a list of pages."
  (remove-if-not (lambda (page) (getf (page-metadata page) :timestamp))
                 pages))

(defun newest-first (pages)
  "Return a copy of PAGES sorted from the newest to the oldest.

Pages with the same date are ordered by path, so the result is deterministic.

PAGES: a list of pages."
  (sort (copy-list pages)
        (lambda (first second)
          (let ((first-time (page-timestamp first))
                (second-time (page-timestamp second)))
            (if (/= first-time second-time)
                (> first-time second-time)
                (string< (page-path first) (page-path second)))))))

(defun pages-in-section (pages section)
  "Return the pages of PAGES whose :SECTION is SECTION.

PAGES: a list of pages.
SECTION: the section name, such as \"posts\"."
  (remove-if-not (lambda (page)
                   (equal section (getf (page-metadata page) :section)))
                 pages))

(defun page-tags (page)
  "Return the tags of PAGE.

PAGE: the page to inspect."
  (getf (page-metadata page) :tags))

(defun pages-with-tag (pages tag)
  "Return the pages of PAGES tagged TAG.

PAGES: a list of pages.
TAG: the tag string."
  (remove-if-not (lambda (page) (member tag (page-tags page) :test #'string=))
                 pages))

(defun all-tags (pages)
  "Return every distinct tag used by PAGES, sorted alphabetically.

PAGES: a list of pages."
  (sort (remove-duplicates (loop for page in pages
                                 append (page-tags page))
                           :test #'string=)
        #'string<))

(defun add-section-indexes (page-map site)
  "Return PAGE-MAP plus a listing page for each section that has dated pages.

A section whose listing path already has a page, such as one written as
index.md, is left alone. Generated pages use the :INDEX layout.

PAGE-MAP: the page map to extend.
SITE: the site being built; unused, part of the step protocol."
  (declare (ignore site))
  (let* ((pages (page-map-pages page-map))
         (sections (sort (remove-duplicates
                          (loop for page in (dated-pages pages)
                                for section = (getf (page-metadata page)
                                                    :section)
                                when section collect section)
                          :test #'string=)
                         #'string<)))
    (with-added-pages
        page-map
      (loop for section in sections
            for path = (format nil "/~A/" section)
            unless (find-page page-map path)
              collect (make-page :path path
                                 :body ""
                                 :metadata (list :title
                                                 (string-capitalize section)
                                                 :layout :index
                                                 :section section))))))

(defun add-tag-pages (page-map site)
  "Return PAGE-MAP plus one page per tag and a page that lists the tags.

Tag pages use the :TAG layout and the listing uses :TAGS. Two tags with the
same slug collide and signal PATH-CONFLICT.

PAGE-MAP: the page map to extend.
SITE: the site being built; unused, part of the step protocol."
  (declare (ignore site))
  (let ((tags (all-tags (page-map-pages page-map))))
    (if (null tags)
        page-map
        (with-added-pages
            page-map
          (append (unless (find-page page-map +tags-section-path+)
                    (list (make-page :path +tags-section-path+
                                     :body ""
                                     :metadata (list :title "Tags"
                                                     :layout :tags))))
                  (loop for tag in tags
                        collect (make-page :path (tag-url-path tag)
                                           :body ""
                                           :metadata (list :title tag
                                                           :layout :tag
                                                           :tag tag))))))))

(defun find-layout (site layout page-path)
  "Return the function designator of LAYOUT on SITE.

Signals UNKNOWN-LAYOUT, with a USE-VALUE restart, when SITE does not define it.

SITE: the site whose layouts to search.
LAYOUT: the layout keyword.
PAGE-PATH: path of the page that asked for it, for the message."
  (or (getf (site-layouts site) layout)
      (restart-case (error 'unknown-layout :layout layout :page-path page-path)
        (use-value (designator)
          :report "Use another layout function."
          designator))))

(defun layout-page (page site pages)
  "Return PAGE with its body replaced by a function that renders its layout.

The layout is looked up again on every call, so redefining a layout function at
the REPL changes the next render. A page without :LAYOUT is returned as is.

PAGE: the page to wrap.
SITE: the site that defines the layouts.
PAGES: every page of the site, as the layouts see them."
  (let ((layout (getf (page-metadata page) :layout)))
    (if (null layout)
        page
        (let ((override (unless (getf (site-layouts site) layout)
                          (find-layout site layout (page-path page)))))
          (copy-page page
                     :body (lambda (rendered)
                             (declare (ignore rendered))
                             (funcall (or override
                                          (find-layout site
                                                       layout
                                                       (page-path page)))
                                      page
                                      site
                                      pages)))))))

(defun apply-layouts (page-map site)
  "Return PAGE-MAP with every page that has a :LAYOUT wrapped by that layout.

The layout function is called as (LAYOUT PAGE SITE PAGES) when the body is
resolved, not here, so a build is cheap and layouts stay live at the REPL.
This must be the last step.

PAGE-MAP: the page map to transform.
SITE: the site that defines the layouts."
  (let ((pages (page-map-pages page-map))
        (result (make-page-map)))
    (dolist (page pages result)
      (add-page result (layout-page page site pages)))))
