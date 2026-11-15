(defpackage #:quire/page
  (:use #:cl)
  (:import-from #:quire/paths
                #:parse-path)
  (:export #:page
           #:make-page
           #:page-body
           #:page-metadata
           #:page-path
           #:page-source))

(in-package #:quire/page)

(deftype octets ()
  "A vector of bytes, for binary page bodies."
  '(vector (unsigned-byte 8)))

(deftype page-body ()
  "A page body: text, bytes, or a function of the page returning either."
  '(or string octets function))

(defun property-list-p (object)
  "Return true when OBJECT is a proper list of even length.

OBJECT: any object."
  (and (listp object)
       (null (cdr (last object)))
       (evenp (length object))))

(deftype property-list ()
  "A proper list of alternating keys and values."
  '(satisfies property-list-p))

(defclass page ()
  ((path :initarg :path
         :reader page-path
         :type string
         :documentation "Validated URL path, such as \"/blog/\" or \"/feed.xml\".")
   (body :initarg :body
         :reader page-body
         :type page-body
         :documentation "Text, bytes, or a function of the page returning them.")
   (metadata :initarg :metadata
             :initform '()
             :reader page-metadata
             :type property-list
             :documentation "Property list of page data, such as :TITLE.")
   (source :initarg :source
           :initform nil
           :reader page-source
           :type (or null string pathname)
           :documentation "Where the page came from, for diagnostics."))
  (:documentation "One page of a site. Treat instances as immutable."))

(defmethod print-object ((page page) stream)
  (print-unreadable-object (page stream :type t)
    (format stream "~S" (page-path page))))

(defun make-page (&key path body metadata source)
  "Return a new page, validating every argument.

PATH: URL path string; signals INVALID-PATH when it is not a valid path.
BODY: a string, a vector of bytes, or a function of the page.
METADATA: property list of page data; defaults to NIL.
SOURCE: string or pathname of the origin, or NIL."
  (check-type path string)
  (check-type body page-body)
  (check-type metadata property-list)
  (check-type source (or null string pathname))
  (make-instance 'page
                 :path (parse-path path)
                 :body body
                 :metadata metadata
                 :source source))
