###
# CoffeeScript for 3X GUI
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###

$ = require "jquery"
_ = require "underscore"

{
    log
    error
} =
utils = require "utils"

CompositeElement = require "CompositeElement"

class _3X_
    @BASE_URL: localStorage._3X_ServiceBaseURL ? ""

    @RUN_COLUMN_NAME: "run#"
    @SERIAL_COLUMN_NAME: "serial#"
    @STATE_COLUMN_NAME: "state#"
    @TARGET_COLUMN_NAME: "target#"
    @DETAILS_COLUMN_NAME: "details#"

    @DESCRIPTOR: null
    @initTitle: ->
        simplifyURL = (url) ->
            url.replace /^[^:]+:\/\//, ""

        $.getJSON("#{_3X_.BASE_URL}/api/description")
            .success((descr) ->
                _3X_.DESCRIPTOR = descr
                hostport =
                    if descr.hostname? and descr.port? then "#{descr.hostname}:#{descr.port}"
                    else simplifyURL _3X_.BASE_URL
                document.title = "3X — #{descr.name} — #{hostport}"
                $("#title")
                    .text("#{descr.name} — #{hostport}")
                    .attr(
                        title: "#{
                            unless descr.description? then ""
                            else "#{descr.description}\n\n"
                        }#{descr.fileSystemPath
                            .split("/").joinTextsWithShy("/")}"
                        )
                    .tooltip(container: ".navbar")
            )


    @initTabs: ->
        # deactivate brand link since it may cause confusion
        $("#logo")
            .click((e) -> do e.preventDefault)
            .css(cursor: "default")
        # re-render some tables since it could be in bad shape while the tab wasn't active
        $(".navbar a[data-toggle='tab']").on "shown", (e) ->
            tab = $(e.target).attr("href").substring(1)
            # store as last tab
            localStorage.lastTab = tab
            #log "showing tab", tab
            do CompositeElement.displayDeferredInstances
        # restore last tab
        if localStorage.lastTab?
            $(".navbar a[href='##{localStorage.lastTab}']").click()

    @_: do ->
        $ ->
            do _3X_.initTitle
            do _3X_.initTabs
            log "_3X_ initialized"


# vim:undofile
