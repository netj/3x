# Makefile for 3X -- EXecutable EXploratory EXperiments
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-10-30

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

APPNAME := 3X
APPIDENT := edu.stanford.infolab.3x
APPCOPYRIGHT := © 2013 InfoLab, Stanford University.
APPICON := gui/app-icon.icns
APPEXECUTES := for d; do (cd "$$d"; exec 3x gui start &) </dev/null >/dev/null 2>&1; done
APPPATHDIR := bin

.DEFAULT: polish
polish:

include buildkit/modules.mk

buildkit/test-with-bats.mk \
buildkit/modules.mk:
	git submodule update --init

# version and build information
$(STAGEDIR)/.build-info.sh: stage
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
$(POLISHED): $(STAGEDIR)/.build-info.sh

# bundled dependencies
$(BUILDDIR)/timestamp/depends.built: depends/bundle.conf
depends/bundle.conf:
	ln -sfn bundle.conf.all      $@
bundle-all:
	ln -sfn bundle.conf.all      depends/bundle.conf
bundle-minimal:
	ln -sfn bundle.conf.minimal  depends/bundle.conf
.PHONY: bundle-all bundle-minimal


# optionally optmize GUI with requirejs
ifdef PACKAGE_OPTIMIZED
$(PACKAGE): optimized-gui
endif
optimized-gui: stage
	coffee -pb gui/.build/client/src/app.build.coffee | \
	    sed '$$s/;$$//' >$(STAGEDIR)/$(GUIDIR)/files/app.build.js
	bash -O extglob -euc ' \
	cd $(STAGEDIR)/gui/files; \
	    r.js -o app.build.js; \
	    rm -f resource.opt/{!(main|require).js,!(main.js).map,{,*/}*/*.css,build.txt}; \
	    mv -f resource resource.orig; mv -f resource.opt resource; \
	    rm -rf resource.orig'
.PHONY: optimized-gui


# keep launching GUI (to be used with keymap in gui/.lvimrc)
gui-test-loop: test-exp
	while sleep .1; do \
    relsymlink gui/.build/client/src $(STAGEDIR)/$(GUIDIR)/files/; \
    _3X_ROOT="$(PWD)/test-exp" \
        $(STAGEDIR)/bin/3x -v gui; \
done
.PHONY: gui-test-loop

# set up a sample experiment for testing
test-exp:
	env $(STAGEDIR)/bin/3x setup $@ \
	  --program \
	    'python measure.py $$algo $$inputSize $$inputType' \
	  --inputs \
	    'inputSize'='10,11,12,13,14,15,16,17,18' \
	    'inputType'='random,ordered,reversed' \
	    'algo'='bubbleSort,selectionSort,insertionSort,quickSort,mergeSort' \
	  --outputs \
	    --extract 'sorting time \(s\): {{sortingTime(s) =~ .+}}' \
	    --extract 'number of compares: {{numCompare =~ .+}}' \
	    --extract 'number of accesses: {{numAccess =~ .+}}' \
	    --extract 'input sorted ratio: {{ratioSortedIn =~ .+}}' \
	    --extract 'output sorted ratio: {{ratioSortedOut =~ .+}}' \
	    --extract 'input generation time \(s\): {{inputTime(s) =~ .+}}' \
	    --extract 'verification time \(s\): {{verificationTime(s) =~ .+}}' \
	  # end of 3x setup
	cp -f docs/examples/sorting-algos/program/*.py $@/program/


count-loc:
	@[ -d @prefix@ ] || { echo Run make first; false; }
	wc -l $$(find Makefile @prefix@/{tools,bin} gui/{client,server} -type f) shell/package.json \
	    $$(find * \( -name .build -o -name node_modules \) -prune -false -o -name '.module.*') \
	    | sort -n
.PHONY: count-loc

gh-pages-updated:
	buildkit/update-gh-pages
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


include buildkit/test-with-bats.mk
