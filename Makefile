# Makefile for 3X -- EXecutable EXploratory EXperiments
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-10-30

export PATH := $(PWD)/node_modules/.bin:$(PATH)

export BINDIR         := bin
export TOOLSDIR       := tools
export LIBDIR         := lib
export LIBEXECDIR     := libexec
export DATADIR        := data
export GUIDIR         := gui
export DOCSDIR        := docs
export RUNTIMEDEPENDSDIR := $(LIBEXECDIR)/depends

DEPENDSDIR := .depends

PACKAGENAME := 3x
PACKAGEEXECUTES := bin/3x
PACKAGEVERSIONSUFFIX := -$(shell uname)-$(shell uname -m)

include buildkit/modules.mk

buildkit/modules.mk:
	git submodule update --init

# version and build information
$(STAGEDIR)/.build-info.sh:
	# Generating $@
	@{ \
	    echo 'version=$(shell git describe --tags)'; \
	    echo 'version_long=$(shell git describe --tags --long)'; \
	    echo 'version_commit=$(shell git rev-parse HEAD)$(shell $(BUILDKIT)/determine-package-version | cut -b 7-)'; \
	    echo 'build_timestamp=$(shell date +%FT%T%z | sed 's/\(.*\)\([0-9][0-9]\)/\1:\2/')'; \
	    echo 'build_os=$(shell uname)'; \
	    echo 'build_os_release=$(shell uname -r)'; \
	    echo 'build_os_version='"'$(shell uname -v)'"; \
	    echo 'build_machine=$(shell uname -m)'; \
	    echo 'build_hostname=$(shell hostname -f)'; \
	} >$@
polish: $(STAGEDIR)/.build-info.sh

# bundled dependencies
$(BUILDDIR)/timestamp/depends.built: depends/bundle.conf
depends/bundle.conf:
	ln -sfn bundle.conf.all      $@
bundle-all:
	ln -sfn bundle.conf.all      depends/bundle.conf
bundle-minimal:
	ln -sfn bundle.conf.minimal  depends/bundle.conf
.PHONY: bundle-all bundle-minimal


gui-test-loop:
	while sleep .1; do _3X_ROOT="$(PWD)/test-exp"  3x -v gui; done
.PHONY: gui-test-loop


count-loc:
	@[ -d @prefix@ ] || { echo Run make first; false; }
	wc -l $$(find Makefile @prefix@/{tools,bin} gui/{client,server} -type f) shell/package.json \
	    $$(find * \( -name .build -o -name node_modules \) -prune -false -o -name '.module.*') \
	    | sort -n
.PHONY: count-loc

gh-pages-updated:
	-git branch --track gh-pages remotes/origin/gh-pages
	[ -e gh-pages/.git ] || git clone . --branch gh-pages gh-pages
	gh-pages/update-gh-pages.sh
	[ $$(git log origin/master..master README.md | wc -l) -eq 0 ] || git push origin master
	git push origin gh-pages
.PHONY: gh-pages-updated

SINCE ?= --
PAGER ?= less
GIT_DIFF_OPTS ?=
diff-docs: $(PACKAGENAME)-docs.diff.md
$(PACKAGENAME)-docs.diff.md:
	@PATH=$(realpath docs/markdown-diff):$(PATH) GIT_DIFF_OPTS=$(GIT_DIFF_OPTS) \
	    markdown-git-changes $(SINCE) >$@ \
	    README.md docs/*/*.md
	$(PAGER) $@
.PHONY: diff-docs $(PACKAGENAME)-docs.diff.md
