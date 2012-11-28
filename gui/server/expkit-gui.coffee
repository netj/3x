###
# ExpKit Graphical User Interface
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###
express = require "express"
child_process = require "child_process"

expKitPort = parseInt process.argv[2] ? 0


RUN_COLUMN_NAME = "run#"


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


cliIO = (cmd, args, onOut, onEnd=null, onErr=null) ->
    console.log "CLI running:", cmd, args.map((x) -> "'#{x}'").join " "
    p = child_process.spawn cmd, args
    p.stdout.on "data", onOut
    p.on "exit", onEnd if onEnd?
    p.stderr.on "data", onErr if onErr?

cli = (cmd, args, onEnd) ->
    stdoutBuf = ""
    stderrBuf = ""
    cliIO cmd, args
        , (data) ->
            stdoutBuf += data
        , (code) ->
            onEnd code, stdoutBuf, stderrBuf
        , (data) ->
            stderrBuf += data

handleCLIError = (res, next) -> (code, stdout, stderr) ->
    if code == 0
        next code, stdout, stderr
    else
        res.send 500, stderr


app.get "/api/conditions", (req, res) ->
    cli "exp-conditions", ["-v"]
        , handleCLIError res, (code, stdout, stderr) ->
            conditions = {}
            for line in stdout.split "\n" when line.length > 0
                [name, value] = line.split "=", 2
                if name and value
                    conditions[name] =
                        values: value?.split ","
                        type: "nominal" # FIXME extend exp-conditions to output datatype as well (-t?)
            res.json(conditions)

app.get "/api/measurements", (req, res) ->
    cli "exp-measures", []
        , handleCLIError res, (code, stdout, stderr) ->
            measurements = {}
            measurements[RUN_COLUMN_NAME] =
                type: "nominal"
            for line in stdout.split "\n" when line.length > 0
                [name, type] = line.split ":", 2
                if name?
                    measurements[name] =
                        type: type
            res.json(measurements)

app.get "/api/results", (req, res) ->
    args = []
    # TODO runs/batches
    conditions =
        try
            JSON.parse req.param("conditions")
        catch err
            {}
    for name,values of conditions
        if values?.length > 0
            args.push "#{name}=#{values.join ","}"
    cli "exp-results", args
        , handleCLIError res, (code, stdout, stderr) ->
            columnIndex = {}
            columnNames = [RUN_COLUMN_NAME]
            rows = []
            for line in stdout.split /\n/
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

