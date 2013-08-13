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
TARGET_COLUMN_NAME = "target#"
DETAILS_COLUMN_NAME = "details#"

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
    target.aborted outputs.failure
    exitstatus stderr stdout
    stdin args env
    rusage assembly
    target.name target/type
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


# Redirect to its canonical location when a run is requested via serial of a queue
app.get "/run/queue/:queueName/runs/:serial", (req, res, next) ->
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


isntNull = (x) -> x?

# convert lines of multiple key=value pairs (or named columns) to an array of
# arrays with a header array:
# "k1=v1 k2=v2\nk1=v3 k3=v4\n..." ->
#   { names:[k1,k2,k3,...], rows:[[v1,v2,null],[v3,null,v4],...] }
normalizeNamedColumnLines = (
        lineToKVPairs = (line) -> line.split /\s+/
      , columnNames = []
) -> (lazyLines, next) ->
    columnIndex = {}
    for name,i in columnNames
        columnIndex[name] = i
    lazyLines
        .filter(isntNull)
        .map(String)
        .map(lineToKVPairs)
        .filter(isntNull)
        .map((columns) ->
            row = []
            for column in columns
                if (m = /^([^=]+)=(.*)$/.exec column)?
                    [__, name, value] = m
                else if (m = /^([^=]+)!$/.exec column)?
                    name = m[1]
                    value = null
                else
                    continue
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
    withOut Lazy(p.stdout).lines.filter(isntNull).map(String), (result...) -> _result = result; do tryEnd
    withErr Lazy(p.stderr).lines.filter(isntNull).map(String), (error)     -> _error  = error ; do tryEnd
    p.on "exit",                                               (code)      -> _code   = code  ; do tryEnd
    p

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
cliSimpleEnv = (env, cmd, args...) ->
    cliBareEnv(env, cmd, args) (code, err, out) ->
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
    (getOutputs res) (respondJSON res)
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
    # TODO runs/queue/
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
    ) (respondJSON res)


formatStatusTable = (lines, firstColumnName = "isCurrent", indexColumnName = null) ->
    # format 3x-{queue,target}-like output
    names = lines.shift().map (s) ->
        if s is "#" then firstColumnName
        else s.toLowerCase().replace(/^#(.)/,
            (__, m) -> "num#{m.toUpperCase()}")
    lines.forEach (cols) ->
        cols[0] = (cols[0] is "*")
    rows = {}
    indexColumn = if indexColumnName? then names.indexOf indexColumnName else 1
    indexColumn = 1 unless indexColumn >= 0
    for line in lines
        row = rows[line[indexColumn]] = {}
        total = null
        for name,i in names
            row[name] = line[i]
            if /^num.+/.test name
                total ?= 0
                total += row[name] = +line[i]
        row.numTotal = total if total?
    rows

app.get "/api/run/queue/", (req, res) ->
    cli(res, "3x-queue", []
        , (lazyLines, next) ->
            lazyLines
                .map((line) -> line.split /\s+/)
                .join (rows) ->
                    next (formatStatusTable rows)
    ) (respondJSON res)

app.get "/api/run/target/", (req, res) ->
    cli(res, "3x-target", []
        , (lazyLines, next) ->
            lazyLines
                .map((line) -> line.split /\s+/)
                .join (rows) ->
                    next (formatStatusTable rows)
    ) (respondJSON res)

app.get "/api/run/target/:name", (req, res) ->
    name = req.param("name")
    cli(res, "3x-target", [name, "info"]
        , (lazyLines, next) ->
            lazyLines
                .bucket(null, (attr, line) ->
                    # group block of lines by "# NAME (DESC):" leader
                    if (m = line?.match /^# (\S+)( \((.*)\))?:\s*$/)?
                        @ (attr = { name: m[1], desc: m[3], value: [] })
                    else if attr? and line?
                        attr.value.push line
                    attr
                    )
                .join (attrs) ->
                    # format the attribute blocks into a nice JSON object
                    targetInfo = {name}
                    for attr in attrs
                        v = attr.value?.slice(0)
                        v.pop() until v[v.length - 1]?.length
                        v = v[0] if v?.length <= 1
                        targetInfo[attr.name] = v
                    targetInfo.target = name
                    next targetInfo
    ) (respondJSON res)


parseStatusOutput = (columnOrder) ->
    normalizeNamedColumnLines (line) ->
                    [state, columns...] = line.split /\s+/
                    switch state
                        when "PLANNED"
                            [columns..., serial] = columns
                            target = runId = null
                        else
                            [columns..., serial, target, runId] = columns
                    serial = (serial?.replace /^#/, "")
                    runId = "" if runId is "?"
                    if state
                        formatValue = (name, v) ->
                            "#{name}#{if v? then "=#{v}" else "!"}"
                        [
                            (formatValue  STATE_COLUMN_NAME, state)
                            (formatValue SERIAL_COLUMN_NAME, serial)
                            (formatValue TARGET_COLUMN_NAME, target)
                            (formatValue    RUN_COLUMN_NAME, runId)
                            # TODO order columns by 3x-condition
                            columns...
                        ]
                , columnOrder

app.get "/api/run/queue/*.DataTables", (req, res) ->
    [queueName] = req.params
    query = req.param("sSearch") ? null
    columnOrder =
        if (columns = req.param("sColumns")?.split /,/)?
            columnOrder = []
            for name,i in columns when j = req.param("mDataProp_#{i}")
                columnOrder[+j] = name
            columnOrder
    getHistory = (cmd, args, next) ->
        cliEnv res, {
                _3X_QUEUE: queueName
                LIMIT:  req.param("iDisplayLength") ? -1
                OFFSET: req.param("iDisplayStart") ? 0
            }, cmd, args, next
    async.parallel [
            getHistory "limitOffset", ["3x-status"]
                , parseStatusOutput columnOrder
        ,
            getHistory "sh", ["-c", "3x-status | wc -l"]
                , (lazyLines, next) ->
                    lazyLines
                        .take(1)
                        .join ([line]) -> next (+line?.trim())
        ], (err, [table, totalCount, filteredCount]) ->
            unless err
                # attach details for erroneous runs
                runIdColumn = table.names.indexOf RUN_COLUMN_NAME
                stateColumn = table.names.indexOf STATE_COLUMN_NAME
                detailsColumn = table.names.indexOf DETAILS_COLUMN_NAME
                if detailsColumn is -1
                    detailsColumn = table.names.length
                    table.names.push DETAILS_COLUMN_NAME
                erroneousRows =
                    for row,i in table.rows when row[stateColumn] is "ABORTED" # TODO in ["ABORTED, "FAILED"]
                        [i, row[runIdColumn], row[stateColumn]]
                async.parallel (
                    for [i, runId] in erroneousRows
                        (next) -> fs.readFile "#{_3X_ROOT}/#{runId}/target.aborted", next
                ), (err, details) ->
                    if err
                        util.log err
                        res.send 500, (err?.join "\n") ? err
                        return
                    for [i],j in erroneousRows
                        table.rows[i][detailsColumn] = String details[j]
                    res.json
                        sEcho: req.param("sEcho")
                        iTotalRecords: totalCount
                        iTotalDisplayRecords: totalCount # FIXME filteredCount
                        aColumnNames: table.names
                        aaData: table.rows

app.get /// /api/run/queue/([^:]+):(start|stop) ///, (req, res) ->
    [queueName, action] = req.params
    # TODO sanitize queueName
    cliEnv(res, {
        _3X_QUEUE: queueName
    }, "sh", ["-c", "SHLVL=0 3x-#{action} </dev/null >>.3x/gui/log.runs 2>&1 &"]
        , (lazyLines, next) ->
            lazyLines
                .join -> next (true)
    ) (respondJSON res)

app.post /// /api/run/queue/([^:]+):(duplicate|prioritize|postpone|cancel) ///, (req, res) ->
    [queueName, action] = req.params
    # TODO sanitize queueName
    if queueName?.length is 0
        return res.send 400, "Bad request\nNo queue specified"
    queueId = "run/queue/#{queueName}"
    try
        runs = JSON.parse req.body.runs
    catch err
        return res.send 400, "Bad request\nserial numbers of runs for the action must be POSTed in strict JSON format"

    {stdin} =
    cliEnv(res, {
        _3X_QUEUE: queueName
    }, "xargs", ["3x-plan", action]
    ) (respondJSON res)

    for serial in runs
        stdin.write "#{serial}\n"
    stdin.end()

app.get "/api/run/queue/*", (req, res) ->
    [queueName] = req.params
    # TODO sanitize queueName
    queueId = "run/queue/#{queueName}"
    fs.stat "#{_3X_ROOT}/#{queueId}", (err, stat) ->
        return res.send 404, "Not found: #{queueId}" if err?
        cliEnv(res, {
            _3X_QUEUE: queueName
        }, "3x-status", [queueId]
            , parseStatusOutput null
        ) (respondJSON res)

app.post /// /api/run/queue/([^:]+):(replace|add) ///, (req, res) ->
    [queueName, action] = req.params
    # TODO sanitize queueName
    try
        plan = JSON.parse req.body.runs
    catch err
        return res.send 400, "Bad request\nplan must be posted in strict JSON format"
    planCommand = switch action
        when "replace" then "with"
        else action

    # TODO write temporary file async
    generatePlanLines = ->
        columns = (name for name in plan.names when name.indexOf("#") is -1)
        (for line,idx in generateNamedColumnLines(plan, columns)
            "run#{line}"
        ).join "\n"

    mktemp.createFile "#{_3X_ROOT}/.3x/plan.XXXXXX", (err, planFile) ->
        andRespond = (err, [queueName]) ->
        fs.writeFile planFile, generatePlanLines(), ->
            cliEnv(res, {
                _3X_QUEUE: queueName
            }, "3x-plan", [planCommand, planFile]
            ) (err, [queueName]) ->
                # remove temporary file
                try cliSimple "rm", "-f", planFile
                unless err
                    res.json queueName


server.listen _3X_GUIPORT, ->
    #util.log "3X GUI started at http://localhost:#{_3X_GUIPORT}/"



###### incremental updates via WebSockets with Socket.IO

queueSockets =
io.of("/run/queue/")
    .on "connection", (socket) ->
        updateRunningCount socket

updateRunningCount = (socket = queueSockets) ->
    cliBare("sh", ["-c", "ls run/queue/*/.is-active.* | wc -l"]
        , (lazyLines, next) ->
            lazyLines
                .take(1)
                .join ([line]) -> next (+line?.trim())
    ) (code, err, count) ->
        socket.volatile.emit "running-count", count

queueRootDir = "#{_3X_ROOT}/run/queue/"
queueNotifyChange = (event, fullpath) ->
    # assuming first path component is the queue ID
    queueName = fullpath?.substring(queueRootDir.length).replace /// /.*$ ///, ""
    filename = fullpath?.substring((queueRootDir + queueName).length)
    return unless queueName?
    queueId = "run/queue/#{queueName}"
    util.log "WATCH #{queueId} #{event} #{filename}"
    if /// ^/( plan | running | done )$ ///.test filename
        queueSockets.volatile.emit "listing-update", [queueId, event]
    else if /// ^/( \.is-active\..* )$ ///.test filename
        do updateRunningCount
        queueSockets.volatile.emit "state-update", [
            queueId
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
        queueRootDir
    ]
    splitter = p.stdout.pipe(StreamSplitter("\n"))
    splitter.on "token", (line) ->
        [__, event, path] = /^(\S+) (.*)$/.exec(line) ? []
        queueNotifyChange event, path
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
