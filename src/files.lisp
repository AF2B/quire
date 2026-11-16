(defpackage #:quire/files
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:export #:read-file-octets
           #:read-file-text
           #:walk-files))

(in-package #:quire/files)

(defconstant +hidden-prefix+ #\.
  "Files and directories whose name starts with this character are ignored.")

(define-constant +exposed-hidden-names+ '(".well-known" ".nojekyll")
  :test #'equal
  :documentation "Hidden names that are still part of a site: the standard
location for site metadata files and the marker that disables Jekyll.")

(defun read-file-text (pathname)
  "Return the contents of PATHNAME as a UTF-8 string.

PATHNAME: the file to read."
  (uiop:read-file-string pathname :external-format :utf-8))

(defun read-file-octets (pathname)
  "Return the contents of PATHNAME as a vector of bytes.

PATHNAME: the file to read."
  (with-open-file (stream pathname :element-type '(unsigned-byte 8))
    (let ((octets (make-array (file-length stream)
                              :element-type '(unsigned-byte 8))))
      (read-sequence octets stream)
      octets)))

(defun hidden-p (pathname)
  "Return true when PATHNAME names a hidden file or directory to ignore.

A name that starts with a dot is hidden, except the names in
+EXPOSED-HIDDEN-NAMES+.

PATHNAME: a file or directory pathname."
  (let ((name (if (uiop:directory-pathname-p pathname)
                  (car (last (pathname-directory pathname)))
                  (file-namestring pathname))))
    (and (stringp name)
         (plusp (length name))
         (char= +hidden-prefix+ (char name 0))
         (not (member name +exposed-hidden-names+ :test #'string=)))))

(defun walk-files (directory)
  "Return every visible file under DIRECTORY as (RELATIVE-NAME . PATHNAME).

RELATIVE-NAME uses forward slashes. Hidden files and directories are skipped,
except .well-known and .nojekyll.
The list is sorted by RELATIVE-NAME, so the traversal is deterministic. A
missing DIRECTORY yields NIL.

DIRECTORY: the directory to traverse."
  (let ((root (uiop:ensure-directory-pathname directory))
        (found '()))
    (labels ((visit (current)
               (dolist (file (uiop:directory-files current))
                 (unless (hidden-p file)
                   (push (cons (uiop:native-namestring
                                (uiop:enough-pathname file root))
                               file)
                         found)))
               (dolist (subdirectory (uiop:subdirectories current))
                 (unless (hidden-p subdirectory)
                   (visit subdirectory)))))
      (when (uiop:directory-exists-p root)
        (visit root)))
    (sort found #'string< :key #'car)))
