(defpackage #:quire/cli
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/build
                #:build-site)
  (:import-from #:quire/check
                #:broken-link-href
                #:broken-link-page
                #:broken-link-reason
                #:check-links)
  (:import-from #:quire/conditions
                #:cli-usage-error
                #:quire-error
                #:site-file-error)
  (:import-from #:quire/export
                #:export-site)
  (:import-from #:quire/server
                #:server-port
                #:start-server
                #:stop-server)
  (:import-from #:quire/site
                #:*site*
                #:site
                #:site-include-drafts-p
                #:site-root
                #:site-watched-directories)
  (:export #:main
           #:parse-options
           #:run
           #:save-executable))

(in-package #:quire/cli)

(defconstant +exit-ok+ 0
  "Exit code of a command that succeeded.")

(defconstant +exit-failure+ 1
  "Exit code of a command that failed with a quire error, or of a check that
found broken links.")

(defconstant +exit-usage+ 2
  "Exit code of a command line that was not understood.")

(defconstant +exit-internal+ 70
  "Exit code of an unexpected error (EX_SOFTWARE in sysexits.h).")

(defconstant +exit-interrupted+ 130
  "Exit code of a command stopped with Ctrl-C.")

(defconstant +max-port+ 65535
  "Highest valid TCP port.")

(defconstant +default-port+ 4000
  "Port of the development server.")

(defconstant +idle-seconds+ 3600
  "Pause of the main thread while the development server runs.")

(define-constant +default-site-file+ "site.lisp"
  :test #'string=
  :documentation "Site definition file, looked up in the working directory.")

(define-constant +default-output-directory+ "public/"
  :test #'string=
  :documentation "Output directory, relative to the site root.")

(define-constant +default-host+ "127.0.0.1"
  :test #'string=
  :documentation "Address of the development server.")

(define-constant +usage+
  "Usage: quire COMMAND [OPTIONS]

Commands:
  build    Build the site into a directory.
  check    Build the site and report links that lead nowhere.
  serve    Serve the site with live reload.
  version  Print the version.
  help     Print this message.

Options:
  --site FILE   Site definition file (default: site.lisp).
  --out DIR     Output directory for build (default: public/ next to the site).
  --clean       Empty the output directory first; only if quire created it.
  --drafts      Include pages marked :draft t.
  --port N      Port for serve (default: 4000).
  --host ADDR   Address for serve (default: 127.0.0.1).
"
  :test #'string=
  :documentation "Text printed by the help command and after a usage error.")

(defvar *version* (asdf:component-version (asdf:find-system "quire"))
  "Version of quire, read from the ASDF system when this file is loaded so that
a saved executable still knows it.")

(defun usage-error (format-control &rest arguments)
  "Signal a CLI-USAGE-ERROR with a message built from the arguments.

FORMAT-CONTROL: a FORMAT control string.
ARGUMENTS: its arguments."
  (error 'cli-usage-error
         :message (apply #'format nil format-control arguments)))

(defun parse-options (arguments value-options flag-options)
  "Return a property list of the options found in ARGUMENTS.

An option that takes a value becomes a keyword and its value; a flag becomes a
keyword and T. Signals CLI-USAGE-ERROR for an unknown option, a missing value
or a stray argument.

ARGUMENTS: list of strings after the command name.
VALUE-OPTIONS: names such as \"--site\" that take a value.
FLAG-OPTIONS: names such as \"--clean\" that do not."
  (let ((result '()))
    (loop while arguments
          do (let* ((name (pop arguments))
                    (key (intern (string-upcase (string-left-trim "-" name))
                                 :keyword)))
               (cond ((member name flag-options :test #'string=)
                      (setf (getf result key) t))
                     ((member name value-options :test #'string=)
                      (when (null arguments)
                        (usage-error "Option ~A needs a value." name))
                      (setf (getf result key) (pop arguments)))
                     (t (usage-error "Unknown argument ~S." name)))))
    result))

(defun parse-port (text)
  "Return the port number written in TEXT.

Signals CLI-USAGE-ERROR when TEXT is not an integer from 0 to 65535.

TEXT: the string given to --port."
  (let ((port (and (plusp (length text))
                   (every #'digit-char-p text)
                   (parse-integer text))))
    (unless (and port (<= 0 port +max-port+))
      (usage-error "Invalid port ~S." text))
    port))

(defun load-site (site-file)
  "Load the site definition file and return the site it sets.

The file is loaded into the QUIRE-USER package and must set QUIRE:*SITE*.
Signals SITE-FILE-ERROR when the file is missing or sets no site.

SITE-FILE: name of the file, absolute or relative to the working directory."
  (let ((pathname (merge-pathnames site-file (uiop:getcwd))))
    (unless (probe-file pathname)
      (error 'site-file-error :file site-file :reason :missing))
    (let ((*site* nil)
          (*package* (find-package '#:quire-user)))
      (load pathname)
      (unless (typep *site* 'site)
        (error 'site-file-error :file site-file :reason :no-site))
      *site*)))

(defun site-from-options (options)
  "Load the site that OPTIONS name and apply the --drafts flag.

OPTIONS: the property list from PARSE-OPTIONS."
  (let ((site (load-site (or (getf options :site) +default-site-file+))))
    (when (getf options :drafts)
      (setf (site-include-drafts-p site) t))
    site))

(defun command-build (arguments)
  "Build the site into the output directory and return the exit code.

ARGUMENTS: command line arguments after the command name."
  (let* ((options (parse-options arguments
                                 '("--site" "--out")
                                 '("--clean" "--drafts")))
         (site (site-from-options options))
         (output (if (getf options :out)
                     (merge-pathnames (uiop:ensure-directory-pathname
                                       (getf options :out))
                                      (uiop:getcwd))
                     (merge-pathnames +default-output-directory+
                                      (site-root site)))))
    (multiple-value-bind (paths count)
        (export-site (build-site site) output :clean (getf options :clean))
      (declare (ignore paths))
      (format t "Built ~D files into ~A~%" count (uiop:native-namestring output))
      +exit-ok+)))

(defun describe-broken-link (broken)
  "Return the one-line report of a broken link.

BROKEN: a BROKEN-LINK."
  (format nil "~A: ~A (~A)"
          (broken-link-page broken)
          (broken-link-href broken)
          (ecase (broken-link-reason broken)
            (:missing-page "no such page")
            (:outside-base-path "outside the base URL path"))))

(defun command-check (arguments)
  "Build the site, report its broken links and return the exit code.

The exit code is 0 when every internal link works and 1 otherwise.

ARGUMENTS: command line arguments after the command name."
  (let* ((options (parse-options arguments '("--site") '("--drafts")))
         (site (site-from-options options))
         (broken (check-links (build-site site) site)))
    (dolist (link broken)
      (format t "~A~%" (describe-broken-link link)))
    (cond (broken
           (format t "~D broken link~:P.~%" (length broken))
           +exit-failure+)
          (t
           (format t "No broken links.~%")
           +exit-ok+))))

(defun command-serve (arguments)
  "Serve the site with live reload until interrupted and return the exit code.

ARGUMENTS: command line arguments after the command name."
  (let* ((options (parse-options arguments
                                 '("--site" "--port" "--host")
                                 '("--drafts")))
         (site (site-from-options options))
         (server (start-server (lambda () (build-site site))
                               :port (if (getf options :port)
                                         (parse-port (getf options :port))
                                         +default-port+)
                               :address (or (getf options :host) +default-host+)
                               :watch (site-watched-directories site))))
    (format t "Serving at http://~A:~D/ (Ctrl-C to stop)~%"
            (or (getf options :host) +default-host+)
            (server-port server))
    (finish-output)
    (unwind-protect
         #+sbcl (handler-case (loop (sleep +idle-seconds+))
                  (sb-sys:interactive-interrupt () +exit-interrupted+))
         #-sbcl (loop (sleep +idle-seconds+))
      (stop-server server))))

(defun run (arguments)
  "Run the command in ARGUMENTS and return the process exit code.

Quire errors and usage errors are reported on *ERROR-OUTPUT* and turn into
exit codes; any other error is reported as an internal error.

ARGUMENTS: list of strings, the command line without the program name."
  (handler-case
      (let ((command (first arguments))
            (rest (rest arguments)))
        (cond ((or (null command)
                   (member command '("help" "--help" "-h") :test #'string=))
               (write-string +usage+)
               +exit-ok+)
              ((member command '("version" "--version") :test #'string=)
               (format t "quire ~A~%" *version*)
               +exit-ok+)
              ((string= command "build") (command-build rest))
              ((string= command "check") (command-check rest))
              ((string= command "serve") (command-serve rest))
              (t (usage-error "Unknown command ~S." command))))
    (cli-usage-error (condition)
      (format *error-output* "quire: ~A~%~%~A" condition +usage+)
      +exit-usage+)
    (quire-error (condition)
      (format *error-output* "quire: ~A~%" condition)
      +exit-failure+)
    (error (condition)
      (format *error-output* "quire: internal error: ~A~%" condition)
      +exit-internal+)))

(defun main ()
  "Entry point of the executable: run the command line and exit."
  (uiop:quit (run (uiop:command-line-arguments))))

(defun save-executable (path)
  "Save the running image as an executable at PATH, with MAIN as entry point.

Only SBCL is supported. The theme, the server and the CLI must be loaded.

PATH: the file name of the executable."
  #+sbcl (sb-ext:save-lisp-and-die path
                                   :executable t
                                   :toplevel #'main
                                   :save-runtime-options t)
  #-sbcl (error "Saving an executable is only supported on SBCL: ~A" path))
