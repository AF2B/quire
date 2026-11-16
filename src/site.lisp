(defpackage #:quire/site
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:export #:*site*
           #:make-site
           #:site
           #:site-author
           #:site-base-url
           #:site-content-directory
           #:site-description
           #:site-extra
           #:site-include-drafts-p
           #:site-language
           #:site-languages
           #:site-layouts
           #:site-link
           #:site-posts-section
           #:site-root
           #:site-static-directories
           #:site-steps
           #:site-title
           #:site-url
           #:site-watched-directories))

(in-package #:quire/site)

(define-constant +default-language+ "en"
  :test #'string=
  :documentation "Language code written in feeds and in the lang attribute.")

(define-constant +default-posts-section+ "posts"
  :test #'string=
  :documentation "Name of the content directory whose pages are posts.")

(define-constant +default-content-directory+ "content/"
  :test #'string=
  :documentation "Content directory, relative to the site root.")

(define-constant +default-static-directory+ "static/"
  :test #'string=
  :documentation "Directory of files copied as they are, relative to the root.")

(defvar *site* nil
  "The site that a site definition file sets and the command line builds.")

(defclass site ()
  ((title :initarg :title
          :reader site-title
          :documentation "Name of the site.")
   (description :initarg :description
                :reader site-description
                :documentation "One sentence about the site.")
   (base-url :initarg :base-url
             :reader site-base-url
             :documentation "Public address without a trailing slash, or empty.")
   (language :initarg :language
             :reader site-language
             :documentation "Language code such as \"en\".")
   (languages :initarg :languages
              :reader site-languages
              :documentation "List of plists (:CODE :NAME :FLAG), default first.")
   (author :initarg :author
           :reader site-author
           :documentation "Author name, or NIL.")
   (root :initarg :root
         :reader site-root
         :documentation "Directory that holds the site definition.")
   (content-directory :initarg :content-directory
                      :reader site-content-directory
                      :documentation "Absolute directory of Markdown content.")
   (static-directories :initarg :static-directories
                       :accessor site-static-directories
                       :documentation "Absolute directories copied verbatim.")
   (layouts :initarg :layouts
            :accessor site-layouts
            :documentation "Plist of layout keyword to function designator.")
   (steps :initarg :steps
          :accessor site-steps
          :documentation "Build steps: designators of (PAGE-MAP SITE) functions.")
   (include-drafts-p :initarg :include-drafts-p
                     :accessor site-include-drafts-p
                     :documentation "True when draft pages are built.")
   (posts-section :initarg :posts-section
                  :reader site-posts-section
                  :documentation "Content directory whose pages are posts.")
   (extra :initarg :extra
          :accessor site-extra
          :documentation "Plist of values for themes, such as :NAV."))
  (:documentation "Everything that describes a site apart from its content."))

(defmethod print-object ((site site) stream)
  (print-unreadable-object (site stream :type t)
    (format stream "~S" (site-title site))))

(defun default-root ()
  "Return the directory of the file being loaded, or the working directory."
  (uiop:pathname-directory-pathname (or *load-truename* (uiop:getcwd))))

(defun resolve-directory (directory root)
  "Return DIRECTORY as an absolute directory pathname, relative to ROOT.

DIRECTORY: a pathname designator, absolute or relative.
ROOT: the directory that relative ones are taken from."
  (merge-pathnames (uiop:ensure-directory-pathname directory) root))

(defun normalize-languages (default languages)
  "Return LANGUAGES as plists, with DEFAULT first and the other codes lowercase.

Signals a type error when an entry has no :CODE string. The code of the default
language is kept as written, so it matches the language the site declares.

DEFAULT: code of the default language.
LANGUAGES: a list of plists with :CODE, :NAME and :FLAG, or NIL."
  (flet ((with-code (entry code)
           (list* :code code
                  (loop for (key value) on entry by #'cddr
                        unless (eq key :code)
                          append (list key value)))))
    (let* ((entries (mapcar (lambda (entry)
                              (check-type (getf entry :code) string)
                              entry)
                            languages))
           (declared (find default entries
                           :key (lambda (entry) (getf entry :code))
                           :test #'string-equal)))
      (cons (if declared
                (with-code declared default)
                (list :code default :name default))
            (loop for entry in entries
                  unless (eq entry declared)
                    collect (with-code entry
                              (string-downcase (getf entry :code))))))))

(defun make-site (&key title
                       (description "")
                       (base-url "")
                       (language +default-language+)
                       languages
                       author
                       (root (default-root))
                       (content-directory +default-content-directory+)
                       (static-directories (list +default-static-directory+))
                       layouts
                       steps
                       include-drafts-p
                       (posts-section +default-posts-section+)
                       extra)
  "Return a new site.

TITLE: name of the site; required.
DESCRIPTION: one sentence about the site.
BASE-URL: public address, such as \"https://example.com\"; a trailing slash is
  dropped. Leave empty to build with root-relative links.
LANGUAGE: language code of the default language; defaults to \"en\".
LANGUAGES: every language of the site as plists with :CODE, :NAME and :FLAG; the
  default language is added first when missing. Pages of any other language
  live in a directory named after its code, such as content/pt-br/.
AUTHOR: author name, or NIL.
ROOT: directory that relative paths are taken from; defaults to the directory
  of the file being loaded.
CONTENT-DIRECTORY: Markdown content; defaults to content/ under ROOT.
STATIC-DIRECTORIES: directories copied verbatim; defaults to static/ under ROOT.
LAYOUTS: plist of layout keyword to function designator. Use symbols so that
  redefining a layout at the REPL takes effect.
STEPS: build steps, or NIL for the default steps of QUIRE/BUILD.
INCLUDE-DRAFTS-P: true to build pages marked :DRAFT T.
POSTS-SECTION: content directory whose pages are posts; defaults to \"posts\".
EXTRA: plist of values for the theme, such as :NAV."
  (check-type title string)
  (check-type base-url string)
  (let ((absolute-root (uiop:ensure-directory-pathname root)))
    (make-instance 'site
                   :title title
                   :description description
                   :base-url (string-right-trim "/" base-url)
                   :language language
                   :languages (normalize-languages language languages)
                   :author author
                   :root absolute-root
                   :content-directory (resolve-directory content-directory
                                                         absolute-root)
                   :static-directories (mapcar (lambda (directory)
                                                 (resolve-directory
                                                  directory absolute-root))
                                               static-directories)
                   :layouts layouts
                   :steps steps
                   :include-drafts-p include-drafts-p
                   :posts-section posts-section
                   :extra extra)))

(defun site-url (site path)
  "Return the absolute URL of PATH on SITE.

SITE: the site.
PATH: a URL path such as \"/blog/\"."
  (concatenate 'string (site-base-url site) path))

(defun site-link (site path)
  "Return the href that points at PATH, honoring the path part of the base URL.

For a base URL such as \"https://example.com/blog\" the link to \"/a/\" is
\"/blog/a/\"; with an empty base URL it is \"/a/\".

SITE: the site.
PATH: a URL path such as \"/a/\"."
  (let* ((base (site-base-url site))
         (scheme-end (search "://" base))
         (path-start (and scheme-end
                          (position #\/ base :start (+ scheme-end 3)))))
    (concatenate 'string
                 (cond (path-start (subseq base path-start))
                       (scheme-end "")
                       (t base))
                 path)))

(defun site-watched-directories (site)
  "Return the directories whose changes require a rebuild.

SITE: the site."
  (cons (site-content-directory site)
        (site-static-directories site)))
