###
# 3X Graphical User Interface
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###
express = require "express"
http = require "http"
socketIO = require "socket.io"
StreamSplitter = require "stream-splitter"

util = require "util"
fs = require "fs"
os = require "os"
child_process = require "child_process"

mktemp = require "mktemp"
_ = require "underscore"
async = require "async"
Lazy = require "lazy"

jade = require "jade"
marked = require "marked"


_3X_ROOT                   = process.env._3X_ROOT
_3X_GUIPORT                = parseInt process.argv[2] ? 0
process.env.SHLVL          = "0"
process.env._3X_LOGLVL  = "1"
process.env._3X_LOGMSGS = "true"


RUN_COLUMN_NAME = "run#"
STATE_COLUMN_NAME = "state#"
SERIAL_COLUMN_NAME = "serial#"

# use text/plain MIME type for 3X artifacts in run/
express.static.mime.define
    "text/plain": """
        sh bash
        pl py rb js coffee
        c h cc cpp hpp cxx C i ii
        Makefile
    """.split /\s+/

RUN_OVERVIEW_FILENAMES = """
    input output
    stdout stderr exitcode rusage
    env args stdin
    assembly
""".split(/\s+/).filter((f) -> f?.length > 0)

_3X_DESCRIPTOR = do ->
    [basename] = _3X_ROOT.match /[^/]+$/
    desc = String(fs.readFileSync "#{_3X_ROOT}/.3x/description").trim()
    if desc == "Unnamed repository; edit this file 'description' to name the repository."
        desc = null
    {
        name: basename
        description: desc
        fileSystemPath: _3X_ROOT
        hostname: os.hostname()
        port: _3X_GUIPORT
    }

###
# Express.js server
###
app = module.exports = express()
server = http.createServer app
io = socketIO.listen server

app.configure ->
    app.set "views", "#{__dirname}/views"
    app.set "view engine", "jade"

    app.use express.logger()
    app.use express.bodyParser()
    #app.use express.methodOverride()
    app.use app.router
    app.use "/run", express.static    "#{_3X_ROOT}/run"
    app.use "/run", express.directory "#{_3X_ROOT}/run"
    app.use         express.static    "#{__dirname}/../client"

app.configure "development", ->
    app.use express.errorHandler({ dumpExceptions: true, showStack: true })
    io.set "log level", 1

app.configure "production", ->
    app.use express.errorHandler()
    io.set "log level", 0

###
# Some routes
###

docsCache = {}
app.get "/docs/*", (req, res) ->
    path = req.params[0]
    title = path
    filepath = "#{process.env.DOCSDIR}/#{path}.md"
    markdown = (filename) ->
        marked String(fs.readFileSync filename)
    res.render "docs", {_3X_DESCRIPTOR, title, markdown, path, filepath}
    #if filepath in docsCache
    #    respond docsCache[filepath]
    #else
    #    fs.readFile filepath, (err, contents) ->
    #        return res.send 404, "Not found #{err}" if err
    #        docsCache[filepath] = contents
    #        respond contents


# Redirect to its canonical location when a run is requested via serial of batch
app.get "/run/batch/:batchId/runs/:serial", (req, res, next) ->
    fs.realpath "#{_3X_ROOT}/#{req.path}", (err, path) ->
        res.redirect path.replace(_3X_ROOT, "")


# Show an overview page for runs
app.get "/run/*/overview", (req, res) ->
    runId = "run/#{req.params[0]}"
    readFileIfExists = (filename, next) ->
        fs.readFile filename, (err, contents) ->
            if err then next null, null
            else next null, contents
    async.parallel [
        (next) -> async.map ("#{_3X_ROOT}/#{runId}/#{filename}" for filename in RUN_OVERVIEW_FILENAMES), readFileIfExists, next
        getInputs  res, "-ut"
        getOutputs res, "-ut"
    ], (err, [results, inputs, outputs]) ->
        files = {}
        for filename,i in RUN_OVERVIEW_FILENAMES
            files[filename] = results[i]
        parseKeyValuePairs = (lines, map) ->
            for kvp in String(lines).split /\n+/ when (m = /// ([^=]+) = (.*) ///.exec kvp)?
                ty = map[m[1]]?.type
                name: m[1]
                value: m[2]
                type: ty
                unit: map[m[1]]?.unit
                presentation: (
                    if /// ^image/.* ///.test ty then "image"
                    else if /// .* / .* ///.test ty then "file"
                    else "scalar"
                )
        input  = parseKeyValuePairs files.input,  inputs
        output = parseKeyValuePairs files.output, outputs
        delete files.input
        delete files.output
        res.render "run-overview", {_3X_DESCRIPTOR, title:runId, runId, files, input, output}


# Override content type for run directory
app.get "/run/*", (req, res, next) ->
    path = req.params[0]
    unless path.match ///.+(/workdir/.+|/$)///
        res.type "text/plain"
    do next


# convert lines of multiple key=value pairs (or named columns) to an array of
# arrays with a header array:
# "k1=v1 k2=v2\nk1=v3 k3=v4\n..." ->
#   { names:[k1,k2,k3,...], rows:[[v1,v2,null],[v3,null,v4],...] }
normalizeNamedColumnLines = (
        lineToKVPairs = (line) -> line.split /\s+/
) -> (lazyLines, next) ->
    columnIndex = {}
    columnNames = []
    lazyLines
        .map(String)
        .map(lineToKVPairs)
        .filter((x) -> x?)
        .map((columns) ->
            row = []
            for column in columns
                m = /^([^=]+)=(.*)$/.exec column
                continue unless m
                [__, name, value] = m
                idx = columnIndex[name]
                unless idx?
                    idx = columnNames.length
                    columnIndex[name] = idx
                    columnNames.push name
                row[idx] = value
            row
        )
        .join((rows) ->
            next {
                names: columnNames
                rows: rows
            }
        )

generateNamedColumnLines = (data, columns = null) ->
    names = {}
    for name,i in data.names when not columns? or name in columns
        names[name] = i
    for row in data.rows
        (" #{name}=#{row[i]}" for name,i of names).join " "

###
# CLI helpers
###
cliBare = (cmd, args
        , withOut = ((outLines, next) -> outLines.join next)
        , withErr = ((errLines, next) -> errLines.join next)
) -> (next) ->
    util.log "CLI running: #{cmd} #{args.map((x) -> "'#{x}'").join " "}"
    #util.log "  cwd: #{_3X_ROOT}"
    #util.log "  env: #{process.env}"
    p = child_process.spawn cmd, args,
        cwd: _3X_ROOT
        env: process.env
    _code = null; _result = null; _error = null
    tryEnd = ->
        if _code? and _error? and _result?
            _error = null unless _error?.length > 0
            try next _code, _error, _result...
            catch err
                util.log err
    withOut Lazy(p.stdout).lines.map(String), (result...) -> _result = result; do tryEnd
    withErr Lazy(p.stderr).lines.map(String), (error)     -> _error  = error ; do tryEnd
    p.on "exit",                              (code)      -> _code   = code  ; do tryEnd

cliBareEnv = (env, cmd, args, rest...) ->
    envArgs = ("#{name}=#{value}" for name,value of env)
    cliBare "env", [envArgs..., cmd, args...], rest...

handleNonZeroExitCode = (res, next) -> (code, err, result...) ->
    if code is 0
        next null, result...
    else
        res.send 500, (err?.join "\n") ? err
        next err ? code, result...

cli    =  (res, rest...) -> (next) ->
    (cliBare    rest...) (handleNonZeroExitCode res, next)

cliEnv =  (res, rest...) -> (next) ->
    (cliBareEnv rest...) (handleNonZeroExitCode res, next)

respondJSON = (res) -> (err, result) ->
    res.json result unless err

cliSimple = (cmd, args...) ->
    cliBare(cmd, args) (code, err, out) ->
        util.log err unless code is 0


# Allow Cross Origin AJAX Requests
# Cross Origin Resource Sharing (CORS)
# See: http://en.wikipedia.org/wiki/Cross-Origin_Resource_Sharing
# See: https://developer.mozilla.org/en-US/docs/HTML/CORS_Enabled_Image
app.options "/*", (req, res) ->
    res.set
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS"
        "Access-Control-Allow-Headers": req.get("access-control-request-headers")
    res.send(200)
app.all "/*", (req, res, next) ->
    res.set
        "Access-Control-Allow-Origin": "*"
    next()


app.get "/api/description", (req, res) ->
    res.json _3X_DESCRIPTOR

app.get "/api/inputs", (req, res) ->
    (getInputs res) (err, inputs) -> res.json inputs unless err
getInputs = (res, opts = "-utv") -> (next) ->
    cli(res, "3x-inputs", [opts]
        , (lazyLines, next) -> lazyLines
                .filter((line) -> line.length > 0)
                .map((line) ->
                        if m = /^([^=:(]+)(\(([^)]+)\))?(:([^=]+))?(=(.*))?$/.exec line
                            [__, name, __, unit, __, type, __, values] = m
                            [name,
                                values: values?.split ","
                                type: type
                                unit: unit
                            ]
                    )
                .join (pairs) -> next (_.object pairs)
    ) next

app.get "/api/outputs", (req, res) ->
    (getOutputs res) (err, outputs) -> res.json outputs unless err
getOutputs = (res, opts = "-ut") -> (next) ->
    cli(res, "3x-outputs", [opts]
        , (lazyLines, next) -> lazyLines
                .filter((line) -> line.length > 0)
                .map((line) ->
                    if m = /^([^:(]+)(\(([^)]+)\))?(:(.*))?$/.exec line
                        [__, name, __, unit, __, type] = m
                        [name,
                            type: type
                            unit: unit
                        ]
                )
                .join (pairs) -> next (_.object pairs)
    ) (err, outputs) ->
        unless err
            outputs[RUN_COLUMN_NAME] =
                type: "nominal"
        next err, outputs

app.get "/api/results", (req, res) ->
    args = [] # TODO use a tab separated format directly from 3x-results
    # TODO runs/batches
    inputs  = (try JSON.parse req.param("inputs") ) ? {}
    outputs = (try JSON.parse req.param("outputs")) ? {}
    for name,values of inputs
        if values?.length > 0
            args.push "#{name}=#{values.join ","}"
    for name,exprs of outputs when _.isArray exprs
        for [rel, literal] in exprs
            args.push "#{name}#{rel}#{literal}"
    cli(res, "3x-results", args
        , normalizeNamedColumnLines (line) ->
                [run, columns...] = line.split /\s+/
                ["#{RUN_COLUMN_NAME}=#{run}", columns...] if run
    ) (err, results) ->
        res.json results unless err

app.get "/api/run/batch.DataTables", (req, res) ->
    query = req.param("sSearch") ? ""
    async.parallel [
            cliEnv res, {
                LIMIT:  req.param("iDisplayLength") ? -1
                OFFSET: req.param("iDisplayStart") ? 0
            }, "3x-batches", ["--", query]
                , (lazyLines, next) ->
                    lazyLines
                        .skip(1)
                        .filter((line) -> line isnt "")
                        .map((line) -> line.split /\t/)
                        .join next
        ,
            cli res, "3x-batches", ["-c", query]
                , (lazyLines, next) ->
                    lazyLines
                        .take(1)
                        .join ([line]) -> next (+line?.trim())
        ,
            cli res, "3x-batches", ["-c"]
                , (lazyLines, next) ->
                    lazyLines
                        .take(1)
                        .join ([line]) -> next (+line?.trim())
        ], (err, [table, filteredCount, totalCount]) ->
            unless err
                res.json
                    sEcho: req.param("sEcho")
                    iTotalRecords: totalCount
                    iTotalDisplayRecords: filteredCount
                    aaData: table

app.get "/api/run/batch.numRUNNING", (req, res) ->
    cli(res, "sh", ["-c", "3x-batches | grep -c RUNNING || true"]
        , (lazyLines, next) ->
            lazyLines
                .take(1)
                .join ([line]) -> next (+line?.trim())
    ) (err, count) ->
        res.json count unless err

app.get ////api/run/batch/([^:]+):(start|stop)///, (req, res) ->
    batchId = req.params[0]
    # TODO sanitize batchId
    action = req.params[1]
    cli(res, "sh", ["-c", "SHLVL=0 3x-#{action} run/batch/#{batchId} </dev/null >>.3x/gui/log.runs 2>&1 &"]
        , (lazyLines, next) ->
            lazyLines
                .join -> next (true)
    ) (err, result) ->
        res.json result unless err

app.get "/api/run/batch/:batchId", (req, res) ->
    batchId = req.param("batchId")
    # TODO sanitize batchId
    batchPath = "run/batch/#{batchId}"
    fs.stat "#{_3X_ROOT}/#{batchPath}", (err, stat) ->
        return res.send 404, "Not found: #{batchPath}" if err?
        cli(res, "3x-status", [batchPath]
            , normalizeNamedColumnLines (line) ->
                    [state, columns..., serial, runId] = line.split /\s+/
                    serial = (serial?.replace /^#/, "")
                    runId = "" if runId is "?"
                    if state
                        [
                            "#{STATE_COLUMN_NAME}=#{state}"
                            "#{SERIAL_COLUMN_NAME}=#{serial}"
                            "#{RUN_COLUMN_NAME}=#{runId}"
                            columns...
                        ]
        ) (err, batch) ->
            res.json batch unless err

app.post "/api/run/batch/*", (req, res) ->
    batchId = req.params[0]
    batchId = if batchId?.length is 0 then null else "run/batch/#{batchId}"
    # TODO sanitize batchId
    try
        plan        = JSON.parse req.body.plan
    catch err
        return res.send 400, "Bad request\nplan must be posted in strict JSON format"
    shouldStart = req.body.shouldStart?

    generatePlanLines = ->
        columns = (name for name in plan.names when name.indexOf("#") is -1)
        serialCol = plan.names.indexOf SERIAL_COLUMN_NAME
        (for line,idx in generateNamedColumnLines(plan, columns)
            serial = plan.rows[idx][serialCol]
            "3x run#{line} ##{serial}"
        ).join "\n"

    # start right away if shouldStart
    startIfNeeded = (batchId) ->
        if shouldStart
            try cliSimple "sh", "-c", "SHLVL=0 3x-start #{batchId} </dev/null >>.3x/gui/log.runs 2>&1 &"

    mktemp.createFile "#{_3X_ROOT}/.3x/plan.XXXXXX", (err, planFile) ->
        andRespond = (err, [batchId]) ->
            # remove temporary file
            unless err
                res.json batchId
                startIfNeeded batchId
            try cliSimple "rm", "-f", planFile
        fs.writeFile planFile, generatePlanLines(), ->
            if batchId? # modify existing one
                cli(res, "3x-edit", [batchId, planFile]
                ) andRespond
            else # create a new batch
                cli(res, "3x-plan", ["with", planFile]
                ) andRespond


server.listen _3X_GUIPORT, ->
    #util.log "3X GUI started at http://localhost:#{_3X_GUIPORT}/"



###### incremental updates via WebSockets with Socket.IO

batchSockets =
io.of("/run/batch/")
    .on "connection", (socket) ->
        updateRunningCount socket

updateRunningCount = (socket = batchSockets) ->
    cliBare("sh", ["-c", "3x-batches | grep -c RUNNING || true"]
        , (lazyLines, next) ->
            lazyLines
                .take(1)
                .join ([line]) -> next (+line?.trim())
    ) (code, err, count) ->
        socket.volatile.emit "running-count", count

batchRootDir = "#{_3X_ROOT}/run/batch/"
batchNotifyChange = (event, fullpath) ->
    # assuming first path component is the batch ID
    batchIdProper = fullpath?.substring(batchRootDir.length).replace /\/.*$/, ""
    filename = fullpath?.substring((batchRootDir + batchIdProper).length)
    return unless batchIdProper?
    batchId = "run/batch/#{batchIdProper}"
    util.log "WATCH #{batchId} #{event} #{filename}"
    if filename is "/plan"
        batchSockets.volatile.emit "listing-update", [batchId, event]
    else if filename.match /// ^/( worker-\d+\.lock )$ ///
        do updateRunningCount
    else if filename.match /// ^/( running\.[^/]+/lock )$ ///
        batchSockets.volatile.emit "state-update", [
            batchId
            if event is "deleted" then "PAUSED" else "RUNNING"
            # TODO pass new progress: running/done/remaining/total
        ]

# Use Python watchdog to monitor filesystem changes
fsMonitor = null
do startFSMonitor = ->
    util.log "starting filesystem monitor"
    fsMonitor =
    p = child_process.spawn "watchmedo", [
        'shell-command'
        '--recursive'
        '--patterns=*'
        '--command=echo ${watch_event_type} "${watch_src_path}"'
        batchRootDir
    ]
    splitter = p.stdout.pipe(StreamSplitter("\n"))
    splitter.on "token", (line) ->
        [__, event, path] = /^(\S+) (.*)$/.exec(line) ? []
        batchNotifyChange event, path
    # respawn when watchmedo process exits
    p.on "exit", (code, signal) ->
        _.defer startFSMonitor


# Exit hooks, Signal handler
process.on "exit", ->
    util.log "Shutting down..."
    do fsMonitor?.kill
shutdown = (sig) -> ->
    util.log "Got SIG#{sig}."
    process.exit 2
for sig in "INT QUIT TERM".split /\s+/
    process.on "SIG#{sig}", shutdown sig
