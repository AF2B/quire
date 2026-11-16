(asdf:defsystem "quire"
  :description "Static site generator: pages as functions, sites as data."
  :version "0.1.0"
  :author "André Borba"
  :license "MIT"
  :serial t
  :depends-on ("3bmd"
               "3bmd-ext-code-blocks"
               "3bmd-ext-tables"
               "alexandria")
  :components ((:module "src"
                :components ((:file "conditions")
                             (:file "paths")
                             (:file "page")
                             (:file "page-map")
                             (:file "files")
                             (:file "front-matter")
                             (:file "dates")
                             (:file "markdown")
                             (:file "site")
                             (:file "content")
                             (:file "xml")
                             (:file "steps")
                             (:file "feed")
                             (:file "atom")
                             (:file "sitemap")
                             (:file "build")
                             (:file "check")
                             (:file "export")
                             (:file "quire"))))
  :in-order-to ((test-op (test-op "quire/tests"))))

(asdf:defsystem "quire/theme-borba"
  :description "Default theme for quire, built on the Borba Design System."
  :version "0.1.0"
  :author "André Borba"
  :license "MIT"
  :pathname "themes/borba/"
  :serial t
  :depends-on ("alexandria"
               "quire"
               "spinneret")
  :components ((:file "assets")
               (:file "layouts")))

(asdf:defsystem "quire/server"
  :description "Development server for quire with live reload."
  :version "0.1.0"
  :author "André Borba"
  :license "MIT"
  :pathname "server/"
  :serial t
  :depends-on ("alexandria"
               "bordeaux-threads"
               "flexi-streams"
               "hunchentoot"
               "quire")
  :components ((:file "server")))

(asdf:defsystem "quire/cli"
  :description "Command line interface and executable entry point of quire."
  :version "0.1.0"
  :author "André Borba"
  :license "MIT"
  :pathname "cli/"
  :serial t
  :depends-on ("alexandria"
               "quire"
               "quire/server"
               "quire/theme-borba")
  :components ((:file "user")
               (:file "cli")))

(asdf:defsystem "quire/tests"
  :description "FiveAM test suite for quire."
  :depends-on ("quire"
               "quire/cli"
               "quire/server"
               "quire/theme-borba"
               "fiveam"
               "usocket")
  :serial t
  :components ((:module "tests"
                :components ((:file "suite")
                             (:file "support")
                             (:file "paths-tests")
                             (:file "page-tests")
                             (:file "page-map-tests")
                             (:file "front-matter-tests")
                             (:file "dates-tests")
                             (:file "markdown-tests")
                             (:file "content-tests")
                             (:file "xml-tests")
                             (:file "steps-tests")
                             (:file "feed-tests")
                             (:file "atom-tests")
                             (:file "sitemap-tests")
                             (:file "export-tests")
                             (:file "build-tests")
                             (:file "check-tests")
                             (:file "theme-tests")
                             (:file "server-tests")
                             (:file "cli-tests"))))
  :perform (test-op (operation component)
             (declare (ignore operation component))
             (uiop:symbol-call '#:quire/tests/suite '#:run-tests)))
