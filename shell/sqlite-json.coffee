#!/usr/bin/env coffee
# Get results of given SQL from SQLite database in JSON format
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2014-02-19
sqlite3 = require "sqlite3"

if process.argv.length < 4
    process.stdout.write "Usage: sqlite-json PATH_TO_DB SQL\n"
    process.exit 1

[pathToDB, sql] = process.argv[2..]

db = new sqlite3.Database pathToDB
db.all sql, (err, rawRows) ->
    if err?
        process.stderr.write err
        process.exit 2
    rows = []
    names = []
    if rawRows.length > 0
        nameIdx = {}
        names = (name for name of rawRows[0])
        for name,i in names
            nameIdx[name] = i
        rows =
            for rawRow in rawRows
                row = []
                for name,value of rawRow
                    row[nameIdx[name]] = value
                row

    process.stdout.write JSON.stringify {names, rows}
    process.stdout.write "\n"
