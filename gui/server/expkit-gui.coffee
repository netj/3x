###
# ExpKit Graphical User Interface
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###
express = require "express"
http = require "http"
socketIO = require "socket.io"
fs = require "fs"
os = require "os"
child_process = require "child_process"
mktemp = require "mktemp"
async = require "async"
Lazy = require "lazy"
StreamSplitter = require "stream-splitter"
_ = require "underscore"

EXPROOT = process.env.EXPROOT
EXPGUIPORT = parseInt process.argv[2] ? 0


RUN_COLUMN_NAME = "run#"
STATE_COLUMN_NAME = "state#"
SERIAL_COLUMN_NAME = "serial#"

# use text/plain MIME type for ExpKit artifacts in run/
express.static.mime.define
    "text/plain": """
        sh
    """.split /\s+/

###
# Express.js server
###
app = module.exports = express()
server = http.createServer app
io = socketIO.listen server

app.configure ->
    #app.set "views", __dirname + "/views"
    #app.set "view engine", "jade"
    app.use express.logger()
    app.use express.bodyParser()
    #app.use express.methodOverride()
    app.use app.router
    app.use "/run", express.static    "#{EXPROOT}/run"
    app.use "/run", express.directory "#{EXPROOT}/run"
    app.use         express.static    "#{__dirname}/../client"

app.configure "development", ->
    app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure "production", ->
    app.use express.errorHandler()

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
                [name, value] = column.split "=", 2
                continue unless name and value?
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
    console.log "CLI running:", cmd, args.map((x) -> "'#{x}'").join " "
    p = child_process.spawn cmd, args
    _code = null; _result = null; _error = null
    tryEnd = ->
        if _code? and _error? and _result?
            _error = null unless _error?.length > 0
            next _code, _error, _result...
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
        console.error err unless code is 0


# Redirect to its canonical location when a run is requested via serial of batch
app.get "/run/batch/:batchId/runs/:serial", (req, res, next) ->
    fs.realpath "#{EXPROOT}/#{req.path}", (err, path) ->
        res.redirect path.replace(EXPROOT, "")


# Override content type for run directory
app.get "/run/*", (req, res, next) ->
    path = req.params[0]
    unless path.match ///.+(/workdir/.+|/$)///
        console.log "text", path
        res.type "text/plain"
    do next


# Allow Cross Origin AJAX Requests
app.options "/api/*", (req, res) ->
    res.set
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS"
        "Access-Control-Allow-Headers": req.get("access-control-request-headers")
    res.send(200)
app.all "/api/*", (req, res, next) ->
    res.set
        "Access-Control-Allow-Origin": "*"
    next()


app.get "/api/description", (req, res) ->
    [basename] = EXPROOT.match /[^/]+$/
    desc = String(fs.readFileSync "#{EXPROOT}/.exp/description").trim()
    if desc == "Unnamed repository; edit this file 'description' to name the repository."
        desc = null
    res.json
        name: basename
        description: desc
        fileSystemPath: EXPROOT
        hostname: os.hostname()
        port: EXPGUIPORT

app.get "/api/conditions", (req, res) ->
    cli(res, "exp-conditions", ["-v"]
        , (lazyLines, next) -> lazyLines
                .filter((line) -> line.length > 0)
                .map((line) ->
                        [name, value] = line.split "=", 2
                        if name and value
                            [name,
                                values: value?.split ","
                                type: "nominal" # FIXME extend exp-conditions to output datatype as well (-t?)
                            ]
                    )
                .join (pairs) -> next (_.object pairs)
    ) (err, conditions) ->
        res.json conditions unless err

app.get "/api/measurements", (req, res) ->
    cli(res, "exp-measures", []
        , (lazyLines, next) -> lazyLines
                .filter((line) -> line.length > 0)
                .map((line) ->
                    [name, type] = line.split ":", 2
                    if name?
                        [name,
                            type: type
                        ]
                )
                .join (pairs) -> next (_.object pairs)
    ) (err, measurements) ->
        unless err
            measurements[RUN_COLUMN_NAME] =
                type: "nominal"
            res.json measurements

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
    cli(res, "exp-results", args
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
            }, "exp-batches", ["--", query]
                , (lazyLines, next) ->
                    lazyLines
                        .skip(1)
                        .filter((line) -> line isnt "")
                        .map((line) -> line.split /\t/)
                        .join next
        ,
            cli res, "exp-batches", ["-c", query]
                , (lazyLines, next) ->
                    lazyLines
                        .take(1)
                        .join ([line]) -> next (+line.trim())
        ,
            cli res, "exp-batches", ["-c"]
                , (lazyLines, next) ->
                    lazyLines
                        .take(1)
                        .join ([line]) -> next (+line.trim())
        ], (err, [table, filteredCount, totalCount]) ->
            unless err
                res.json
                    sEcho: req.param("sEcho")
                    iTotalRecords: totalCount
                    iTotalDisplayRecords: filteredCount
                    aaData: table

app.get "/api/run/batch.numRUNNING", (req, res) ->
    cli(res, "sh", ["-c", "exp-batches | grep -c RUNNING || true"]
        , (lazyLines, next) ->
            lazyLines
                .take(1)
                .join ([line]) -> next (+line.trim())
    ) (err, count) ->
        res.json count unless err

app.get ////api/run/batch/([^:]+):(start|stop)///, (req, res) ->
    batchId = req.params[0]
    # TODO sanitize batchId
    action = req.params[1]
    cli(res, "sh", ["-c", "exp-#{action} run/batch/#{batchId} </dev/null &>/dev/null &"]
        , (lazyLines, next) ->
            lazyLines
                .join -> next (true)
    ) (err, result) ->
        res.json result unless err

app.get "/api/run/batch/:batchId", (req, res) ->
    batchId = req.param("batchId")
    # TODO sanitize batchId
    batchPath = "run/batch/#{batchId}"
    fs.exists "#{EXPROOT}/#{batchPath}", (exists) ->
        return res.send 404, "Not found: #{batchPath}" unless exists
        cli(res, "exp-status", [batchPath]
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
            "exp run#{line} ##{serial}"
        ).join "\n"

    # start right away if shouldStart
    startIfNeeded = (batchId) ->
        if shouldStart
            try cliSimple "sh", "-c", "exp-start #{batchId} </dev/null &>/dev/null &"

    mktemp.createFile "#{EXPROOT}/.exp/plan.XXXXXX", (err, planFile) ->
        andRespond = (err, [batchId]) ->
            # remove temporary file
            unless err
                res.json batchId
                startIfNeeded batchId
            try cliSimple "rm", "-f", planFile
        fs.writeFile planFile, generatePlanLines(), ->
            if batchId? # modify existing one
                cli(res, "exp-edit", [batchId, planFile]
                ) andRespond
            else # create a new batch
                cli(res, "exp-plan", ["with", planFile]
                ) andRespond


server.listen EXPGUIPORT, ->
    #console.log "ExpKit GUI started at http://localhost:%d/", EXPGUIPORT



###### incremental updates via WebSockets with Socket.IO

batchSockets =
io.of("/run/batch/")
    .on "connection", (socket) ->
        updateRunningCount socket

updateRunningCount = (socket = batchSockets) ->
    cliBare("sh", ["-c", "exp-batches | grep -c RUNNING || true"]
        , (lazyLines, next) ->
            lazyLines
                .take(1)
                .join ([line]) -> next (+line.trim())
    ) (code, err, count) ->
        socket.volatile.emit "running-count", count

batchRootDir = "#{EXPROOT}/run/batch/"
batchNotifyChange = (event, fullpath) ->
    console.log "WATCH #{event} #{fullpath}"
    # assuming first path component is the batch ID
    batchIdProper = fullpath?.substring(batchRootDir.length).replace /\/.*$/, ""
    filename = fullpath?.substring((batchRootDir + batchIdProper).length)
    return unless batchIdProper?
    batchId = "run/batch/#{batchIdProper}"
    console.log "WATCH #{batchId} #{event} #{filename}"
    if filename is "/plan"
        batchSockets.volatile.emit "listing-update", [batchId, event]
    else if filename.match /// ^/worker-\d+\.lock$ /// or filename.match /// ^/running\.[^/]+/lock$ ///
        do updateRunningCount
        batchSockets.volatile.emit "state-update", [
            batchId
            if event is "created" then "START" else "STOP"
            # TODO pass new state, #running, #done, #remaining, ...??
        ]

# Use Python watchdog to monitor filesystem changes
p = child_process.spawn "watchmedo", [
    'shell-command'
    '--recursive'
    '--patterns=*'
    '--command=echo ${watch_event_type} ${watch_src_path}'
    batchRootDir
]
splitter = p.stdout.pipe(StreamSplitter("\n"))
splitter.on "token", (line) ->
    [event, path] = String(line).split " ", 2
    batchNotifyChange event, path
