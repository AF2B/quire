(defpackage #:quire/check
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/conditions
                #:invalid-path)
  (:import-from #:quire/page
                #:page-path
                #:resolve-body)
  (:import-from #:quire/page-map
                #:find-page
                #:page-map-pages)
  (:import-from #:quire/paths
                #:+path-separator+
                #:path-directory-p)
  (:import-from #:quire/site
                #:site-link)
  (:export #:broken-link
           #:broken-link-href
           #:broken-link-page
           #:broken-link-reason
           #:check-links
           #:make-broken-link))

(in-package #:quire/check)

(define-constant +link-attributes+ '("href" "src")
  :test #'equal
  :documentation "Attributes whose value is a link to another page or file.")

(define-constant +html-suffix+ ".html"
  :test #'string=
  :documentation "Suffix of a page written as an HTML file.")

(define-constant +current-segment+ "."
  :test #'string=
  :documentation "Path segment that means the current directory.")

(define-constant +parent-segment+ ".."
  :test #'string=
  :documentation "Path segment that means the parent directory.")

(defstruct (broken-link (:constructor make-broken-link (page href reason)))
  "A link that does not lead to a page of the site.

PAGE: the URL path of the page that holds the link.
HREF: the link exactly as written.
REASON: :MISSING-PAGE when no page has the target path, or :OUTSIDE-BASE-PATH
when an absolute link ignores the path part of the base URL."
  (page "" :type string :read-only t)
  (href "" :type string :read-only t)
  (reason :missing-page :type keyword :read-only t))

(defun whitespace-p (character)
  "Return true when CHARACTER is HTML whitespace.

CHARACTER: the character to test."
  (member character '(#\Space #\Tab #\Newline #\Return #\Page)))

(defun attribute-value-end (html start)
  "Return the index where the attribute value that begins at START ends.

A value that starts with a quote ends at the matching quote; an unquoted value
ends at whitespace or at >.

HTML: the document text.
START: index of the first character after the equals sign."
  (let ((quote-character (and (< start (length html))
                              (find (char html start) "\"'"))))
    (if quote-character
        (or (position quote-character html :start (1+ start))
            (length html))
        (or (position-if (lambda (character)
                           (or (whitespace-p character)
                               (char= character #\>)))
                         html
                         :start start)
            (length html)))))

(defun attribute-value-start (html start)
  "Return the index of the first character of the value that begins at START.

HTML: the document text.
START: index of the first character after the equals sign."
  (if (and (< start (length html))
           (find (char html start) "\"'"))
      (1+ start)
      start))

(defun inside-tag-p (html index)
  "Return true when INDEX is inside an HTML tag, between < and >.

HTML: the document text.
INDEX: a position in HTML."
  (let ((open (position #\< html :end index :from-end t))
        (close (position #\> html :end index :from-end t)))
    (and open
         (or (null close)
             (< close open)))))

(defun link-at (html name-start name)
  "Return the end index and the value of the link attribute NAME at NAME-START.

Returns NIL when what follows is not NAME=, when NAME-START is in the middle of
a longer name such as data-href, or when it is not inside a tag.

HTML: the document text.
NAME-START: index where NAME was found.
NAME: the attribute name, lowercase."
  (let ((after-name (+ name-start (length name))))
    (when (and (plusp name-start)
               (whitespace-p (char html (1- name-start)))
               (inside-tag-p html name-start)
               (< after-name (length html))
               (char= #\= (char html after-name)))
      (let* ((after-equals (1+ after-name))
             (value-start (attribute-value-start html after-equals))
             (value-end (attribute-value-end html after-equals)))
        (cons value-end (subseq html value-start value-end))))))

(defun extract-links (html)
  "Return the values of every href and src attribute in HTML, in document order.

HTML: the document text."
  (let ((lowercase (string-downcase html))
        (links '()))
    (dolist (name +link-attributes+)
      (loop with start = 0
            for found = (search name lowercase :start2 start)
            while found
            do (let ((link (link-at html found name)))
                 (when link
                   (push (cons found (cdr link)) links))
                 (setf start (+ found (length name))))))
    (mapcar #'cdr (sort links #'< :key #'car))))

(defun external-link-p (href)
  "Return true when HREF leaves the site or points inside the current page.

That covers an empty value, a fragment, a link with a scheme such as https: or
mailto:, and a protocol-relative link.

HREF: the link as written."
  (or (zerop (length href))
      (char= #\# (char href 0))
      (eql 0 (search "//" href))
      (let ((colon (position #\: href)))
        (and colon
             (plusp colon)
             (alpha-char-p (char href 0))
             (every (lambda (character)
                      (or (alphanumericp character)
                          (find character "+-.")))
                    (subseq href 0 colon))))))

(defun strip-query-and-fragment (href)
  "Return HREF without its query string and fragment.

HREF: the link as written."
  (subseq href 0 (position-if (lambda (character) (find character "?#"))
                              href)))

(defun page-directory (path)
  "Return the directory that relative links on the page at PATH start from.

PATH: the URL path of a page; \"/a/b/\" yields \"/a/b/\", \"/a/b.html\" yields
\"/a/\"."
  (if (path-directory-p path)
      path
      (subseq path 0 (1+ (position +path-separator+ path :from-end t)))))

(defun normalize-path (path)
  "Return PATH with its . and .. segments resolved, or NIL above the root.

PATH: an absolute URL path, possibly with . and .. segments."
  (let ((stack '()))
    (dolist (segment (uiop:split-string path :separator (string +path-separator+)))
      (cond ((or (string= segment "")
                 (string= segment +current-segment+)))
            ((string= segment +parent-segment+)
             (if stack
                 (pop stack)
                 (return-from normalize-path nil)))
            (t (push segment stack))))
    (let ((joined (format nil "/~{~A~^/~}" (reverse stack))))
      (if (and (path-directory-p path)
               (string/= joined "/"))
          (concatenate 'string joined "/")
          joined))))

(defun base-prefix (site)
  "Return the path part of the base URL of SITE, without a trailing slash.

SITE: the site being checked."
  (string-right-trim (string +path-separator+) (site-link site "/")))

(defun target-path (href page-path prefix)
  "Return the site path HREF points at, or a reason keyword when it cannot.

The first value is the target path, or NIL; the second is NIL or
:OUTSIDE-BASE-PATH.

HREF: the link, already stripped of query and fragment.
PAGE-PATH: the URL path of the page that holds the link.
PREFIX: the path part of the base URL, such as \"/blog\" or \"\"."
  (cond ((char= +path-separator+ (char href 0))
         (cond ((zerop (length prefix))
                (values (normalize-path href) nil))
               ((or (string= href prefix)
                    (eql 0 (search (concatenate 'string prefix "/") href)))
                (values (normalize-path (subseq href (length prefix))) nil))
               (t (values nil :outside-base-path))))
        (t (values (normalize-path
                    (concatenate 'string (page-directory page-path) href))
                   nil))))

(defun page-exists-p (page-map path)
  "Return true when PAGE-MAP has a page at PATH, or at PATH plus a slash.

A path that is not a valid page path, such as /about, is still tried with a
trailing slash.

PATH: a normalized site path, or NIL.
PAGE-MAP: the page map to search."
  (flet ((present-p (candidate)
           (handler-case (and (find-page page-map candidate) t)
             (invalid-path () nil))))
    (and path
         (or (present-p path)
             (and (not (path-directory-p path))
                  (present-p (concatenate 'string
                                          path
                                          (string +path-separator+))))))))

(defun html-page-p (page)
  "Return true when PAGE is written as HTML.

PAGE: the page to inspect."
  (let ((path (page-path page)))
    (or (path-directory-p path)
        (let ((suffix-start (- (length path) (length +html-suffix+))))
          (and (plusp suffix-start)
               (string= +html-suffix+ path :start2 suffix-start))))))

(defun check-page (page page-map prefix)
  "Return the broken links of PAGE.

PAGE: an HTML page.
PAGE-MAP: the page map the links must resolve in.
PREFIX: the path part of the base URL."
  (let ((body (resolve-body page))
        (broken '()))
    (when (stringp body)
      (dolist (href (extract-links body))
        (unless (external-link-p href)
          (let ((stripped (strip-query-and-fragment href)))
            (unless (zerop (length stripped))
              (multiple-value-bind (target reason)
                  (target-path stripped (page-path page) prefix)
                (cond (reason
                       (push (make-broken-link (page-path page) href reason)
                             broken))
                      ((not (page-exists-p page-map target))
                       (push (make-broken-link (page-path page)
                                               href
                                               :missing-page)
                             broken)))))))))
    (nreverse broken)))

(defun check-links (page-map site)
  "Return the broken internal links of the HTML pages in PAGE-MAP.

Every href and src in an HTML page is checked: relative links are resolved
against the page, absolute links against the path part of the base URL of SITE.
Links with a scheme, fragments and query strings are not followed. Pages are
visited in path order, so the result is deterministic. An empty list means
every link works.

PAGE-MAP: the built page map, with its layouts applied.
SITE: the site that was built."
  (let ((prefix (base-prefix site)))
    (loop for page in (page-map-pages page-map)
          when (html-page-p page)
            append (check-page page page-map prefix))))
