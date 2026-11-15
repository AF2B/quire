(asdf:defsystem "quire"
  :description "Static site generator: pages as functions, sites as data."
  :version "0.1.0"
  :serial t
  :depends-on ("alexandria")
  :components ((:module "src"
                :components ((:file "conditions")
                             (:file "paths")
                             (:file "page")
                             (:file "page-map"))))
  :in-order-to ((test-op (test-op "quire/tests"))))

(asdf:defsystem "quire/tests"
  :description "FiveAM test suite for quire."
  :depends-on ("quire"
               "fiveam")
  :serial t
  :components ((:module "tests"
                :components ((:file "suite")
                             (:file "paths-tests")
                             (:file "page-tests")
                             (:file "page-map-tests"))))
  :perform (test-op (operation component)
             (declare (ignore operation component))
             (uiop:symbol-call '#:quire/tests/suite '#:run-tests)))
