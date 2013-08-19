#!/usr/bin/env bash
set -eu

type python &>/dev/null &&
[ ! "$(python -V 2>&1)" \< "Python 2.6" ]
