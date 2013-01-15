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
STATE_COLUMN_NAME = "state#"
SEQUENCE_COLUMN_NAME = "sequence#"

# use text/plain MIME type for ExpKit artifacts in run/
express.static.mime.define
    "text/plain": """
        sh env args stdin stdout stderr exitcode
        run measure
        condition assembly outcome
        plan remaining done count cmdln
    """.split /\s+/

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
    app.use "/run", express.static    "#{process.env.EXPROOT}/run"
    app.use "/run", express.directory "#{process.env.EXPROOT}/run"
    app.use         express.static    "#{__dirname}/../client"

app.configure "development", ->
    app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure "production", ->
    app.use express.errorHandler()

# convert lines of multiple key=value pairs (or named columns) to an array of
# arrays with a header array:
# "k1=v1 k2=v2\nk1=v3 k3=v4\n..." ->
#   { names:[k1,k2,k3,...], rows:[[v1,v2,null],[v3,null,v4],...] }
normalizeNamedColumnLines = (streamOfLines, next
    , lineToKVPairs = (line) -> line.split /\s+/
) ->
    columnIndex = {}
    columnNames = []
    rows = []
    for line in String(streamOfLines).split /\n/
        columns = lineToKVPairs line
        continue unless columns
        row = []
        for column in columns
            [name, value] = column.split "=", 2
            continue unless name and value?
            idx = columnIndex[name]
            unless idx?
                idx = columnNames.length
                columnIndex[name] = idx
                columnNames.push name
            row[idx] = value
        rows.push row
    next {
        names: columnNames
        rows: rows
    }

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
cliEnv = (env, cmd, args, onEnd) ->
    envArgs = ("#{name}=#{value}" for name,value of env)
    cli "env", [envArgs..., cmd, args...], onEnd

handleCLIError = (res, next) -> (code, stdout, stderr) ->
    if code == 0
        next code, stdout, stderr
    else
        res.send 500, stderr

# Allow Cross Origin AJAX Requests
app.options "/api/*", (req, res) ->
    res.set
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS"
        "Access-Control-Allow-Headers": req.get("access-control-request-headers")
    res.send(200)
app.get "/api/*", (req, res, next) ->
    res.set
        "Access-Control-Allow-Origin": "*"
    next()

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
            normalizeNamedColumnLines stdout
                , (results) ->
                    res.json results
                , (line) ->
                    [run, columns...] = line.split /\s+/
                    ["#{RUN_COLUMN_NAME}=#{run}", columns...] if run

app.get "/api/run/batch.DataTables", (req, res) ->
    query = req.param("sSearch") ? ""
    # TODO don't nest these, try to do them in parallel
    cliEnv {
        LIMIT:  req.param("iDisplayLength")
        OFFSET: req.param("iDisplayStart")
    }, "exp-batches", ["-l", query]
        , handleCLIError res, (code, stdout, stderr) ->
            table =
                for line in stdout.trim().split(/\n/) when line != ""
                    col for col in line.split(/\t/)
            cli "exp-batches", ["-c", query]
                , handleCLIError res, (code, stdout, stderr) ->
                    filteredCount = +stdout.trim()
                    cli "exp-batches", ["-c"]
                        , handleCLIError res, (code, stdout, stderr) ->
                            totalCount = +stdout.trim()
                            res.json
                                sEcho: req.param("sEcho")
                                iTotalRecords: totalCount
                                iTotalDisplayRecords: filteredCount
                                aaData: table

app.get "/api/run/batch/:batchId", (req, res) ->
    batchId = req.param("batchId")
    # TODO sanitize batchId
    cli "exp-status", [batchId]
        , handleCLIError res, (code, stdout, stderr) ->
            normalizeNamedColumnLines stdout
                , (results) ->
                    res.json results
                , (line) ->
                    [state, columns..., sequence] = line.split /\s+/
                    sequence = +(sequence?.replace /^#/, "")
                    ["#{STATE_COLUMN_NAME}=#{state}", "#{SEQUENCE_COLUMN_NAME}=#{sequence}", columns...] if state


app.listen expKitPort, ->
    #console.log "ExpKit GUI started at http://localhost:%d/", expKitPort

