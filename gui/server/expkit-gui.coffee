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
    p = child_process.spawn cmd, args
    p.stdout.on "data", onOut
    p.on "exit", onEnd if onEnd?
    p.stderr.on "data", onErr if onErr?


app.get "/api/v1/conditions", (req, res) ->
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


app.listen expKitPort, ->
    #console.log "ExpKit GUI started at http://localhost:%d/", expKitPort

