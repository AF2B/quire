(defpackage #:quire/server
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/conditions
                #:invalid-path
                #:invalid-path-reason)
  (:import-from #:quire/files
                #:walk-files)
  (:import-from #:quire/page
                #:resolve-body)
  (:import-from #:quire/page-map
                #:find-page)
  (:import-from #:quire/paths
                #:parse-path)
  (:import-from #:quire/xml
                #:xml-escape)
  (:export #:+events-path+
           #:content-type-for
           #:dev-server
           #:refresh
           #:reload-browsers
           #:respond
           #:server-generation
           #:server-last-error
           #:server-page-map
           #:server-port
           #:start-server
           #:stop-server))

(in-package #:quire/server)

(define-constant +events-path+ "/__quire/events"
  :test #'string=
  :documentation "Path of the server-sent events stream that drives reloads.")

(define-constant +live-reload-snippet+
  "<script>new EventSource(\"/__quire/events\").onmessage=function(){location.reload()}</script>"
  :test #'string=
  :documentation "Script injected into every HTML page the dev server sends.")

(define-constant +body-end-tag+ "</body>"
  :test #'string=
  :documentation "Tag before which the live reload script is inserted.")

(define-constant +html-type+ "text/html; charset=utf-8"
  :test #'string=
  :documentation "Content type of HTML responses.")

(define-constant +text-type+ "text/plain; charset=utf-8"
  :test #'string=
  :documentation "Content type of redirect and error bodies that are not HTML.")

(define-constant +default-type+ "application/octet-stream"
  :test #'string=
  :documentation "Content type of files with an unknown extension.")

(define-constant +content-types+
  '(("html" . "text/html; charset=utf-8")
    ("css" . "text/css; charset=utf-8")
    ("js" . "text/javascript; charset=utf-8")
    ("json" . "application/json; charset=utf-8")
    ("xml" . "application/xml; charset=utf-8")
    ("txt" . "text/plain; charset=utf-8")
    ("svg" . "image/svg+xml")
    ("png" . "image/png")
    ("jpg" . "image/jpeg")
    ("jpeg" . "image/jpeg")
    ("gif" . "image/gif")
    ("webp" . "image/webp")
    ("ico" . "image/x-icon")
    ("woff" . "font/woff")
    ("woff2" . "font/woff2")
    ("ttf" . "font/ttf")
    ("pdf" . "application/pdf"))
  :test #'equal
  :documentation "Content type for each file extension the server knows.")

(defconstant +watch-interval-seconds+ 0.5
  "Pause between two checks of the watched directories.")

(defconstant +event-interval-seconds+ 0.1
  "Pause between two checks of the generation by an event stream.")

(defconstant +heartbeat-ticks+ 100
  "Event stream checks between two keep-alive comments.")

(defconstant +status-ok+ 200
  "HTTP status of a successful response.")

(defconstant +status-moved+ 301
  "HTTP status of a redirect to the directory form of a path.")

(defconstant +status-bad-request+ 400
  "HTTP status of a request whose path is invalid.")

(defconstant +status-not-found+ 404
  "HTTP status of a request for a page that does not exist.")

(defconstant +status-method-not-allowed+ 405
  "HTTP status of a request that is neither GET nor HEAD.")

(defconstant +status-server-error+ 500
  "HTTP status of a build or layout failure.")

(defclass dev-server ()
  ((builder :initarg :builder
            :reader server-builder
            :documentation "Function of no arguments that returns a page map.")
   (page-map :initform nil
             :reader server-page-map
             :documentation "The most recent successfully built page map.")
   (generation :initform 0
               :reader server-generation
               :documentation "Counter that grows on every refresh.")
   (last-error :initform nil
               :reader server-last-error
               :documentation "Message of the failed build, or NIL.")
   (lock :initform (bt:make-lock "quire-server")
         :reader server-lock
         :documentation "Guards the slots above.")
   (watched :initarg :watched
            :initform '()
            :reader server-watched
            :documentation "Directories whose changes trigger a refresh.")
   (running-p :initform t
              :accessor server-running-p
              :documentation "False once the server is stopped.")
   (watcher :initform nil
            :accessor server-watcher
            :documentation "The thread that polls the watched directories.")
   (acceptor :initform nil
             :accessor server-acceptor
             :documentation "The Hunchentoot acceptor."))
  (:documentation "A development server: serves a page map and reloads browsers."))

(defclass dev-acceptor (hunchentoot:acceptor)
  ((server :initarg :server
           :reader acceptor-server
           :documentation "The DEV-SERVER this acceptor answers for."))
  (:documentation "Hunchentoot acceptor that dispatches every request to a server."))

(defun content-type-for (path)
  "Return the content type to send for the URL path PATH.

PATH: a URL path; a directory path is HTML."
  (let* ((dot (position #\. path :from-end t))
         (slash (position #\/ path :from-end t))
         (extension (and dot slash (> dot slash)
                         (string-downcase (subseq path (1+ dot))))))
    (or (and extension (cdr (assoc extension +content-types+ :test #'string=)))
        (if (and (plusp (length path))
                 (char= #\/ (char path (1- (length path)))))
            +html-type+
            +default-type+))))

(defun inject-live-reload (html)
  "Return HTML with the live reload script inserted before the closing body tag.

When HTML has no body tag the script is appended.

HTML: the page text."
  (let ((position (search +body-end-tag+ html :from-end t)))
    (if position
        (concatenate 'string
                     (subseq html 0 position)
                     +live-reload-snippet+
                     (subseq html position))
        (concatenate 'string html +live-reload-snippet+))))

(defun html-response (status html)
  "Return the response values for an HTML page with STATUS.

HTML: the page text; the live reload script is added.
STATUS: the HTTP status code."
  (values status +html-type+ (inject-live-reload html) nil))

(defun error-response (message)
  "Return the response values for a failure described by MESSAGE.

MESSAGE: the text to show; it is escaped."
  (html-response +status-server-error+
                 (format nil "<!doctype html><html><head><meta charset=utf-8>~
                              <title>quire error</title></head><body>~
                              <pre>~A</pre></body></html>"
                         (xml-escape message))))

(defun not-found-response ()
  "Return the response values for a page that does not exist."
  (html-response +status-not-found+
                 "<!doctype html><html><head><meta charset=utf-8><title>Not found</title></head><body><p>Not found</p></body></html>"))

(defun page-response (page path)
  "Return the response values for PAGE served at PATH.

A failure while rendering becomes a 500 page that shows the message.

PAGE: the page to serve.
PATH: the validated URL path that was requested."
  (handler-case
      (let ((body (resolve-body page))
            (type (content-type-for path)))
        (if (and (stringp body) (string= type +html-type+))
            (html-response +status-ok+ body)
            (values +status-ok+ type body nil)))
    (error (condition)
      (error-response (princ-to-string condition)))))

(defun route (page-map request-path)
  "Return the response values for REQUEST-PATH, looked up in PAGE-MAP.

REQUEST-PATH: the decoded path of the request.
PAGE-MAP: the page map to serve."
  (multiple-value-bind (path reason)
      (handler-case (values (parse-path request-path) nil)
        (invalid-path (condition)
          (values nil (invalid-path-reason condition))))
    (cond ((eq reason :missing-extension)
           (let ((directory (concatenate 'string request-path "/")))
             (if (find-page page-map directory)
                 (values +status-moved+ +text-type+ "" directory)
                 (not-found-response))))
          (reason
           (html-response +status-bad-request+
                          "<!doctype html><html><body><p>Bad request</p></body></html>"))
          (t
           (let ((page (find-page page-map path)))
             (if page
                 (page-response page path)
                 (not-found-response)))))))

(defun respond (server request-path)
  "Return the response for REQUEST-PATH as four values.

The values are the status code, the content type, the body (a string or bytes)
and the location to redirect to, or NIL. HTML responses carry the live reload
script. A failed build is shown instead of any page, so errors are never
hidden behind a stale site.

SERVER: the dev server.
REQUEST-PATH: the decoded path of the request."
  (let ((failure (server-last-error server)))
    (if failure
        (error-response failure)
        (route (server-page-map server) request-path))))

(defun reload-browsers (server)
  "Tell every connected browser to reload, without rebuilding anything.

Use it after redefining a layout at the REPL: layouts run on every request, so
only the open pages need a nudge.

SERVER: the dev server."
  (bt:with-lock-held ((server-lock server))
    (incf (slot-value server 'generation))))

(defun rebuild (server)
  "Run the builder of SERVER and store the page map, or the failure message.

A failing build is reported to browsers and to *ERROR-OUTPUT*; the server keeps
running so that fixing the source recovers it.

SERVER: the dev server."
  (handler-case
      (let ((page-map (funcall (server-builder server))))
        (bt:with-lock-held ((server-lock server))
          (setf (slot-value server 'page-map) page-map
                (slot-value server 'last-error) nil)))
    (error (condition)
      (let ((message (princ-to-string condition)))
        (format *error-output* "~&quire: build failed: ~A~%" message)
        (bt:with-lock-held ((server-lock server))
          (setf (slot-value server 'last-error) message))))))

(defun refresh (server)
  "Rebuild the site of SERVER and tell every browser to reload.

SERVER: the dev server."
  (rebuild server)
  (reload-browsers server))

(defun file-size (pathname)
  "Return the size of PATHNAME in bytes.

PATHNAME: the file to measure."
  (with-open-file (stream pathname :element-type '(unsigned-byte 8))
    (file-length stream)))

(defun fingerprint (directories)
  "Return a value that changes when a file in DIRECTORIES changes.

The value lists the name, modification time and size of every file, so a change
is noticed even within the one-second resolution of modification times.

DIRECTORIES: the directories to inspect."
  (loop for directory in directories
        append (loop for (name . pathname) in (walk-files directory)
                     collect (list directory
                                   name
                                   (file-write-date pathname)
                                   (file-size pathname)))))

(defun watch-loop (server initial)
  "Refresh SERVER whenever its watched directories change, until it stops.

SERVER: the dev server.
INITIAL: the fingerprint taken before the first build, so that a change made
  while the site was building is still noticed."
  (let ((previous initial))
    (loop while (server-running-p server)
          do (sleep +watch-interval-seconds+)
             (let ((current (fingerprint (server-watched server))))
               (unless (equal previous current)
                 (setf previous current)
                 (refresh server))))))

(defun write-event (stream text)
  "Write TEXT as UTF-8 to the event STREAM and flush it.

STREAM: the binary response stream.
TEXT: the text of the event."
  (write-sequence (flexi-streams:string-to-octets text :external-format :utf-8)
                  stream)
  (finish-output stream))

(defun stream-events (server)
  "Hold the connection open and send a reload event on every refresh.

Returns when SERVER stops or the browser disconnects.

SERVER: the dev server."
  (setf (hunchentoot:content-type*) "text/event-stream; charset=utf-8"
        (hunchentoot:header-out :cache-control) "no-cache")
  (let ((seen (server-generation server))
        (stream (hunchentoot:send-headers)))
    (handler-case
        (progn
          (write-event stream (format nil ": connected~%~%"))
          (loop for tick from 1
                while (server-running-p server)
                do (sleep +event-interval-seconds+)
                   (cond ((/= seen (server-generation server))
                          (setf seen (server-generation server))
                          (write-event stream (format nil "data: reload~%~%")))
                         ((zerop (mod tick +heartbeat-ticks+))
                          (write-event stream (format nil ": ping~%~%"))))))
      ;; The browser closing the tab is the normal way a stream ends.
      (stream-error () nil)))
  nil)

(defmethod hunchentoot:acceptor-dispatch-request ((acceptor dev-acceptor) request)
  (let* ((server (acceptor-server acceptor))
         (path (handler-case (hunchentoot:url-decode
                              (hunchentoot:script-name request))
                 (error () ""))))
    (cond ((not (member (hunchentoot:request-method request) '(:get :head)))
           (setf (hunchentoot:return-code*) +status-method-not-allowed+)
           "Method not allowed")
          ((string= path +events-path+)
           (stream-events server))
          (t
           (multiple-value-bind (status type body location)
               (respond server path)
             (setf (hunchentoot:return-code*) status
                   (hunchentoot:content-type*) type
                   (hunchentoot:header-out :cache-control) "no-store")
             (when location
               (setf (hunchentoot:header-out :location) location))
             body)))))

(defun server-port (server)
  "Return the TCP port that SERVER listens on.

SERVER: the dev server."
  (hunchentoot:acceptor-port (server-acceptor server)))

(defun start-server (builder &key (port 4000) (address "127.0.0.1") watch)
  "Start a development server and return it.

The site is built once up front and again on every REFRESH. The server listens
on loopback by default, so it is not reachable from other machines.

BUILDER: function of no arguments that returns the page map to serve.
PORT: TCP port; 0 picks a free one, readable with SERVER-PORT.
ADDRESS: interface to bind; defaults to \"127.0.0.1\".
WATCH: directories to poll; the site refreshes when a file in them changes."
  (let* ((server (make-instance 'dev-server :builder builder :watched watch))
         (acceptor (make-instance 'dev-acceptor
                                  :server server
                                  :port port
                                  :address address
                                  :access-log-destination nil))
         (initial (fingerprint watch)))
    (setf (server-acceptor server) acceptor)
    (rebuild server)
    (hunchentoot:start acceptor)
    (when watch
      (setf (server-watcher server)
            (bt:make-thread (lambda () (watch-loop server initial))
                            :name "quire-watcher")))
    server))

(defun stop-server (server)
  "Stop SERVER: end its watcher and event streams and close the port.

SERVER: the dev server to stop."
  (setf (server-running-p server) nil)
  (when (server-watcher server)
    (bt:join-thread (server-watcher server)))
  (hunchentoot:stop (server-acceptor server))
  nil)
