#!/usr/bin/env coffee
# coalesce-values-by-name -- Coalesce value part of the arguments by name
# Usage:
# > coalesce-by-names NAME_DELIM VALUE_DELIM ARG...
# 
# Example:
# The following command:
# > coalesce-by-names = , program=f program=g x=1 x=2,3 y=abcd z= k="k's value"
# 
# will output:
#   'program=f,g' 'x=1,2,3' 'y=abcd' 'z=' 'k=k'\''s value'
# 
# Therefore, you should use it in your shell script as follows:
# > eval "set -- $(coalesce-by-names = , "$@")"
# 
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-02-13
[_,_, nameDelim, valueDelim, args...] = process.argv
ordering = []
values = {}
for arg in args
    [name,vs] = arg.split nameDelim, 2
    ordering.push name unless name in ordering
    values[name] ?= []
    if vs?
        for v in vs.split valueDelim
            values[name].push v unless v in values[name]
esc = (s) -> s.replace /'/g, "'\\''"
console.log (
        for name in ordering
            "'#{esc(name)}#{nameDelim}#{values[name].map(esc).join valueDelim}'"
    ).join " "
