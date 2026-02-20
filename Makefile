EMACS ?= emacs

.PHONY: test
test:
	$(EMACS) -Q --batch -L . -L test -l test/perspective-project-bridge-test.el -f ert-run-tests-batch-and-exit
