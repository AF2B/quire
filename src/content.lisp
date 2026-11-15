(defpackage #:quire/content
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/conditions
                #:front-matter-error
                #:invalid-path
                #:skipped-file)
  (:import-from #:quire/dates
                #:parse-date)
  (:import-from #:quire/files
                #:read-file-octets
                #:read-file-text
                #:walk-files)
  (:import-from #:quire/front-matter
                #:split-front-matter)
  (:import-from #:quire/markdown
                #:markdown->html)
  (:import-from #:quire/page
                #:make-page)
  (:import-from #:quire/page-map
                #:add-page
                #:make-page-map)
  (:import-from #:quire/paths
                #:+path-separator+)
  (:import-from #:quire/site
                #:site-content-directory
                #:site-include-drafts-p
                #:site-posts-section
                #:site-static-directories)
  (:export #:read-content
           #:read-static-directory
           #:source-path->url-path
           #:title-from-slug))

(in-package #:quire/content)

(define-constant +markdown-extension+ ".md"
  :test #'string=
  :documentation "Suffix of the files that are rendered as pages.")

(define-constant +index-stem+ "index"
  :test #'string=
  :documentation "File name, without extension, that names its directory.")

(defconstant +word-separator+ #\-
  "Separator between words in a slug.")

(defun markdown-file-p (relative-name)
  "Return true when RELATIVE-NAME is the name of a Markdown file.

RELATIVE-NAME: a file name relative to the content directory."
  (let ((suffix-start (- (length relative-name) (length +markdown-extension+))))
    (and (plusp suffix-start)
         (string= +markdown-extension+ relative-name :start2 suffix-start))))

(defun source-path->url-path (relative-name)
  "Return the URL path of the Markdown file RELATIVE-NAME.

\"index.md\" becomes \"/\", \"posts/index.md\" becomes \"/posts/\" and
\"posts/hello.md\" becomes \"/posts/hello/\".

RELATIVE-NAME: name of a .md file relative to the content directory, with
forward slashes."
  (let* ((stem (subseq relative-name
                       0
                       (- (length relative-name)
                          (length +markdown-extension+))))
         (separator (position +path-separator+ stem :from-end t))
         (directory (if separator (subseq stem 0 (1+ separator)) ""))
         (name (if separator (subseq stem (1+ separator)) stem)))
    (if (string= name +index-stem+)
        (concatenate 'string "/" directory)
        (concatenate 'string "/" directory name "/"))))

(defun title-from-slug (slug)
  "Return a readable title for SLUG, used when a page has no :TITLE.

SLUG: a hyphenated name; \"hello-world\" yields \"Hello World\"."
  (string-capitalize (substitute #\Space +word-separator+ slug)))

(defun url-path-section (url-path)
  "Return the first segment of URL-PATH, or NIL for the site root.

URL-PATH: a valid URL path; \"/posts/a/\" yields \"posts\"."
  (let ((end (position +path-separator+ url-path :start 1)))
    (when (and end (> end 1))
      (subseq url-path 1 end))))

(defun url-path-slug (url-path)
  "Return the last meaningful segment of URL-PATH, or \"home\" for the root.

URL-PATH: a valid directory URL path."
  (let ((segments (remove "" (uiop:split-string url-path
                                                :separator
                                                (string +path-separator+))
                          :test #'string=)))
    (if segments
        (car (last segments))
        "home")))

(defun check-metadata (metadata source)
  "Signal FRONT-MATTER-ERROR when a known METADATA key has the wrong type.

METADATA: the property list read from the front matter.
SOURCE: origin of the metadata, for messages."
  (flet ((require-type (key predicate description)
           (let ((value (getf metadata key)))
             (when (and value (not (funcall predicate value)))
               (error 'front-matter-error
                      :source source
                      :reason :invalid-value
                      :detail (format nil "~S must be ~A" key description))))))
    (require-type :title #'stringp "a string")
    (require-type :date #'stringp "a string")
    (require-type :path #'stringp "a string")
    (require-type :description #'stringp "a string")
    (require-type :layout #'keywordp "a keyword")
    (require-type :tags
                  (lambda (tags) (and (listp tags) (every #'stringp tags)))
                  "a list of strings")))

(defun page-metadata-for (metadata url-path section posts-section)
  "Return METADATA completed with the keys quire derives.

Adds :TITLE, :SECTION, :LAYOUT and, when :DATE is present, :TIMESTAMP.

METADATA: the property list read from the front matter.
URL-PATH: the final URL path of the page.
SECTION: first segment of URL-PATH, or NIL.
POSTS-SECTION: name of the section that holds posts."
  (let ((result (copy-list metadata)))
    (unless (getf result :title)
      (setf (getf result :title) (title-from-slug (url-path-slug url-path))))
    (setf (getf result :section) section)
    (unless (getf result :layout)
      (setf (getf result :layout)
            (if (and section
                     (string= section posts-section)
                     (not (string= url-path
                                   (concatenate 'string "/" section "/"))))
                :post
                :page)))
    (when (getf result :date)
      (setf (getf result :timestamp) (parse-date (getf result :date))))
    result))

(defun read-markdown-page (site relative-name pathname)
  "Return the page that the Markdown file PATHNAME defines.

SITE: the site being built.
RELATIVE-NAME: name of the file relative to the content directory.
PATHNAME: the file to read."
  (let ((source (uiop:native-namestring pathname)))
    (multiple-value-bind (metadata markdown)
        (split-front-matter (read-file-text pathname) :source source)
      (check-metadata metadata source)
      (let* ((url-path (or (getf metadata :path)
                           (source-path->url-path relative-name)))
             (section (url-path-section url-path)))
        (make-page :path url-path
                   :body (markdown->html markdown)
                   :metadata (page-metadata-for metadata
                                                url-path
                                                section
                                                (site-posts-section site))
                   :source source)))))

(defun draft-p (page)
  "Return true when PAGE is marked as a draft.

PAGE: a page with metadata."
  (getf (quire/page:page-metadata page) :draft))

(defun read-static-file (relative-name pathname)
  "Return a page holding the bytes of PATHNAME, or NIL when it must be skipped.

The page lives at RELATIVE-NAME below the root. A file whose name is not a valid
site path is skipped with a SKIPPED-FILE warning.

RELATIVE-NAME: name of the file relative to its directory.
PATHNAME: the file to read."
  (handler-case (make-page :path (concatenate 'string "/" relative-name)
                           :body (read-file-octets pathname)
                           :source (uiop:native-namestring pathname))
    (invalid-path ()
      (warn 'skipped-file :file pathname)
      nil)))

(defun read-static-directory (directory)
  "Return a page map with every visible file under DIRECTORY, as bytes.

A file at DIRECTORY/css/a.css becomes the page at /css/a.css.

DIRECTORY: the directory to read; a missing directory yields an empty map."
  (let ((page-map (make-page-map)))
    (loop for (relative-name . pathname) in (walk-files directory)
          for page = (read-static-file relative-name pathname)
          when page
            do (add-page page-map page))
    page-map))

(defun read-content (site)
  "Return a page map with the content of SITE.

Markdown files become pages, drafts are left out unless SITE builds drafts, and
every other file under the content directory is copied as bytes.

SITE: the site whose content directory to read."
  (let ((page-map (make-page-map)))
    (loop for (relative-name . pathname)
            in (walk-files (site-content-directory site))
          for page = (if (markdown-file-p relative-name)
                         (read-markdown-page site relative-name pathname)
                         (read-static-file relative-name pathname))
          when (and page
                    (or (site-include-drafts-p site)
                        (not (draft-p page))))
            do (add-page page-map page))
    page-map))
