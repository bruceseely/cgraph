

(setq filesets-data '(("CGraph System Definition file"
                       (:file "~/repo/cgraph/cgraph.asd" ))
                      ("CGraph Settings file"
                       (:file "~/repo/cgraph/system/setup/definitions.lisp"))
                      ("CGraph Type Definitions"
                       (:pattern "~/.cgraph/types/"     "^.+\\.lisp$"))
                      ("CGraph Code"
                       (:tree "~/repo/cgraph/system/" "^.+\\.lisp$"))
                      ("CGraph Tests"
                       (:tree "~/repo/cgraph/test/" "^.+\\.lisp$"))
                      ("CGraph Notes"
                       (:tree "~/repo/cgraph/notes/" "^.+\\.md$"))
                      ("Support"
                       (:tree "~/repo/cgraph/support/" "^.+\\.lisp$"))
                      ))

(setq filesets-menu-name "Filesets")

(filesets-init)
(filesets-build-menu-now t)
