SYSTEM := quire

# Every system of the project; the strict build compiles all of them.
SYSTEMS := "quire" "quire/theme-borba" "quire/server" "quire/cli"

# Makes this directory's .asd visible without installing under ~/common-lisp/.
REGISTER := --eval '(push (uiop:getcwd) asdf:*central-registry*)'

# Third-party dependencies load first, outside the handler, because they may
# warn on their own. Then every system of ours is force-compiled, and any WARNING
# or STYLE-WARNING aborts the build. The test system is the one exception for
# redefinition warnings: ASDF reloads its .asd and SBCL reports its macro
# twice, which says nothing about the quality of our code.
DEPENDENCIES := "alexandria" "3bmd" "3bmd-ext-code-blocks" "3bmd-ext-tables" \
	"spinneret" "hunchentoot" "bordeaux-threads" "flexi-streams" \
	"usocket" "fiveam"
STRICT := --eval '(progn \
	(dolist (name (quote ($(DEPENDENCIES)))) (asdf:load-system name)) \
	(handler-bind ((warning (lambda (w) (error "Build not clean: ~A" w)))) \
	(asdf:load-system "quire/cli" :force (quote ($(SYSTEMS))))) \
	(handler-bind ((warning (lambda (w) \
	(unless (typep w (quote sb-kernel:redefinition-warning)) \
	(error "Build not clean: ~A" w))))) \
	(asdf:load-system "quire/tests" :force (list "quire/tests"))))'

.PHONY: build test repl clean sync-design binary

build:
	sbcl --noinform --non-interactive $(REGISTER) $(STRICT)

test: build
	sbcl --noinform --non-interactive $(REGISTER) \
		--eval '(asdf:test-system "$(SYSTEM)")'

repl:
	rlwrap sbcl $(REGISTER) --eval '(asdf:load-system "$(SYSTEM)")'

clean:
	find . -name '*.fasl' -delete
	rm -rf bin

# Copies tokens and fonts from the Borba Design System into the theme.
# The design system is the source of truth: never edit the copies.
DESIGN := $(HOME)/Documents/borba-design-system
THEME_STATIC := themes/borba/static

sync-design:
	cp $(DESIGN)/tokens.css $(THEME_STATIC)/css/tokens.css
	cp $(DESIGN)/fonts/Inter.ttf \
		$(DESIGN)/fonts/JetBrainsMono.ttf \
		$(DESIGN)/fonts/PlayfairDisplay.ttf \
		$(THEME_STATIC)/fonts/

# Standalone executable with the dev server, CLI and Borba theme built in.
binary: build
	mkdir -p bin
	sbcl --noinform --non-interactive $(REGISTER) \
		--eval '(asdf:load-system "quire/cli")' \
		--eval '(quire/cli:save-executable "bin/quire")'
