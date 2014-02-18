$ = require "jquery"
_ = require "underscore"
io = require "socket.io"
require "jquery.ui.sortable"

_3X_ = require "3x"
{
    log
    error
    humanReadableNumber
} =
utils = require "utils"

CompositeElement = require "CompositeElement"

class QueuesUI extends CompositeElement
    constructor: (@baseElement, @status, @target, @optionElements) ->
        super @baseElement

        # subscribe to queue change notifications
        @socket = io.connect("#{_3X_.BASE_URL}/run/queue/")
            .on "listing-update", ([queueId, createOrDelete]) =>
                log "queue #{queueId} #{createOrDelete}"
                # refresh status table when it's showing the updated queue
                if @queueOnFocus? and queueId is "run/queue/#{@queueOnFocus}"
                    @status.load @queueOnFocus, @queues?[@queueOnFocus]
                do @refresh

            .on "state-update", ([queueId, newStatus]) =>
                log "queue #{queueId} became #{newStatus}"
                do @refresh

            .on "target-update", ([queueId]) =>
                log "queue #{queueId} target changed"
                do @refresh

        # listen to events
        @baseElement
            .on("click", ".queue-start"  , @handleQueueAction   @startQueue)
            .on("click", ".queue-stop"   , @handleQueueAction    @stopQueue)
            .on("click", ".queue-reset"  , @handleQueueAction   @resetQueue)
            .on("click", ".queue-refresh", @handleQueueAction @refreshQueue)
            .on("click", ".queue"        , @handleQueueAction   @focusQueue)

        # TODO @optionElements.addNewQueue?. ...
        @showAbsoluteProgress = localStorage.queuesShowAbsoluteProgress is "true"
        @optionElements.toggleAbsoluteProgress
            ?.toggleClass("active", @showAbsoluteProgress)
            .click (e) =>
                localStorage.queuesShowAbsoluteProgress =
                @showAbsoluteProgress = not @optionElements.toggleAbsoluteProgress.hasClass("active")
                do @display

        @queueOnFocus = localStorage.queueOnFocus

        @queuesDisplayOrder = (try JSON.parse localStorage.queuesDisplayOrder) ? []
        changeQueuesDisplayOrder = (order) =>
            log "new queue display order", order
            @queuesDisplayOrder = order
            localStorage.queuesDisplayOrder = JSON.stringify order
        @optionElements.sortByName?.click (e) =>
            changeQueuesDisplayOrder _.keys(@queues).sort()
            do @display
        @optionElements.sortByTime?.click (e) =>
            changeQueuesDisplayOrder _.keys(@queues)
            do @display
        @baseElement
            .on("sortupdate", (e, ui) =>
                changeQueuesDisplayOrder @baseElement
                    .find(".queue .queue-name")
                    .map(-> $(@).text()).toArray()
            )
            # Workaround for tooltips' interference with sortable
            .on("sortstart", (e, ui) => ui.item.find(".progress, .bar").tooltip("destroy"))
            .on("sortstop",  (e, ui) => ui.item.find(".progress, .bar").tooltip("hide"))

        # finally load the queue list
        do @refresh

    refresh: =>
        # TODO loading feedback
        $.getJSON("#{_3X_.BASE_URL}/api/run/queue/")
            .success((@queues) =>
                unless @queueOnFocus?
                    for queueName of @queues
                        # focus on the first queue as default
                        @focusQueue queueName
                        break
                # TODO trigger "queue-refreshed" event to decouple @status and @target from QueuesUI and let them manage things on their own
                @status.currentQueue =
                @target.currentQueue =
                    @queues[@queueOnFocus]
                # update badges for total number of running and planned runs
                if @optionElements.remainingCountDisplay?
                    totalRemaining = 0
                    for name,queue of @queues
                        totalRemaining += +queue.numPlanned + queue.numAborted
                    @optionElements.remainingCountDisplay.text(totalRemaining)
                        .toggleClass("hide", totalRemaining == 0)
                if @optionElements.activeCountDisplay?
                    totalRunning = 0
                    for name,queue of @queues
                        totalRunning += +queue.numRunning
                    @optionElements.activeCountDisplay.text(totalRunning)
                        .toggleClass("hide", totalRunning == 0)
                do @display
                do @updateFocusedQueue # XXX to load StatusTable and setup ResultsTable popover when it hasn't been rendered yet
            )

    focusQueue: (queueName, e) =>
        if not e? or $(e?.target).closest("button").length == 0
            localStorage.queueOnFocus =
            @queueOnFocus = queueName
            do @updateFocusedQueue

    updateFocusedQueue: =>
        @status.load @queueOnFocus, @queues[@queueOnFocus]
        @target.load @queues[@queueOnFocus]
        @baseElement.find(".queue")
            .removeClass("active")
            .filter("[data-name='#{@queueOnFocus}']").addClass("active")

    @QUEUE_SKELETON: $("""
        <script type="text/x-jsrender">
            <li class="queue {{if state == "ACTIVE"}}active{{/if}} well alert-block" data-name="{{>queue}}">
                <h5 class="queue-label pull-left">
                    <i class="icon icon-cog icon-spin"></i>
                    <span class="queue-name">{{>queue}}</span>
                </h5>
                <small class="queue-summary pull-right muted"
                                                             data-toggle="tooltip" data-placement="top"    data-container=".queues"></small>
                <div class="clearfix"></div>
                <div class="progress for-PLANNED"            data-toggle="tooltip" data-placement="right"  data-container=".queues">
                    <div class="bar bar-success    for-DONE" data-toggle="tooltip" data-placement="bottom" data-container=".queues"></div>
                    <div class="bar bar-danger   for-FAILED" data-toggle="tooltip" data-placement="bottom" data-container=".queues"></div>
                    <div class="bar             for-RUNNING" data-toggle="tooltip" data-placement="top"    data-container=".queues"></div>
                    <div class="bar bar-warning for-ABORTED" data-toggle="tooltip" data-placement="top"    data-container=".queues"></div>
                <!--<div class="bar bar-muted   for-PLANNED" data-toggle="tooltip" data-placement="right"  data-container=".queues"></div>-->
                </div>
                <div class="actions">
                    <div class="pull-left">
                        <button class="queue-reset btn btn-small btn-danger"><i class="icon icon-undo"></i></button>
                    </div>
                    <button class="queue-refresh btn btn-small" disabled title="Refresh queue"><i class="icon icon-refresh"></i></button>
                    <button class="queue-stop btn btn-small btn-primary" title="Turn this queue off"><i class="icon icon-pause"></i></button>
                    <button class="queue-start btn btn-small btn-primary" title="Turn this queue on"><i class="icon icon-play"></i></button>
                </div>
            </li>
        </script>
        """)

    render: =>
        numQueues = _.size(@queues)
        @optionElements.sortByName?.toggleClass("hide", numQueues <= 3)
        @optionElements.sortByTime?.toggleClass("hide", numQueues <= 3)
        @optionElements.toggleAbsoluteProgress?.toggleClass("hide", numQueues < 2)
        queueNames = _.keys(@queues).sort()
        if @queuesDisplayOrder?.length > 0
            queueNames = @queuesDisplayOrder.concat(_.difference(queueNames, @queuesDisplayOrder))
        maxTotal = _.max _.pluck @queues, "numTotal"
        $queuesList = @baseElement.find("ul:first")
        unless $queuesList.length > 0
            @baseElement.addClass("queues")
            $queuesList = $("<ul>")
                .addClass("clearfix unstyled")
                .appendTo(@baseElement)
                .sortable
                    distance: 5
        progressGroups = ["Done", "Failed", "Aborted", "Running", "Planned"]
        MIN_VISIBLE_RATIO = 0.05
        for name,i in queueNames when @queues[name]?
            # compute queue data for display
            queue = @queues[name]
            isActive = queue.state is "ACTIVE"
            numRemaining = queue.numAborted + queue.numRunning + queue.numPlanned
            #  count the total number of runs in this queue
            numTotal = 0
            for g in progressGroups when queue["num#{g}"]?
                numTotal += queue["num#{g}"]
            #  compute ratio for progress bar display
            ratioTotal = 0
            for g in progressGroups
                ratioTotal += queue["ratio#{g}"] =
                    if numTotal == 0 or queue["num#{g}"] == 0 then 0
                    else Math.max MIN_VISIBLE_RATIO, (queue["num#{g}"] / numTotal)
            #  normalize to account the residuals created by MIN_VISIBLE_RATIO
            for g in progressGroups
                queue["ratio#{g}"] = queue["ratio#{g}"] / ratioTotal
            # update DOM
            $queue = $queuesList.find(".queue[data-name='#{name}']")
            unless $queue.length > 0
                $queue = $(QueuesUI.QUEUE_SKELETON.render queue, { BASE_URL: _3X_.BASE_URL })
                    .appendTo($queuesList)
            else if i isnt $queue.index()
                $queue.insertBefore($queuesList.find(".queue").eq(i))
            $queue
                .find(".queue-label")
                    .toggleClass("text-info", isActive)
                    .find(".icon").toggleClass("hide", not isActive).end()
                .end()
                .find(".queue-summary")
                    .text("#{humanReadableNumber numRemaining} / #{humanReadableNumber numTotal}")
                    .attr(title: "#{
                        if queue.numRunning == 0 then ""
                        else "#{humanReadableNumber queue.numRunning} running "
                    }#{
                        if queue.numAborted == 0 then ""
                        else "#{humanReadableNumber queue.numAborted} aborted "
                    }#{
                        "#{humanReadableNumber queue.numPlanned} planned "
                    }runs remain among #{humanReadableNumber numTotal} total runs#{
                        if queue.numFailed == 0 then ""
                        else ", #{humanReadableNumber queue.numFailed} of which failed"
                    }.")
                .end()
                .find(".progress")
                    .css(width: if @showAbsoluteProgress then "#{100 * (Math.max MIN_VISIBLE_RATIO, (queue.numTotal/maxTotal))}%" else "auto")
                    .find(".bar")
                    .filter(".for-DONE"   ).attr(title: "#{humanReadableNumber queue.numDone   } done"   ).css(width: "#{100 * queue.ratioDone   }%").end()
                    .filter(".for-FAILED" ).attr(title: "#{humanReadableNumber queue.numFailed } failed" ).css(width: "#{100 * queue.ratioFailed }%").end()
                    .filter(".for-ABORTED").attr(title: "#{humanReadableNumber queue.numAborted} aborted").css(width: "#{100 * queue.ratioAborted}%").end()
                    .filter(".for-RUNNING").attr(title: "#{humanReadableNumber queue.numRunning} running").css(width: "#{100 * queue.ratioRunning}%").end()
                    #.filter(".for-PLANNED").attr(title: "#{queue.numPlanned} planned").css(width: "#{100 * queue.ratioPlanned}%").end()
                    .end()
                    .attr(title: "#{humanReadableNumber queue.numPlanned} planned")
                .end()
                .find(".actions")
                    .find(".queue-start").toggleClass("hide",     isActive).end()
                    .find(".queue-stop" ).toggleClass("hide", not isActive).end()
                    .find(".queue-reset")
                        .toggleClass("hide", (queue.numRunning + queue.numAborted) == 0)
                        .attr(title:
                            if isActive then "Stop this queue and clean up"
                            else "Clean up runs that were executing"
                        )
                        .find(".icon")
                            .toggleClass("icon-stop",     isActive)
                            .toggleClass("icon-undo", not isActive)
                        .end()
                    .end()
                .end()
                .find(".progress, .bar, .queue-summary").tooltip("destroy").tooltip("hide").end()

        # indicate which queue is on focus
        do @updateFocusedQueue


    handleQueueAction: (action) -> (e) ->
        queueName = $(@).closest(".queue").find(".queue-name").text()
        action queueName, e

    startQueue:    (queueName) => @doQueueAction queueName, "start"
    stopQueue:     (queueName) => @doQueueAction queueName, "stop"
    resetQueue:    (queueName) => @doQueueAction queueName, "reset"
    refreshQueue:  (queueName) => @doQueueAction queueName, "refresh"
    doQueueAction: (queueName, action) =>
        $.getJSON("#{_3X_.BASE_URL}/api/run/queue/#{queueName}:#{action}")
            # TODO show feedback in case of failure
