# Makefile for ExpKit
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-10-30

export PATH := $(PWD)/node_modules/.bin:$(PATH)

export BINDIR         := bin
export TOOLSDIR       := tools

PACKAGENAME := exp
PACKAGEEXECUTES := bin/exp

STAGEDIR := @prefix@
include buildkit/modules.mk
