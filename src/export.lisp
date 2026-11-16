(defpackage #:quire/export
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/conditions
                #:unsafe-output-directory)
  (:import-from #:quire/page
                #:page-path
                #:resolve-body)
  (:import-from #:quire/page-map
                #:page-map-pages)
  (:import-from #:quire/paths
                #:path->output-path)
  (:export #:+output-marker-name+
           #:export-site))

(in-package #:quire/export)

(define-constant +output-marker-name+ ".quire-output"
  :test #'string=
  :documentation "File that marks a directory as created by quire.")

(define-constant +output-marker-text+ "Created by quire; safe to clean.
"
  :test #'string=
  :documentation "Contents of the marker file.")

(defun marker-pathname (root)
  "Return the pathname of the marker file inside ROOT.

ROOT: the output directory pathname."
  (merge-pathnames (uiop:parse-unix-namestring +output-marker-name+) root))

(defun directory-empty-p (root)
  "Return true when the directory ROOT has no files and no subdirectories.

ROOT: the directory pathname."
  (and (null (uiop:directory-files root))
       (null (uiop:subdirectories root))))

(defun owned-p (root)
  "Return true when ROOT is missing, empty or marked as a quire output.

ROOT: the output directory pathname."
  (or (not (uiop:directory-exists-p root))
      (directory-empty-p root)
      (probe-file (marker-pathname root))))

(defun regular-file-p (root)
  "Return true when ROOT names an existing file that is not a directory.

ROOT: the output directory pathname."
  (and (not (uiop:directory-exists-p root))
       (probe-file (string-right-trim "/" (uiop:native-namestring root)))
       t))

(defun clean-directory (root)
  "Delete everything inside ROOT except the marker, if quire owns ROOT.

Signals UNSAFE-OUTPUT-DIRECTORY when ROOT is a file or holds files that quire
did not create.

ROOT: the output directory pathname."
  (cond ((regular-file-p root)
         (error 'unsafe-output-directory
                :directory root
                :reason :not-a-directory))
        ((not (owned-p root))
         (error 'unsafe-output-directory
                :directory root
                :reason :not-quire-output))
        ((uiop:directory-exists-p root)
         (dolist (file (uiop:directory-files root))
           (unless (string= +output-marker-name+ (file-namestring file))
             (delete-file file)))
         (dolist (subdirectory (uiop:subdirectories root))
           (uiop:delete-directory-tree subdirectory :validate t)))))

(defun write-page (root page)
  "Write the resolved body of PAGE below ROOT and return its output path.

A string body is written as UTF-8; a vector of bytes is written as it is.

ROOT: the output directory pathname.
PAGE: the page to write."
  (let* ((output-path (path->output-path (page-path page)))
         (pathname (merge-pathnames (uiop:parse-unix-namestring output-path)
                                    root))
         (body (resolve-body page)))
    (ensure-directories-exist pathname)
    (if (stringp body)
        (with-open-file (out pathname :direction :output
                                      :if-exists :supersede
                                      :external-format :utf-8)
          (write-string body out))
        (with-open-file (out pathname :direction :output
                                      :if-exists :supersede
                                      :element-type '(unsigned-byte 8))
          (write-sequence body out)))
    output-path))

(defun export-site (page-map directory &key clean)
  "Write every page of PAGE-MAP below DIRECTORY and return the output paths.

Pages are written in path order. The marker file .quire-output is written when
DIRECTORY is new, empty or already marked, so that CLEAN stays safe: it
deletes the previous contents of a directory only when quire owns it, and
otherwise signals UNSAFE-OUTPUT-DIRECTORY before touching anything. Returns
the sorted list of relative output paths as the first value and their count as
the second.

PAGE-MAP: the page map to write.
DIRECTORY: the output directory; created when missing.
CLEAN: true to delete the previous contents first."
  (let* ((root (uiop:ensure-directory-pathname directory))
         (owned (owned-p root)))
    (when clean
      (clean-directory root))
    (ensure-directories-exist root)
    (when owned
      (with-open-file (out (marker-pathname root) :direction :output
                                                  :if-exists :supersede
                                                  :external-format :utf-8)
        (write-string +output-marker-text+ out)))
    (let ((written (sort (loop for page in (page-map-pages page-map)
                               collect (write-page root page))
                         #'string<)))
      ;; SORT is destructive: only its result is a valid list afterwards.
      (values written (length written)))))
