###
# ExpKit Graphical User Interface
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###
express = require "express"
child_process = require "child_process"

expKitPort = parseInt process.argv[2] ? 0



###
# Express.js server
###
app = module.exports = express()

app.configure ->
    #app.set "views", __dirname + "/views"
    #app.set "view engine", "jade"
    app.use express.logger()
    #app.use express.bodyParser()
    #app.use express.methodOverride()
    app.use app.router
    app.use express.static(__dirname + "/../client")

app.configure "development", ->
    app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure "production", ->
    app.use express.errorHandler()


cli = (cmd, args, onOut, onEnd=null, onErr=null) ->
    console.log "CLI running:", cmd, args.map((x) -> "'#{x}'").join " "
    p = child_process.spawn cmd, args
    p.stdout.on "data", onOut
    p.on "exit", onEnd if onEnd?
    p.stderr.on "data", onErr if onErr?


app.get "/api/conditions", (req, res) ->
    buf = ""
    cli "exp-conditions", ["-v"]
        , (data) ->
            buf += data
        , (code) ->
            conditions = {}
            for line in buf.split "\n"
                [name, value] = line.split "=", 2
                conditions[name] = value?.split "," if name?
            res.json(conditions)

app.get "/api/results", (req, res) ->
    args = []
    # TODO runs/batches
    for name,values of JSON.parse req.param("conditions")
        if values?.length > 0
            args.push "#{name}=#{values.join ","}"
    buf = ""
    cli "exp-results", args
        , (data) ->
            buf += data
        , (code) ->
            # TODO error checking with code
            columnIndex = {"#": 0}
            columnNames = ["#"]
            rows = []
            for line in buf.split /\n/
                [run, columns...] = line.split /\s+/
                continue unless run
                row = [run]
                for column in columns
                    [name, value] = column.split "=", 2
                    continue unless name
                    idx = columnIndex[name]
                    unless idx?
                        idx = columnNames.length
                        columnIndex[name] = idx
                        columnNames.push name
                    row[idx] = value
                rows.push row
            res.json(
                names: columnNames
                rows: rows
            )


app.listen expKitPort, ->
    #console.log "ExpKit GUI started at http://localhost:%d/", expKitPort

