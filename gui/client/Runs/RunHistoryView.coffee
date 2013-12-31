define (require) -> (\

$ = require "jquery"
_ = require "underscore"
require "bootstrap"
require "jquery.ui.selectable"

_3X_ = require "cs!3x"
{
    log
    error
} =
utils = require "cs!utils"

CompositeElement = require "cs!CompositeElement"

class StatusTable extends CompositeElement
    constructor: (@baseElement, @conditions, @optionElements) ->
        super @baseElement
        @queueName = null
        @queueId = null
        @currentQueue = null

        @initialized = no
        @conditions.on "initialized", (e) =>
            @initialized = yes
            _.defer @display

        # intialize UI and hook events
        $(window).resize(_.throttle @maximizeDataTable, 100)
            .resize(_.debounce @display, 500)

        @optionElements.actions?.on("click", ".action", (e) =>
            $action = $(e.target).closest(".action")
            for c in $action.attr("class").split(/\s+/)
                if (m = /^action-(.+)$/.exec c)?
                    action = m[1]
                    @doStatusAction @selectedRuns, action
        )

        do @attachToResultsTable

    doStatusAction: (selectedRuns, action) =>
        runSerials = (serial for serial of selectedRuns when not StatusTable.CODE_BY_STATE[serial]?)
        $.post("#{_3X_.BASE_URL}/api/run/queue/#{@currentQueue.queue}:#{action}", {
            runs: JSON.stringify runSerials
        })
            .success((result) =>
                # scroll to the runs of interest and update selection
                switch action
                    when "prioritize"
                        row = (@currentQueue.numDone + @currentQueue.numFailed)
                        # @selectedRuns = {...} # TODO select the first runs
                    when "duplicate"
                        row = (@currentQueue.numTotal)
                        # @selectedRuns = {...} # TODO select newly added runs
                    when "postpone"
                        row = (@currentQueue.numTotal)
                        # @selectedRuns = {...} # TODO select the last runs
                        # XXX We may not need to do anything for @selectedRuns
                        # if every run were identified by serial.  However that
                        # is not the case until we migrate queue
                        # done/running/plan lists to SQLite tables.  It is
                        # tricky to know the exact serial without passing the
                        # queue's serial counter value (.count).
                    when "cancel"
                        row = null
                        @selectedRuns = {}
                @dataTableScroller?.fnScrollToRow row if row?
            )
            # TODO show feedback on failure

    load: (queueName, @currentQueue) =>
        if @dataTable? and @queueName is queueName
            log "status refreshing queue #{queueName}"
            @display true
        else
            log "status loading queue #{queueName}"
            @queueName = queueName
            @queueId = "run/queue/#{queueName}"
            do @display
        # initialize results table popover's target queue
        @resultsActionPopover?.find(".queue-name").text(@queueId)

    @STATES: """
        DONE
        FAILED
        RUNNING
        ABORTED
        PLANNED
    """.trim().split /\s+/
    @CODE_BY_STATE: utils.indexMap StatusTable.STATES
    @ICON_BY_STATE:
        DONE: "ok"
        FAILED: "remove"
        RUNNING: "cog icon-spin"
        ABORTED: "warning-sign"
        PLANNED: "time"
    @CLASS_BY_STATE:
        DONE: "text-success"
        FAILED: "text-error"
        RUNNING: "text-info"
        ABORTED: "text-warning"
        PLANNED: "muted"

    render: (quickUpdate = false) =>
        return unless @initialized

        # simply redraw DataTables and skip reconstructing it
        if quickUpdate
            do @dataTable?.fnDraw
            do @dataTable?.focus
            return

        # display the name of the queue
        @optionElements.nameDisplay?.text(@queueId)

        # prepare to distinguish metadata from input parameter columns
        columnNames = (name for name of @conditions.conditions)

        # fold any artifacts left by previous DataTables construction
        @dataTable
           ?.find(".state-detail").popover("destroy").end()
            .find("tbody").addClass("hide").end()
            .dataTable bDestroy:true

        ## define the table structure
        columnDefs = [
            { sTitle:      "#" , sName: _3X_.SERIAL_COLUMN_NAME , sClass:"muted serial" , mData: 1, aTargets:[0]                    , sWidth:  "60px" }
            { sTitle:  "State" , sName: _3X_.STATE_COLUMN_NAME  , sClass:"state"        , mData: 0, aTargets:[1]                    , sWidth: "100px" }
            { sTitle: "Target" , sName: _3X_.TARGET_COLUMN_NAME , sClass:"muted target" , mData: 2, aTargets:[3+columnNames.length] , bVisible: false }
            { sTitle: "Details", sName: _3X_.DETAILS_COLUMN_NAME, sClass:"muted details", mData: 4, aTargets:[4+columnNames.length] , bVisible: false }
            { sTitle:   "run#" , sName: _3X_.RUN_COLUMN_NAME    , sClass:"muted run"    , mData: 3, aTargets:[2]                    , bVisible: false }
        ]
        i = 0
        for name in columnNames
            # find the next vacant column index
            i++ while columnDefs.some (col) -> ~col.aTargets.indexOf(i)
            columnDefs.push { sTitle: name, sName: name, mData: columnDefs.length, aTargets: [i] }
        columnIndex = {}; columnIndex[col.sName] = col.mData for col,i in columnDefs

        @selectedRuns = (try JSON.parse localStorage["#{@queueId}SelectedRuns"]) ? {}

        # make it a DataTable
        @dataTable = $(@baseElement).dataTable
            sDom: '<"row-fluid"<"span6 muted"ir><"span6"f>>tS'
            bDestroy: true
            bServerSide: true
            sAjaxSource: "#{_3X_.BASE_URL}/api/#{@queueId}.DataTables"
            bProcessing: true
            sScrollY:  "#{window.innerHeight - @baseElement.offset().top}px"
            oScroller:
                loadingIndicator: true
                serverWait: 100
            bDeferRender: true
            bAutoWidth: true
            bFilter: false
            bSort: false
            # Use localStorage instead of cookies (See: http://datatables.net/blog/localStorage_for_state_saving)
            fnStateSave: (oSettings, oData) => localStorage["#{@queueId}DataTablesState"] = JSON.stringify oData
            fnStateLoad: (oSettings       ) => try JSON.parse localStorage["#{@queueId}DataTablesState"]
            bStateSave: true
            aoColumnDefs: columnDefs
            fnRowCallback: (nRow, aData, iDisplayIndex, iDisplayIndexFull) =>
                $row = $(nRow)
                # TODO why not simply use an object within aaData?
                serial = aData[columnIndex[_3X_.SERIAL_COLUMN_NAME]]
                state  = aData[columnIndex[_3X_.STATE_COLUMN_NAME]]
                runId  = aData[columnIndex[_3X_.RUN_COLUMN_NAME]]
                target = aData[columnIndex[_3X_.TARGET_COLUMN_NAME]]
                stateCode = StatusTable.CODE_BY_STATE[state]
                # restore selection
                if @selectedRuns[serial]?
                    $row.addClass("ui-selected")
                    # observe state change
                    if stateCode isnt @selectedRuns[serial]
                        oldState = StatusTable.STATES[@selectedRuns[serial]]
                        #log "state change #{serial} #{runId} #{oldState} -> #{state}", @selectedRuns
                        @selectedRuns[serial] = stateCode
                        @selectedRuns[oldState]--
                        @selectedRuns[state] ?= 0
                        @selectedRuns[state]++
                        do @persistSelectedRuns
                        do @updateAvailableActionsForSelection
                # avoid decorating a row multiple times
                return if $row.find("i.icon").length
                # tag serial for selection tracking
                $row.attr
                    "data-serial": serial
                    "data-state" : state, "data-statecode": stateCode
                    "data-runId" : runId
                    "data-target": target
                # icon and style class
                $state = $row.find(".state")
                    .prepend(" ")
                    .prepend($("<i>").addClass("icon icon-#{StatusTable.ICON_BY_STATE[state]}"))
                    .wrapInner($("<span>").addClass("#{StatusTable.CLASS_BY_STATE[state]}"))
                # popover with run# and other messages
                if runId?
                    $state
                        .wrapInner($("<a/>").attr(href: "#{_3X_.BASE_URL}/#{runId}/overview", target: "run-details"))
                        .addClass("state-detail")
                        .attr(
                            title: runId
                            "data-content": """
                                    <p><small><i class="icon icon-flag"></i> Target</small>
                                        <span class="label label-info">#{target}</span></p>
                                """ + switch state
                                when "ABORTED", "FAILED"
                                    details = aData[columnIndex[_3X_.DETAILS_COLUMN_NAME]]
                                    unless details then ""
                                    else """
                                        <p class="well well-small text-error"><small><tt>
                                            #{
                                                details.replace /\n/g, "<br>"
                                            }
                                        </tt></small></p>
                                    """
                                else ""
                            "data-html": "true"
                            "data-toggle": "popover"
                            "data-trigger": "hover"
                            "data-placement": "left"
                            "data-container": ".dataTables_wrapper"
                        ).popover("hide")
            fnInitComplete: =>
                @dataTable.find("tbody").removeClass("hide")
                do @maximizeDataTable
                dtScrollBG.removeClass("loading initializing")
                loadingIndicator.hide()

        # better loading progress indicator on scroll
        # + preventing popover from appearing when scrolling
        # See: http://stackoverflow.com/a/9144827/390044
        dtWrapper =
        @dataTable.closest(".dataTables_wrapper")
            .find(".dataTables_processing").html("""
                    &nbsp;<i class="icon icon-download-alt"></i>
                """).end()
        loadingIndicator = dtWrapper.find(".DTS_Loading").removeClass("DTS_Loading")
            .addClass("loading alert alert-block alert-info")
            .html("""
                    <h4>Loading...</h4>
                """)
            ### active, striped progress bar is sluggish
                    <br>
                    <div class="progress progress-striped active">
                        <div class="bar" style="width:100%;"></div>
                    </div>
                """)
            # as well as spinning icons
            #  <i class="icon icon-spinner icon-spin"></i>
            ###
        dtScrollBG =
        dtWrapper.find(".dataTables_scroll")
            .addClass("initializing loading")
            .find(".dataTables_scrollBody")
                .on("scroll", (_.debounce =>
                        @dataTable.find(".state-detail").popover("destroy")
                        dtScrollBG.addClass("loading")
                        loadingIndicator.show()
                    , 250, true))
                .on("scroll", (_.debounce =>
                        loadingIndicator.hide()
                        dtScrollBG.not(".initializing").removeClass("loading")
                        dtWrapper.find(".popover").remove()
                        @dataTable.find(".state-detail").popover("hide")
                    , 250))
            .end()

        # make rows selectable
        @dataTable.find("tbody").selectable(
                filter: "tr"
                cancel: "a, .cancel"
                appendTo: "##{dtWrapper.attr("id")}"
            )
            # reset selection unless metaKey is down
            .on("selectablestart", (e, ui) =>
                @selectedRuns = {} unless e.metaKey
            )
            # keep track of which runs are selected
            .on("selectableselected", (e, ui) =>
                runData = ui.selected.dataset
                unless @selectedRuns[runData.serial]?
                    @selectedRuns[runData.state] ?= 0
                    @selectedRuns[runData.state]++
                    @selectedRuns[runData.serial] = +runData.statecode
                    #log "selected", @queueId, runData.serial, e
                    do @updateAvailableActionsForSelection
            )
            .on("selectableunselected", (e, ui) =>
                runData = ui.unselected.dataset
                if @selectedRuns[runData.serial]?
                    state = StatusTable.STATES[@selectedRuns[runData.serial]]
                    delete @selectedRuns[runData.serial]
                    @selectedRuns[state]--
                    #log "unselected", @queueId, runData.serial, e
                    do @updateAvailableActionsForSelection
            )
            # persist each time it's done
            .on("selectablestop", (e, ui) =>
                do @persistSelectedRuns
            )
        # put focus on the table so it can be scrolled with keyboard as well
        @dataTable #.closest(".dataTables_scrollBody")
            .attr(tabindex: 0)
            .focus()
        do @updateAvailableActionsForSelection

        @dataTableScroller = @dataTable.fnSettings().oScroller

    persistSelectedRuns: =>
        localStorage["#{@queueId}SelectedRuns"] =
            JSON.stringify @selectedRuns

    updateAvailableActionsForSelection: =>
        return unless @optionElements.selectionSummary? or @optionElements.actions?
        $actionButtons = @optionElements.actions?.find("button").prop(disabled: true)
        summary = []
        totalCount = 0
        for state of StatusTable.CLASS_BY_STATE when @selectedRuns[state] > 0
            totalCount += count = @selectedRuns[state]
            $actionButtons.filter(".for-#{state}:disabled").prop(disabled: count == 0)
            summary.push "#{count} #{state}"
        @optionElements.selectionSummary?.html(
            if summary.length == 0 then ""
            else "With selected #{
                if totalCount <= 1 then "run"
                else "#{totalCount} runs"
            } <small>(#{summary.join ", "})</small>, "
        )

    maximizeDataTable: =>
        if @dataTableScroller?
            @dataTableScroller.dom.scroller.style.height =
                "#{window.innerHeight - $(@dataTableScroller.dom.scroller).offset().top}px"
            @dataTableScroller.fnMeasure()


    # TODO move the rest (plan popover) to PlannerUI
    attachToResultsTable: =>
        # add a popover to the attached results table
        if (rt = @optionElements.resultsTable)?
            popoverParent = rt.baseElement.parent()
            popover = @resultsActionPopover = $("""
                <div class="planner popover hide fade left">
                    <div class="arrow"></div>
                    <div class="popover-inner">
                        <h3 class="popover-title">Add to <span class="queue-name">Plan</span></h3>
                        <div class="popover-content">
                        <ul class="nav nav-list">
                            <li><a class="btn add add-all"><i class="icon icon-repeat"></i> <b class="num-all">0</b> Full Combinations</a></li>
                            <li><a class="btn add add-random"><i class="icon icon-random"></i> <b class="num-random">10</b> Random Runs</a>
                            <input class="random-percent" type="range" min="1" max="100" step="1">
                            </li>
                        </ul>
                        <div>From inputs <span class="conditions"></span></div>
                        </div>
                    </div>
                </div>
                """).appendTo(popoverParent)
            popover.find(".random-percent")
                .val(localStorage["#{@planTableId}_randomPercent"] ? 10)
                .change((e) =>
                    randomPercent = localStorage["#{@planTableId}_randomPercent"] =
                        popover.find(".random-percent").val()
                    numRandom = Math.max(1, Math.round(popover.numAllRuns * randomPercent/100))
                    popover
                        .find(".num-random").text(numRandom).end()
                        .find(".add-random").toggleClass("disabled", popover.numAllRuns == numRandom)
                )
            # update popover configuration
            updatePopoverContent = ($tr) =>
                # TODO check if we can skip this
                # prepare a values array for adding to plan later
                currentDataRow = rt.resultsForRendering[+$tr.attr("data-ordinal")]
                columns = rt.columns
                conditionNames = []
                popover.valuesArray =
                    for name,allValues of @conditions.conditions
                        conditionNames.push name
                        column = columns[name]
                        if currentDataRow? and column.isExpanded
                            [currentDataRow[column.index].value]
                        else
                            values = @conditions.menuItemsSelected[name]
                            if values?.length > 0 then values
                            else allValues?.values ? [] # XXX latter should not happen in any case
                popover.numAllRuns = _.foldr popover.valuesArray.map((vs) -> vs.length), (a,b) -> a*b
                popover
                    .find(".num-all").text(popover.numAllRuns).end()
                    .find(".random-percent").change().end()
                    .find(".conditions").find("*").remove().end().append(
                        for name,i in conditionNames
                            $("<span>").addClass("label label-info")
                                .toggleClass("expanded", columns[name].isExpanded is true)
                                .html("#{name}=#{popover.valuesArray[i].joinTextsWithShy(",")}")
                                .after(" ")
                    )
            # attach the popover to the results table
            attachPopover = ($tr) ->
                # TODO display only when there is an expanded condition column
                # try to avoid attaching to the same row more than once
                return if popover.currentTR?.index() == $tr.index()
                popover.currentTR = $tr
                popover.removeClass("hide in")
                _.defer ->
                    updatePopoverContent $tr
                    # attach to the current row
                    pos = $tr.position()
                    popover.addClass("in")
                        .css
                            top:  "#{pos.top  - (popover.height() - $tr.height())/2}px"
                            left: "#{pos.left -  popover.width()                   }px"
            popoverHideTimeout = null
            detachPopover = ->
                popover.currentTR = null
                popover.removeClass("in")
                popoverHideTimeout = clearTimeout popoverHideTimeout if popoverHideTimeout?
                popoverHideTimeout = setTimeout (-> popover.addClass("hide")), 100
                # XXX .remove() will break all attached event handlers, so send it away somewhere
            #  in a somewhat complicated way to make it appear/disappear after a delay
            # TODO this needs to be cleaned up with https://github.com/jakesgordon/javascript-state-machine
            POPOVER_SHOW_DELAY_INITIAL = 7000
            POPOVER_SHOW_HIDE_DELAY    =  100
            popoverAttachTimeout = null
            popoverDetachTimeout = null
            popoverResetDelayTimeout = null
            resetTimerAndDo = (next) ->
                popoverResetDelayTimeout = clearTimeout popoverResetDelayTimeout if popoverResetDelayTimeout?
                popoverHideTimeout = clearTimeout popoverHideTimeout if popoverHideTimeout?
                popoverDetachTimeout = clearTimeout popoverDetachTimeout if popoverDetachTimeout?
                # TODO is there any simple way to detect changes in row to fire attachPopover?
                popoverAttachTimeout = clearTimeout popoverAttachTimeout if popoverAttachTimeout?
                do next
            popoverParent
                .on("click", "tbody tr", (e) -> resetTimerAndDo =>
                    popover.showDelay = POPOVER_SHOW_HIDE_DELAY
                    attachPopover $(this).closest("tr")
                    )
                .on("mouseover", "tbody tr", (e) -> resetTimerAndDo =>
                    popoverAttachTimeout = setTimeout =>
                        popover.showDelay = POPOVER_SHOW_HIDE_DELAY
                        attachPopover $(this).closest("tr")
                        popoverAttachTimeout = null
                    , popover.showDelay ?= POPOVER_SHOW_DELAY_INITIAL
                    )
                .on("mouseover", ".planner.popover", (e) -> resetTimerAndDo =>
                    )
                .on("mouseout",  "tbody tr, .planner.popover", (e) -> resetTimerAndDo =>
                    popoverDetachTimeout = setTimeout ->
                        do detachPopover
                        popoverResetDelayTimeout = clearTimeout popoverResetDelayTimeout if popoverResetDelayTimeout?
                        popoverResetDelayTimeout = setTimeout ->
                            popover.showDelay = POPOVER_SHOW_DELAY_INITIAL
                            popoverResetDelayTimeout = null
                        , POPOVER_SHOW_DELAY_INITIAL / 3
                        popoverDetachTimeout = null
                    , POPOVER_SHOW_HIDE_DELAY
                    )
                .on("click", ".planner.popover .add.btn", @addPlanFromRowHandler())
        $('html').on('click.popover.data-api touchstart.popover.data-api', null, (e) =>
            if rt.baseElement.has(e.target).length == 0
                popover.showDelay = POPOVER_SHOW_DELAY_INITIAL
        )


    addPlanFromRowHandler: =>
        add = (strategy) =>
            popover = @resultsActionPopover
            # don't proceed if no condition is expanded
            if popover.numAllRuns == 0
                error "Cannot add anything to plan: no expanded inputs"
                return
            valuesArray = popover.valuesArray
            # check valuesArray to see if we are actually generating some plans
            for values,idx in valuesArray when not values? or values.length == 0
                name = (name for name of @conditions.conditions)[idx]
                error "Cannot add anything to plan: no values for inputs variable #{name}"
                return
            # add generated combinations to the current plan
            #log "adding #{strategy} plans for", valuesArray
            options =
                randomPercent: +popover.find(".random-percent").val()
            moreRuns = []
            # add to plans using the given strategy
            StatusTable.PLAN_ADDITION_STRATEGY[strategy](options) valuesArray, (comb) =>
                moreRuns.push comb
            @addPlan moreRuns
        (e) ->
            # find which btn was pressed
            for c in $(this).closest(".add").attr("class")?.split(/\s+/)
                if m = c.match /^add-(.+)$/
                    return add m[1]
    addPlan: (moreRuns) =>
        $.post("#{_3X_.BASE_URL}/api/#{@queueId}:add", {
            runs: JSON.stringify {
                names: (name for name of @conditions.conditions)
                rows: moreRuns
            }
        })
            # TODO show feedback on failure

    @PLAN_ADDITION_STRATEGY:

        all: (options) -> utils.forEachCombination

        random: ({randomPercent}) -> (valuesArray, addCombination) ->
            totalCount = 1; totalCount *= values.length for values in valuesArray
            numToChoose = Math.round (randomPercent/100 * totalCount)
            numRemaining = totalCount
            log numRemaining, numToChoose, addCombination
            utils.forEachCombination valuesArray, (comb) ->
                numRemaining--
                if numToChoose <= 0
                    false
                else if numRemaining < numToChoose or _.random(99) < randomPercent
                    # toss a coin if there are more remaining than needed
                    addCombination comb
                    numToChoose--

)
