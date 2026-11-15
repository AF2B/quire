(defpackage #:quire/tests/support
  (:use #:cl)
  (:export #:call-with-temp-directory
           #:directory-snapshot
           #:with-temp-directory
           #:write-octet-file
           #:write-text-file))

(in-package #:quire/tests/support)

(defconstant +random-limit+ 1000000000
  "Exclusive upper bound of the number that makes a temp directory unique.")

(defun call-with-temp-directory (function)
  "Call FUNCTION with a fresh empty directory, and delete it afterwards.

FUNCTION: a function of one argument, the directory pathname."
  (let ((directory (merge-pathnames
                    (format nil "quire-test-~D/"
                            (random +random-limit+ (make-random-state t)))
                    (uiop:temporary-directory))))
    (ensure-directories-exist directory)
    (unwind-protect (funcall function directory)
      (uiop:delete-directory-tree directory :validate t
                                            :if-does-not-exist :ignore))))

(defmacro with-temp-directory ((variable) &body body)
  "Run BODY with VARIABLE bound to a fresh temporary directory.

VARIABLE: the symbol that names the directory pathname.
BODY: the forms to run."
  `(call-with-temp-directory (lambda (,variable) ,@body)))

(defun write-text-file (directory relative-name text)
  "Write TEXT as UTF-8 to RELATIVE-NAME under DIRECTORY and return the pathname.

DIRECTORY: the base directory.
RELATIVE-NAME: file name relative to DIRECTORY, with forward slashes.
TEXT: the string to write."
  (let ((pathname (merge-pathnames relative-name directory)))
    (ensure-directories-exist pathname)
    (with-open-file (out pathname :direction :output
                                  :if-exists :supersede
                                  :external-format :utf-8)
      (write-string text out))
    pathname))

(defun write-octet-file (directory relative-name octets)
  "Write OCTETS to RELATIVE-NAME under DIRECTORY and return the pathname.

DIRECTORY: the base directory.
RELATIVE-NAME: file name relative to DIRECTORY, with forward slashes.
OCTETS: the vector of bytes to write."
  (let ((pathname (merge-pathnames relative-name directory)))
    (ensure-directories-exist pathname)
    (with-open-file (out pathname :direction :output
                                  :if-exists :supersede
                                  :element-type '(unsigned-byte 8))
      (write-sequence octets out))
    pathname))

(defun directory-snapshot (directory)
  "Return a sorted list of (RELATIVE-NAME . OCTETS) for every file in DIRECTORY.

Hidden files are included, so the snapshot compares whole output trees.

DIRECTORY: the directory to read."
  (let ((root (uiop:ensure-directory-pathname directory))
        (found '()))
    (labels ((visit (current)
               (dolist (file (uiop:directory-files current))
                 (push (cons (uiop:native-namestring
                              (uiop:enough-pathname file root))
                             (quire/files:read-file-octets file))
                       found))
               (mapc #'visit (uiop:subdirectories current))))
      (visit root))
    (sort found #'string< :key #'car)))
