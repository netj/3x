###
# ExpKit Graphical User Interface
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###
express = require "express"

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


app.get "/results/stops.json", (req, res) ->
    res.sendfile __dirname + "/data/stops.json"



app.listen expKitPort, ->
    #console.log "ExpKit GUI started at http://localhost:%d/", expKitPort

