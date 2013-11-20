#!/usr/bin/env bash

DocumentUpOptions=(
    repo="netj/3x"
    google_analytics="UA-29293848-3"
)

# README preview
mirror-master .
compile-markdown . name="3X" #"3X for eXecuting eXploratory eXperiments"

# Features
mirror-master docs/features
compile-markdown docs/features name="3X Features"

# Tutorial
mirror-master docs/tutorial
compile-markdown docs/tutorial name="3X Tutorial"
# and examples
mirror-master docs/examples

# Installation
mirror-master docs/install
compile-markdown docs/install name="3X Installation"
