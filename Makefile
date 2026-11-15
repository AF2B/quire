SYSTEM := quire

# Makes this directory's .asd visible without installing under ~/common-lisp/.
REGISTER := --eval '(push (uiop:getcwd) asdf:*central-registry*)'

# Any WARNING or STYLE-WARNING during load aborts the build.
STRICT := --eval '(handler-bind ((warning (lambda (w) (error "Build not clean: ~A" w)))) \
	(asdf:load-system "$(SYSTEM)" :force t))'

.PHONY: build test repl clean

build:
	sbcl --noinform --non-interactive $(REGISTER) $(STRICT)

test: build
	sbcl --noinform --non-interactive $(REGISTER) \
		--eval '(asdf:test-system "$(SYSTEM)")'

repl:
	rlwrap sbcl $(REGISTER) --eval '(asdf:load-system "$(SYSTEM)")'

clean:
	find . -name '*.fasl' -delete
