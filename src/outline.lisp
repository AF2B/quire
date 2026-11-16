(defpackage #:quire/outline
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/page
                #:copy-page
                #:page-body
                #:page-metadata)
  (:import-from #:quire/page-map
                #:add-page
                #:make-page-map
                #:page-map-pages)
  (:import-from #:quire/steps
                #:slugify)
  (:export #:add-heading-anchors
           #:add-reading-time
           #:anchor-headings
           #:html->text
           #:reading-minutes))

(in-package #:quire/outline)

(defconstant +words-per-minute+ 200
  "Reading speed used to estimate the reading time of a page.")

(defconstant +shallowest-heading+ 2
  "Smallest heading level that gets an anchor: h1 is the page title.")

(defconstant +deepest-heading+ 3
  "Largest heading level that gets an anchor.")

(define-constant +anchor-fallback+ "section"
  :test #'string=
  :documentation "Id given to a heading whose text has no letter or digit.")

(define-constant +entities+
  '(("&amp;" . "&") ("&lt;" . "<") ("&gt;" . ">") ("&quot;" . "\"")
    ("&#39;" . "'"))
  :test #'equal
  :documentation "Character references that HTML->TEXT turns back into text.")

(defun replace-all (text old new)
  "Return TEXT with every occurrence of OLD replaced by NEW.

TEXT: the string to scan.
OLD: the substring to replace.
NEW: the replacement."
  (with-output-to-string (out)
    (loop with start = 0
          for hit = (search old text :start2 start)
          do (write-string text out :start start :end hit)
          while hit
          do (write-string new out)
             (setf start (+ hit (length old))))))

(defun strip-tags (html)
  "Return HTML without its tags, keeping the text between them.

HTML: an HTML fragment."
  (with-output-to-string (out)
    (loop with inside-tag = nil
          for character across html
          do (cond ((char= character #\<) (setf inside-tag t))
                   ((char= character #\>) (setf inside-tag nil))
                   ((not inside-tag) (write-char character out))))))

(defun html->text (html)
  "Return the plain text of the HTML fragment HTML.

Tags are dropped and the common character references are decoded.

HTML: an HTML fragment."
  (let ((text (strip-tags html)))
    (dolist (entity +entities+ text)
      (setf text (replace-all text (car entity) (cdr entity))))))

(defun heading-open-at (html start)
  "Return the level of the heading whose opening tag starts at START, or NIL.

HTML: the fragment being scanned.
START: index of a #\< character."
  (when (and (< (+ start 3) (length html))
             (char= #\h (char html (1+ start)))
             (digit-char-p (char html (+ start 2)))
             (member (char html (+ start 3)) '(#\> #\Space)))
    (let ((level (digit-char-p (char html (+ start 2)))))
      (when (<= +shallowest-heading+ level +deepest-heading+)
        level))))

(defun unique-id (base seen)
  "Return BASE, or BASE with a number when SEEN already holds it, and record it.

BASE: the wanted id.
SEEN: hash table of the ids used so far on the page."
  (let ((id base)
        (count 1))
    (loop while (gethash id seen)
          do (setf id (format nil "~A-~D" base (incf count))))
    (setf (gethash id seen) t)
    id))

(defun existing-id (open-tag)
  "Return the id attribute written in OPEN-TAG, or NIL.

OPEN-TAG: the text of an opening tag, such as \"<h2 id=\\\"a\\\">\"."
  (let ((marker (search " id=\"" open-tag)))
    (when marker
      (let* ((start (+ marker (length " id=\"")))
             (end (position #\" open-tag :start start)))
        (when end (subseq open-tag start end))))))

(defun anchor-headings (html)
  "Return HTML with an id on every h2 and h3, and the outline those make.

Returns two values: the new HTML and a list of (LEVEL ID TEXT), in document
order. An id already written in the heading is kept. Other ids come from the
text of the heading, with a number added when two headings would share one.

HTML: the HTML fragment of a page body."
  (let ((seen (make-hash-table :test 'equal))
        (outline '()))
    (values
     (with-output-to-string (out)
       (loop with position = 0
             for open = (position #\< html :start position)
             do (write-string html out :start position :end open)
             while open
             do (let* ((level (heading-open-at html open))
                       (open-end (and level (position #\> html :start open)))
                       (close-tag (and level (format nil "</h~D>" level)))
                       (close (and open-end
                                   (search close-tag html :start2 open-end))))
                  (cond (close
                         (let* ((open-tag (subseq html open (1+ open-end)))
                                (inner (subseq html (1+ open-end) close))
                                (text (html->text inner))
                                (id (or (existing-id open-tag)
                                        (unique-id
                                         (let ((slug (slugify text)))
                                           (if (plusp (length slug))
                                               slug
                                               +anchor-fallback+))
                                         seen))))
                           (push (list level id text) outline)
                           (if (existing-id open-tag)
                               (write-string open-tag out)
                               (format out "<h~D id=\"~A\">" level id))
                           (write-string inner out)
                           (write-string close-tag out)
                           (setf position (+ close (length close-tag)))))
                        (t
                         (write-char #\< out)
                         (setf position (1+ open)))))))
     (nreverse outline))))

(defun transform-bodies (page-map function)
  "Return PAGE-MAP with FUNCTION applied to every page that has a text body.

PAGE-MAP: the page map to transform.
FUNCTION: called with a page whose body is a string and which has a :LAYOUT;
  it returns the page that replaces it."
  (let ((result (make-page-map)))
    (dolist (page (page-map-pages page-map) result)
      (add-page result
                (if (and (stringp (page-body page))
                         (getf (page-metadata page) :layout))
                    (funcall function page)
                    page)))))

(defun add-heading-anchors (page-map site)
  "Return PAGE-MAP with ids on the h2 and h3 of every page body.

Each page also gets :TOC, a list of (LEVEL ID TEXT) that a layout can render as
a table of contents. Run this before APPLY-LAYOUTS.

PAGE-MAP: the page map to transform.
SITE: the site being built; unused, part of the step protocol."
  (declare (ignore site))
  (transform-bodies
   page-map
   (lambda (page)
     (multiple-value-bind (html outline) (anchor-headings (page-body page))
       (let ((metadata (copy-list (page-metadata page))))
         (setf (getf metadata :toc) outline)
         (copy-page page :body html :metadata metadata))))))

(defun remove-code-blocks (html)
  "Return HTML without its pre elements, so code is not counted as prose.

HTML: an HTML fragment."
  (with-output-to-string (out)
    (loop with position = 0
          for open = (search "<pre" html :start2 position)
          for close = (and open (search "</pre>" html :start2 open))
          do (write-string html out :start position :end open)
          while (and open close)
          do (setf position (+ close (length "</pre>"))))))

(defun reading-minutes (html)
  "Return the minutes needed to read HTML, at least 1.

Code blocks are not counted.

HTML: the HTML fragment of a page body."
  (let* ((text (html->text (remove-code-blocks html)))
         (words (loop with count = 0
                      with inside-word = nil
                      for character across text
                      do (if (member character '(#\Space #\Newline #\Tab
                                                 #\Return))
                             (setf inside-word nil)
                             (unless inside-word
                               (setf inside-word t)
                               (incf count)))
                      finally (return count))))
    (max 1 (ceiling words +words-per-minute+))))

(defun add-reading-time (page-map site)
  "Return PAGE-MAP with :READING-MINUTES set on every page with a text body.

PAGE-MAP: the page map to transform.
SITE: the site being built; unused, part of the step protocol."
  (declare (ignore site))
  (transform-bodies
   page-map
   (lambda (page)
     (let ((metadata (copy-list (page-metadata page))))
       (setf (getf metadata :reading-minutes)
             (reading-minutes (page-body page)))
       (copy-page page :metadata metadata)))))
