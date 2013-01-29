###
# CoffeeScript for ExpKit GUI
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###

ExpKitServiceBaseURL = localStorage.ExpKitServiceBaseURL ? ""

log   = (args...) -> console.log   args...; args[0]
error = (args...) -> console.error args...; args[0]

Array::joinTextsWithShy = (delim) ->
    ($("<div/>").text(v).html() for v in @).join "&shy;#{delim}"

# JSRender "fields" tag for handy object presentation
# See: http://borismoore.github.com/jsrender/demos/scenarios/03_iterating-through-fields-scenario.html
`
$.views.tags({
	fields: function( object ) {
		var key,
			ret = "";
		for ( key in object ) {
			if ( object.hasOwnProperty( key )) {
				// For each property/field, render the content of the {{fields object}} tag, with "~key" as template parameter
				ret += this.renderContent( object[ key ], { key: key });
			}
		}
		return ret;
	}
});
`

safeId = (str) -> str.replace(/[^A-Za-z0-9_-]/g, "-")


RUN_COLUMN_NAME = "run#"
SERIAL_COLUMN_NAME = "serial#"
STATE_COLUMN_NAME  = "state#"


mapReduce = (map, red) -> (rows) ->
    mapped = {}
    for row in rows
        (mapped[map(row)] ?= []).push row
    reduced = {}
    for key,rowGroup of mapped
        reduced[key] = red(key, rowGroup)
    reduced

forEachCombination = (nestedList, f, acc = []) ->
    if nestedList?.length > 0
        [xs, rest...] = nestedList
        if xs?
            for x in xs
                forEachCombination rest, f, (acc.concat [x])
        else
            forEachCombination rest, f, acc
    else
        f acc
mapCombination = (nestedList, f) ->
    mapped = []
    forEachCombination nestedList, (combination) -> mapped.push (f combination)
    mapped

enumerate = (vs) -> vs.joinTextsWithShy ","



# different aggregation methods depending on data type or level of measurement
class Aggregation
    constructor: (@name, @type, @func) ->
        Aggregation.FOR_NAME[@name] = @

    @FOR_NAME: {}

    @FOR_TYPE: do ->
        withNumbersIn = (vs) -> v for v in vs.map parseFloat when not isNaN v
        new Aggregation "count",    "number", (vs) -> vs?.length
        new Aggregation "mode",     "string", (vs) ->
            hist = {}
            for v in vs
                hist[v] ?= 0
                hist[v] += 1
            maxc = _.max(hist)
            for v,c of hist when c == maxc
                return v
        new Aggregation "median",   "number", (vs) ->
            ordered = _.clone(vs).sort()
            ordered[Math.floor(vs.length / 2)]
        new Aggregation "min",      "number", (vs) -> ns = withNumbersIn vs; if ns.length then Math.min ns... else null
        new Aggregation "max",      "number", (vs) -> ns = withNumbersIn vs; if ns.length then Math.max ns... else null
        new Aggregation "mean",     "number", (vs) ->
            ns = withNumbersIn vs
            if ns.length > 0
                sum = 0
                count = 0
                for v in ns
                    sum += v
                    count++
                if count > 0 then (sum / count) else null
            else null
         new Aggregation "stdev",   "number", (vs) ->
            ns = withNumbersIn vs
            if ns.length > 0
                dsqsum = 0
                n = 0
                m = Aggregation.FOR_NAME.mean.func ns
                for v in ns
                    d = (v - m)
                    dsqsum += d*d
                    n++
                (Math.sqrt(dsqsum / n))
            else null
        aggs = (names...) -> _.pick Aggregation.FOR_NAME, names...
        nominal  : aggs "count"  , "mode"  , "enumerate"
        ordinal  : aggs "median" , "mode"  , "min"       , "max"  , "count" , "enumerate"
        interval : aggs "mean"   , "stdev" , "median"    , "mode" , "min"   , "max"       , "enumerate"
        ratio    : aggs "mean"   , "stdev" , "median"    , "mode" , "min"   , "max"       , "enumerate"

    @DATA_FORMATTER_FOR_TYPE: (type, rows, colIdx) ->
        switch type
            when "string", "nominal"
                _.identity
            when "number", "ordinal", "interval", "ratio"
                # go through all the values of rows at colIdx and determine precision
                sumIntegral   = 0; maxIntegral   = 0; minIntegral   = 0
                sumFractional = 0; maxFractional = 0; minFractional = 0
                count = 0
                for row in rows
                    v = "#{row[colIdx].value}."
                    f = v.length - 1 - v.indexOf(".")
                    #i = v.length - 1 - f
                    #minIntegral    = Math.min minIntegral, i
                    #maxIntegral    = Math.max maxIntegral, i
                    #sumIntegral   += i
                    #maxFractional  = Math.max maxFractional, f
                    #minFractional  = Math.min maxFractional, f
                    sumFractional += f
                    count++
                prec = Math.ceil(sumFractional / count)
                do (prec) ->
                    (v) ->
                        parseFloat(v).toFixed(prec) if v? and v != ""
            else
                _.identity


simplifyURL = (url) ->
    url.replace /^[^:]+:\/\//, ""

ExpDescriptor = null
initTitle = ->
    $.getJSON("#{ExpKitServiceBaseURL}/api/description")
        .success((exp) ->
            ExpDescriptor = exp
            hostport =
                if exp.hostname? and exp.port? then "#{exp.hostname}:#{exp.port}"
                else simplifyURL ExpKitServiceBaseURL
            document.title = "ExpKit — #{exp.name} — #{hostport}"
            $("#url").text("#{hostport}")
                .attr
                    title: "#{exp.fileSystemPath}#{
                        unless exp.description? then ""
                        else "\n#{exp.description}"
                    }"
        )


updateScrollSpy = ->
    $('[data-spy="scroll"]').each(-> $(this).scrollspy('refresh'))

initNavBar = ->
    $("body > .navbar-fixed-top .nav a").click((e) ->
        [target] = $($(this).attr("href")).get()
        do target.scrollIntoView
        e.preventDefault()
    )


initBaseURLControl = ->
    urlModalToggler = $("#url")
    urlModal = $("#url-switch")
    inputHost = urlModal.find(".url-input-host")
    inputPort = urlModal.find(".url-input-port")
    btnPrimary = urlModal.find(".btn-primary")

    urlModalToggler
        .text(simplifyURL ExpKitServiceBaseURL)
    urlModal.find("input").keyup (e) ->
        switch e.keyCode
            when 14, 13 # enter or return
                btnPrimary.click()
    urlModal.on "show", ->
        m = ExpKitServiceBaseURL.match ///
            ^http://
            ([^/]+)
            :
            (\d+)
            ///i
        inputHost.val(m?[1] ? ExpDescriptor.hostname)
        inputPort.val(m?[2] ? ExpDescriptor.port)
    urlModal.on "shown", -> inputPort.focus()
    urlModal.on "hidden", -> urlModalToggler.blur()
    btnPrimary.click (e) ->
        url = "http://#{inputHost.val()}:#{inputPort.val()}"
        if url isnt ExpKitServiceBaseURL
            $("#url").text(simplifyURL url)
            ExpKitServiceBaseURL = localStorage.ExpKitServiceBaseURL = url
            do location.reload # TODO find a nice way to avoid reload?
        urlModal.modal "hide"


# TODO find a cleaner way to do this, i.e., leveraging jQuery
class CompositeElement
    constructor: (@baseElement) ->
        @on      = $.proxy @baseElement.on     , @baseElement
        @off     = $.proxy @baseElement.off    , @baseElement
        @one     = $.proxy @baseElement.one    , @baseElement
        @trigger = $.proxy @baseElement.trigger, @baseElement



class ConditionsUI extends CompositeElement
    constructor: (@baseElement) ->
        super @baseElement
        @conditions = {}
        @lastConditionValues = (localStorage.conditionValues ?= "{}")
        @conditionValues = JSON.parse @lastConditionValues
        @lastConditionsHidden = (localStorage.conditionsHidden ?= "{}")
        @conditionsHidden = JSON.parse @lastConditionsHidden

    persist: =>
        # TODO isolate localStorage key
        localStorage.conditionValues = JSON.stringify @conditionValues
        localStorage.conditionsHidden = JSON.stringify @conditionsHidden

    load: =>
        $.getJSON("#{ExpKitServiceBaseURL}/api/conditions")
            .success(@initialize)

    @SKELETON: $("""
        <script id="condition-skeleton" type="text/x-jsrender">
          <li id="condition-{{>id}}" class="condition dropdown">
            <a class="dropdown-toggle" role="button" href="#"
              data-toggle="dropdown" data-target="#condition-{{>id}}"
              ><span class="caret"></span><i class="icon condition-hide-toggle"></i><span
                  class="condition-name">{{>name}}</span><span class="condition-values"></span>&nbsp;</a>
            <ul class="dropdown-menu" role="menu">
              {{for values}}
              <li><a href="#" class="condition-value">{{>#data}}</a></li>
              {{/for}}
              <li class="divider"></li>
              <li><a href="#" class="condition-values-toggle">All</a></li>
            </ul>
          </li>
        </script>
        """)

    initialize: (newConditions) =>
        @conditions = newConditions
        @condUI = {}
        @baseElement.find("*").remove()
        for name,{type,values} of @conditions
            id = safeId(name)
            # add each variable by filling the skeleton
            @baseElement.append(ConditionsUI.SKELETON.render({name, id, type, values}, {ExpKitServiceBaseURL}))
            condUI = @baseElement.find("#condition-#{id}")
            # with menu items for each value
            menu = condUI.find(".dropdown-menu")
            isAllActive = do (menu) -> () ->
                menu.find(".condition-value")
                    .toArray().every (a) -> $(a).hasClass("active")
            menu.find(".condition-value")
                .click(@menuItemActionHandler do (isAllActive) -> ($this, condUI) ->
                    $this.toggleClass("active")
                    condUI.find(".condition-values-toggle")
                        .toggleClass("active", isAllActive())
                )
                .each (i,menuitem) =>
                    $this = $(menuitem)
                    value = $this.text()
                    $this.toggleClass("active", value in (@conditionValues[name] ? []))
            menu.find(".condition-values-toggle")
                .toggleClass("active", isAllActive())
                .click(@menuItemActionHandler ($this, condUI) ->
                    $this.toggleClass("active")
                    condUI.find(".condition-value")
                        .toggleClass("active", $this.hasClass("active"))
                )
            condUI.toggleClass("active", not @conditionsHidden[name]?)
                .find(".condition-hide-toggle")
                    .click(do (condUI) => (e) =>
                        e.stopPropagation()
                        e.preventDefault()
                        condUI.toggleClass("active")
                        @updateDisplay condUI
                        do @persist
                        do @triggerIfChanged
                    )
            @updateDisplay condUI
            @condUI[name] = condUI
            log "initCondition #{name}:#{type}=#{values.join ","}"
        do updateScrollSpy

    @ICON_CLASS_VISIBLE: "icon-check"
    @ICON_CLASS_HIDDEN:  "icon-check-empty"
    updateDisplay: (condUI) =>
        name = condUI.find(".condition-name")?.text()
        values = condUI.find(".condition-value.active").map( -> $(this).text()).get()
        hasValues = values?.length > 0
        isHidden = not condUI.hasClass("active")
        @conditionValues[name] =
            if hasValues
                values
        @conditionsHidden[name] =
            if isHidden
                true
        condUI.find(".condition-values")
            ?.html(if hasValues then "=#{values.joinTextsWithShy ","}" else "")
        condUI.find(".condition-hide-toggle")
            .removeClass("#{ConditionsUI.ICON_CLASS_VISIBLE} #{ConditionsUI.ICON_CLASS_HIDDEN}")
            .toggleClass(ConditionsUI.ICON_CLASS_VISIBLE, not isHidden)
            .toggleClass(ConditionsUI.ICON_CLASS_HIDDEN ,     isHidden)

    menuItemActionHandler: (handle) =>
        c = @
        (e) ->
            e.stopPropagation()
            e.preventDefault()
            $this = $(this)
            condUI = $this.closest(".condition")
            ret = handle($this, condUI, e)
            c.updateDisplay condUI
            do c.persist
            do c.triggerChangedAfterMenuBlurs
            ret

    triggerIfChanged: =>
        thisConditionValues = JSON.stringify @conditionValues
        if @lastConditionValues != thisConditionValues
            @lastConditionValues = thisConditionValues
            _.defer => @trigger "filterChange"
        thisConditionsHidden = JSON.stringify @conditionsHidden
        if @lastConditionsHidden != thisConditionsHidden
            @lastConditionsHidden = thisConditionsHidden
            _.defer => @trigger "visibilityChange"

    triggerChangedAfterMenuBlurs: =>
        ($html = $("html"))
            .off(".conditions")
            .on("click.conditions touchstart.conditions", ":not(##{@baseElement.id} *)", (e) =>
                    _.delay =>
                        return if @baseElement.find(".dropdown.open").length > 0
                        $html.off(".conditions")
                        do @triggerIfChanged
                    , 100
                )


class MeasurementsUI extends CompositeElement
    constructor: (@baseElement) ->
        super @baseElement
        @measurements = {}
        @measurementsAggregation = try JSON.parse (localStorage.measurementsAggregation ?= "{}")

    persist: =>
        # TODO isolate localStorage key
        localStorage.measurementsAggregation = JSON.stringify @measurementsAggregation

    load: =>
        $.getJSON("#{ExpKitServiceBaseURL}/api/measurements")
            .success(@initialize)

    @SKELETON: $("""
        <script id="measurement-skeleton" type="text/x-jsrender">
          <li id="measurement-{{>id}}" class="measurement dropdown">
            <a class="dropdown-toggle" role="button" href="#"
              data-toggle="dropdown" data-target="#measurement-{{>id}}"
              ><span class="caret"></span><span class="measurement-name">{{>name}}</span><span
                class="measurement-aggregation"></span></a>
            <ul class="dropdown-menu" role="menu">
              {{fields aggregations}}
              <li><a href="#" class="measurement-aggregation">{{>~key}}</a></li>
              {{/fields}}
              <!--
              <li class="divider"></li>
              TODO precision slider
              <li><a href="#" class="measurement-aggregation-toggle">All</a></li>
              -->
            </ul>
          </li>
        </script>
        """)

    initialize: (newMeasurements) =>
        @measurements = newMeasurements
        @baseElement.find("*").remove()
        for name,{type} of @measurements
            id = safeId(name)
            aggregations = Aggregation.FOR_TYPE[type]
            # add each measurement by filling the skeleton
            @baseElement.append(MeasurementsUI.SKELETON.render({name, id, type, aggregations}, {ExpKitServiceBaseURL}))
            measUI = @baseElement.find("#measurement-#{id}")
            @run = measUI if name == RUN_COLUMN_NAME
            # with menu items for aggregation
            menu = measUI.find(".dropdown-menu")
            menu.find(".measurement-aggregation")
                .click(@menuActionHandler ($this, measUI) ->
                    # activate or toggle the newly chosen one
                    wasActive = $this.hasClass("active")
                    measUI.find(".dropdown-menu .measurement-aggregation").removeClass("active")
                    $this.toggleClass("active") unless wasActive
                    # Or we could always use at least one
                    # $this.addClass("active")
                )
                .each (i,menuitem) =>
                    $this = $(menuitem)
                    aggregation = $this.text()
                    $this.toggleClass("active", aggregation == @measurementsAggregation[name])
            @updateDisplay measUI
            log "initMeasurement #{name}:#{type}.#{@measurementsAggregation[name]}"
        do updateScrollSpy

    updateDisplay: (measUI) =>
        name = measUI.find(".measurement-name")?.text()
        aggregationActive = measUI.find(".measurement-aggregation.active")
        isActive = aggregationActive.length > 0
        aggregation = if isActive then aggregationActive.first().text()
        @measurementsAggregation[name] = aggregation
        measUI.find(".dropdown-toggle .measurement-aggregation").text(if isActive then ".#{aggregation}" else "")
        isActive = true if name == RUN_COLUMN_NAME
        measUI.toggleClass("active", isActive)

    menuActionHandler: (handle) ->
        m = @
        (e) ->
            e.stopPropagation()
            e.preventDefault()
            $this = $(this)
            measUI = $this.closest(".measurement")
            ret = handle($this, measUI, e)
            m.updateDisplay measUI
            do m.persist
            do m.triggerChangedAfterMenuBlurs
            ret

    triggerIfChanged: (job) =>
        thisMeasurementsAggregation = JSON.stringify @measurementsAggregation
        if @lastMeasurementsAggregation != thisMeasurementsAggregation
            @lastMeasurementsAggregation = thisMeasurementsAggregation
            _.defer => @trigger "aggregationChange"
            # special notification for changes to RUN_COLUMN_NAME
            last = try JSON.parse @lastMeasurementsAggregation
            runActiveHasChangedTo =
                if @measurementsAggregation[RUN_COLUMN_NAME] != last?[RUN_COLUMN_NAME]
                    @measurementsAggregation[RUN_COLUMN_NAME]?.length > 0
            _.defer => @run.trigger "changed", runActiveHasChangedTo if runActiveHasChangedTo?

    triggerChangedAfterMenuBlurs: =>
        ($html = $("html"))
            .off(".measurements")
            .on("click.measurements touchstart.measurements", ":not(##{@baseElement.id} *)", (e) =>
                    _.delay =>
                        return if @baseElement.find(".dropdown.open").length > 0
                        $html.off(".measurements")
                        do @triggerIfChanged
                    , 100
                )





class ResultsTable extends CompositeElement
    @EMPTY_RESULTS:
        names: []
        rows: []

    constructor: (@baseElement, @conditions, @measurements, @optionElements = {}) ->
        super @baseElement
        # TODO isolate localStorage key
        @columnsToExpand = (try JSON.parse localStorage.resultsColumnsToExpand) ? {}
        @columnNames = null
        @columnNamesGrouping = null
        @columnNamesMeasured = null
        @columnAggregation = null
        @dataTable = null
        @results = ResultsTable.EMPTY_RESULTS
        @resultsForRendering = null
        t = @
        $('html').on('click.popover.data-api touchstart.popover.data-api', null, (e) =>
                @baseElement.find(".aggregated").popover("hide")
            )
        @optionElements.toggleIncludeEmpty
           ?.prop("checked", (try JSON.parse localStorage.resultsIncludeEmpty) ? false)
            .change((e) ->
                # TODO isolate localStorage key
                localStorage.resultsIncludeEmpty = JSON.stringify this.checked
                do t.display
            )
        @optionElements.toggleShowHiddenConditions
           ?.prop("checked", (try JSON.parse localStorage.resultsShowHiddenConditions) ? false)
            .change((e) ->
                # TODO isolate localStorage key
                localStorage.resultsShowHiddenConditions = JSON.stringify this.checked
                do t.display
            )
        @optionElements.buttonResetColumnOrder
           ?.toggleClass("disabled", @isColumnReordered())
            .click((e) ->
                do t.dataTable?._oPluginColReorder?.fnReset
                $(this).addClass("disabled")
                e.preventDefault()
            )
        do @display # initializing results table with empty data first
        @conditions.on("filterChange", @load)
                   .on("visibilityChange", @display)
        @measurements.on "aggregationChange", @display

    load: =>
        displayNewResults = (newResults) =>
            log "got results:", newResults
            @results = newResults
            do @display
        (
            if _.values(@conditions.conditionValues).some((vs) -> vs?.length > 0)
                @optionElements.containerForStateDisplay?.addClass("loading")
                $.getJSON("#{ExpKitServiceBaseURL}/api/results",
                    runs: []
                    batches: []
                    conditions: JSON.stringify @conditions.conditionValues
                ).success(displayNewResults)
            else
                $.when displayNewResults(ResultsTable.EMPTY_RESULTS)
        ).done(=> @optionElements.containerForStateDisplay?.removeClass("loading"))

    @HEAD_SKELETON: $("""
        <script id="results-table-head-skeleton" type="text/x-jsrender">
          <tr>
            {{for columns}}
            <th class="{{>className}}"><span>{{>name}}</span
                >{{if isRunIdColumn || !~isRunIdExpanded && !isMeasured }}<i class="aggregation-toggler
                icon icon-folder-{{if isForGrouping}}open{{else}}close{{/if}}-alt"
                title="{{if isForGrouping}}Aggregate and fold the values of {{>name}}{{else
                }}Expand the aggregated values of {{>name}}{{/if}}"
                ></i>{{/if}}</th>
            {{/for}}
          </tr>
        </script>
        """)
    @ROW_SKELETON: $("""
        <script id="results-table-row-skeleton" type="text/x-jsrender">
          <tr class="result">
            {{for columns}}
            <td class="{{>className}} {{>type}}-type" data-value="{{:value}}">
              {{if aggregation}}
              <div class="aggregated {{>aggregation}}"
                {{if values}}
                data-placement="bottom" data-trigger="click"
                title="{{>aggregation}}{{if aggregation != 'enumerate'}} = {{:value}}{{/if}}"
                data-html="true" data-content='<ul>
                  {{for values}}
                  <li>{{for #data tmpl=~CELL_SKELETON ~column=#parent.parent.data ~value=#data/}}</li>
                  {{/for}}
                </ul>'
                {{/if}}
                >{{:formattedValue}}</div>
              {{else}}
              {{for #data tmpl=~CELL_SKELETON ~column=#data ~value=value/}}
              {{/if}}
            </td>
            {{/for}}
          </tr>
        </script>
        """)
    @CELL_SKELETON: """
        {{if ~column.isRunIdColumn}}<a href="{{>~ExpKitServiceBaseURL}}/{{>~value}}">{{>~value}}</a>{{else}}{{>~value}}{{/if}}
        """

    _enumerateAll: (name) =>
        if ({values} = @conditions.conditions[name])?
            (vs) -> (v for v in values when v in vs).joinTextsWithShy ","
        else
            enumerate

    display: =>
        @optionElements.containerForStateDisplay?.addClass("displaying")
        deferred = $.Deferred()
            .done(=> @optionElements.containerForStateDisplay?.removeClass("displaying"))
        _.delay (=> do @_display; deferred.resolve()), 10
        deferred
    _display: =>
        columnIndex = {}; columnIndex[name] = idx for name,idx in @results.names
        @columnNamesGrouping =
            if @optionElements.toggleShowHiddenConditions?.is(":checked")
                (name for name,value of @columnsToExpand when value)
            else
                (name for name,value of @columnsToExpand when value and not @conditions.conditionsHidden[name]?)
        @columnNamesMeasured = (name for name of @measurements.measurements when @measurements.measurementsAggregation[name]?)
        @columnNames = (name for name of @conditions.conditions).concat @columnNamesMeasured
        @columnAggregation = {}

        isRunIdExpanded = RUN_COLUMN_NAME in @columnNamesGrouping

        if isRunIdExpanded
            # present results without aggregation
            @optionElements.toggleIncludeEmpty?.prop("disabled", true)
            log "no aggregation"
            @resultsForRendering =
                for row in @results.rows
                    for name in @columnNames
                        value: row[columnIndex[name]]
        else
            # aggregate data
            @optionElements.toggleIncludeEmpty?.prop("disabled", false)
            for name in @columnNamesMeasured
                aggs = Aggregation.FOR_TYPE[@measurements.measurements[name].type] ? _.values(Aggregation.FOR_TYPE)[0]
                aggName = @measurements.measurementsAggregation[name]
                aggName = _.keys(aggs)[0] unless aggs[aggName]
                @columnAggregation[name] = aggs[aggName]
            for name of @conditions.conditions
                @columnAggregation[name] ?= {name:"enumerate", type:"string", func:@_enumerateAll name}
            log "aggregation:", JSON.stringify @columnAggregation
            groupRowsByColumns = (rows) =>
                map = (row) => JSON.stringify (@columnNamesGrouping.map (name) -> row[columnIndex[name]])
                red = (key, groupedRows) =>
                    for name in @columnNames
                        idx = columnIndex[name]
                        if name in @columnNamesGrouping
                            value: groupedRows[0][idx]
                        else
                            values = _.uniq (row[idx] for row in groupedRows)
                            value: @columnAggregation[name].func(values)
                            values: values
                grouped = mapReduce(map, red)(rows)
                [_.values(grouped), _.keys(grouped)]
            [aggregatedRows, aggregatedGroups] = groupRowsByColumns(@results.rows)
            #log "aggregated results:", aggregatedRows
            #log "aggregated groups:", aggregatedGroups

            # pad aggregatedRows with missing combination of condition values
            emptyRows = []
            if @optionElements.toggleIncludeEmpty?.is(":checked")
                emptyValues = []
                columnValuesForGrouping =
                    for name in @columnNamesGrouping
                        @conditions.conditionValues[name] ? @conditions.conditions[name].values
                forEachCombination columnValuesForGrouping, (group) =>
                    key = JSON.stringify group
                    unless key in aggregatedGroups
                        #log "padding empty row for #{key}"
                        emptyRows.push @columnNames.map (name) =>
                            if name in @columnNamesGrouping
                                value: group[@columnNamesGrouping.indexOf(name)]
                            else
                                value: @columnAggregation[name].func(emptyValues) ? ""
                                values: emptyValues
                #log "padded empty groups:", emptyRows
            @resultsForRendering = aggregatedRows.concat emptyRows

        log "rendering results:", @resultsForRendering

        # fold any artifacts made by previous DataTables
        @dataTable?.dataTable bDestroy:true

        # populate table head
        thead = @baseElement.find("thead")
        thead.find("tr").remove()
        columnMetadata = {}
        thead.append(ResultsTable.HEAD_SKELETON.render(
            columns: (
                for name,idx in @columnNames
                    isForGrouping = name in @columnNamesGrouping
                    # use aggregation type or the type of original data
                    type = (@columnAggregation[name]?.type unless isForGrouping) ?
                        @conditions.conditions[name]?.type ? @measurements.measurements[name]?.type
                    columnMetadata[name] =
                        name: name
                        type: type
                        className: "#{if name in @columnNamesMeasured        then "measurement" else "condition"
                                   }#{if @conditions.conditionsHidden[name]? then " muted"      else ""
                                   }#{if name in @columnNamesGrouping        then " expanded"   else ""
                                   }"
                        isForGrouping: isForGrouping
                        isMeasured: name in @columnNamesMeasured
                        isntImportant: @conditions.conditions[name]? and not isForGrouping
                        isRunIdColumn: name == RUN_COLUMN_NAME
                        aggregation: @columnAggregation[name]?.name unless isForGrouping
                        formatter: Aggregation.DATA_FORMATTER_FOR_TYPE?(type, @resultsForRendering, idx)
            )
            , {ExpKitServiceBaseURL, isRunIdExpanded}
            ))
        # allow the column header to toggle aggregation
        t = @
        thead.find(".aggregation-toggler").click((e) ->
            return if e.shiftKey # to reduce interference with DataTables' sorting
            $this = $(this)
            th = $this.closest("th")
            th.toggleClass("expanded")
            name = th.find("span").text()
            t.columnsToExpand[name] = if th.hasClass("expanded") then true else null
            localStorage.resultsColumnsToExpand = JSON.stringify t.columnsToExpand
            do t.display
            do e.stopPropagation
        )

        # populate table body
        @baseElement.find("tbody").remove()
        tbody = $("<tbody>").appendTo(@baseElement)
        for row in @resultsForRendering
            tbody.append(ResultsTable.ROW_SKELETON.render(
                columns: (
                    for name,idx in @columnNames
                        c = $.extend columnMetadata[name], row[idx]
                        c.formattedValue = c.formatter c.value
                        c
                )
                , {ExpKitServiceBaseURL, CELL_SKELETON:ResultsTable.CELL_SKELETON}
                ))
        tbody.find(".aggregated")
            .popover(trigger: "manual")
            .click((e) ->
                tbody.find(".aggregated").not(this).popover("hide")
                $(this).popover("show")
                e.stopPropagation()
                e.preventDefault()
            )

        # finally, make the table interactive with DataTable
        @dataTable = $(@baseElement).dataTable
            # XXX @baseElement must be enclosed by a $() before .dataTable(),
            # because otherwise @baseElement gets polluted by DataTables, and that
            # previous state will make it behave very weirdly.
            sDom: 'R<"H"fir>t<"F"lp>'
            bDestroy: true
            bLengthChange: false
            bPaginate: false
            bAutoWidth: false
            # Use localStorage instead of cookies (See: http://datatables.net/blog/localStorage_for_state_saving)
            # TODO isolate localStorage key
            fnStateSave: (oSettings, oData) -> localStorage.resultsDataTablesState = JSON.stringify oData
            fnStateLoad: (oSettings       ) -> try JSON.parse localStorage.resultsDataTablesState
            bStateSave: true
            oColReorder:
                fnReorderCallback: => @optionElements.buttonResetColumnOrder?.toggleClass("disabled", @isColumnReordered())
        do @updateColumnVisibility
        do updateScrollSpy

        # trigger event for others
        _.defer => @trigger("changed", @resultsForRendering)

    isColumnReordered: =>
        colOrder = @getColumnOrdering()
        (JSON.stringify colOrder) == (JSON.stringify (_.range colOrder?.length))
    getColumnOrdering: =>
        @dataTable?._oPluginColReorder?.fnGetCurrentOrder?() ?
        try (JSON.parse localStorage.resultsDataTablesState).ColReorder

    updateColumnVisibility: =>
        return unless @dataTable?
        # Hide some columns if necessary
        colOrder = @getColumnOrdering()
        return unless colOrder?.length == @columnNames.length
        isVisible =
            unless @optionElements.toggleShowHiddenConditions?.is(":checked")
            then (name) => (not @conditions.conditionsHidden[name]? or name in @columnNamesMeasured)
            else (name) => true
        for name,idx in @columnNames
            @dataTable.fnSetColumnVis (colOrder.indexOf idx), (isVisible name), false
        do @dataTable.fnDraw




displayChart = ->
    chartBody = d3.select("#chart-body")
    margin = {top: 20, right: 20, bottom: 50, left: 100}
    width = 960 - margin.left - margin.right
    height = 500 - margin.top - margin.bottom

    xAxisLabel = ExpKit.results.columnNamesGrouping[1]
    yAxisLabel = ExpKit.results.columnNamesMeasured[1]
    xIndex = ExpKit.results.columnNames.indexOf(xAxisLabel)
    yIndex = ExpKit.results.columnNames.indexOf(yAxisLabel)

    log "drawing chart for", xAxisLabel, yAxisLabel

    # collect column data from table
    data = []
    series = 0
    resultsTableRows = $("#results-table tbody tr")
    # TODO find(".aggregated")
    data[series++] = resultsTableRows.find("td:nth(#{xIndex})").toArray()
    data[series++] = resultsTableRows.find("td:nth(#{yIndex})").toArray()

    valueOf = (cell) -> +$(cell).attr("data-value")
    xData = (rowIdx) -> valueOf data[0][rowIdx]
    yData = (rowIdx) -> valueOf data[1][rowIdx]
    # TODO multi series to come
    dataForCharting = [0 .. data[0].length-1]


    log "data for charting", data, dataForCharting.map(xData)

    chartBody.select("svg").remove()
    svg = chartBody.append("svg")
        .attr("width",  width  + margin.left + margin.right )
        .attr("height", height + margin.top  + margin.bottom)
      .append("g")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

    x = d3.scale.ordinal()
        .rangeRoundBands([0, width], .1)
    # TODO see the type for x-axis, and decide
    #x = d3.scale.linear()
    #    .range([0, width])
    y = d3.scale.linear()
        .range([height, 0])
    xAxis = d3.svg.axis()
        .scale(x)
        .orient("bottom")
    yAxis = d3.svg.axis()
        .scale(y)
        .orient("left")

    console.log "ydomain", d3.extent(dataForCharting, yData)

    #x.domain(d3.extent(dataForCharting, xData))
    x.domain(dataForCharting.map(xData))
    extent = d3.extent(dataForCharting, yData)
    extent = d3.extent(extent.concat([0])) # TODO if ratio type only
    y.domain(extent)

    svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0,#{height})")
        .call(xAxis)
      .append("text")
        .attr("y", -3)
        .attr("x", width)
        .attr("dy", "-.71em")
        .style("text-anchor", "end")
        .text(xAxisLabel)

    svg.append("g")
        .attr("class", "y axis")
        .call(yAxis)
      .append("text")
        .attr("transform", "rotate(-90)")
        .attr("y", 6)
        .attr("dy", ".71em")
        .style("text-anchor", "end")
        .text(yAxisLabel)

        
    svg.selectAll(".dot")
        .data(dataForCharting)
      .enter().append("circle")
        .attr("class", "dot")
        .attr("r", 3.5)
        .attr("cx",    (d) -> x(xData(d)))
        .attr("cy",    (d) -> y(yData(d)))
        .style("fill", "red")

    line = d3.svg.line()
        .x((d) -> x(xData(d)))
        .y((d) -> y(yData(d)))
    svg.append("path")
        .datum(dataForCharting)
        .attr("class", "line")
        .attr("d", line)

initChartUI = ->
    # TODO listen to table changes?
    $("#chart .btn-primary").click((e) ->
        e.preventDefault()
        e.stopPropagation()
        do displayChart
    )
    $("#results-table").bind("changed", (e) ->
        do displayChart
    )




class BatchesTable extends CompositeElement
    constructor: (@baseElement, @countDisplay, @status) ->
        super @baseElement

        # subscribe to batch notifications
        @socket = io.connect("#{ExpKitServiceBaseURL}/run/batch/")
            .on "listing-update", ([batchId, createOrDelete]) =>
                # TODO any non intrusive way to give feedback?
                log "batch #{batchId} #{createOrDelete}"
                do @reload

            .on "state-update", ([batchId, newStatus]) =>
                log batchId, newStatus
                # TODO update only when the batch is visible on current page
                # TODO rate limit?
                do @reload

                # TODO when the batch is opened in status table, and unless it's dirty, update it
                @openBatchStatus batchId

            .on "running-count", (count) =>
                # update how many batches are running
                @countDisplay
                    ?.text(count)
                     .toggleClass("hide", count == 0)

        # TODO isolate localStorage key
        @currentBatchId = localStorage.lastBatchId

        openBatchStatusFor = ($row) =>
            batchId = $row.find("td:nth(0)").text()
            @openBatchStatus batchId, $row
        @baseElement.on "click", "tbody tr", (e) ->
            openBatchStatusFor $(this).closest("tr")

        do @display

        # load the current batch status
        if @currentBatchId?
            @status.load @currentBatchId
        else
            @dataTable.one "draw", ->
                tbody.find("tr:nth(0)").click()

    persist: =>
        # TODO isolate localStorage key
        localStorage.lastBatchId = @currentBatchId

    display: =>
        bt = @
        unless @dataTable?
            # clone original thead row
            @thead = @baseElement.find("thead")
            @origHeadRow = @thead.find("tr").clone()
            # remember the column names
            @headerNames = []
            @thead.find("th:gt(1)")
                .each (i,th) => @headerNames.push $(th).text().replace /^#/, ""
        else
            # fold any artifacts made by previous DataTables
            @dataTable?.dataTable bDestroy:true
            @thead.find("tr").remove()
            @thead.append(@origHeadRow)
            @baseElement.find("tbody").remove()
            @baseElement.append("<tbody>")
        # initialize server-side DataTables
        @dataTable = $(@baseElement).dataTable
            sDom: '<"H"fir>t<"F"lp>'
            bDestroy: true
            bAutoWidth: false
            bProcessing: true
            bServerSide: true
            sAjaxSource: "#{ExpKitServiceBaseURL}/api/run/batch.DataTables"
            bLengthChange: false
            iDisplayLength: 5
            bPaginate: true
            #bScrollInfinite: true
            bScrollCollapse: true
            #sScrollY: "#{Math.max(240, .2 * window.innerHeight)}px"
            bSort: false
            # Use localStorage instead of cookies (See: http://datatables.net/blog/localStorage_for_state_saving)
            # TODO isolate localStorage key
            fnStateSave: (oSettings, oData) -> localStorage.batchesDataTablesState = JSON.stringify oData
            fnStateLoad: (oSettings       ) -> try JSON.parse localStorage.batchesDataTablesState
            bStateSave: true
            # manipulate header columns
            fnHeaderCallback: (nHead, aData, iStart, iEnd, aiDisplay) ->
                $("th:gt(1)", nHead).remove()
                $(nHead).append("""
                    <th class="action">Action</th>
                    <th>#Total</th>
                    <th>#Done</th>
                    <th>#Running</th>
                    <th>#Remaining</th>
                    """)
            # manipulate rows before they are rendered
            fnRowCallback: (nRow, aData, iDisplayIndex, iDisplayIndexFull) =>
                $row = $(nRow)
                # indicate which batch's status is displayed
                $batchCell = $row.find("td:nth(0)")
                batchId = $batchCell.text()
                if localStorage.lastBatchId is batchId
                    @_displaySelected $row
                # collect the values and replace columns
                value = {}
                $row.find("td:gt(1)")
                    .each((i,td) => value[@headerNames[i]] = $(td).text())
                    .remove()
                totalRuns = (+value.done) + (+value.running) + (+value.remaining)
                percentage = (100 * (+value.done) / totalRuns).toFixed(0)
                $row.append("""
                    <td class="action"></td>
                    <td>#{totalRuns}</td>
                    <td>#{value.done}</td>
                    <td>#{value.running}</td>
                    <td>#{value.remaining}</td>
                    """)
                $batchCell.addClass("id")
                # progress bar
                $stateCell = $row.find("td:nth(1)")
                state = $stateCell.text()
                $row.addClass(state)
                PROGRESS_BY_STATE =
                    DONE: "progress-success"
                    RUNNING: "progress-striped active"
                    PAUSED: "progress-warning"
                    PLANNED: ""
                $stateCell.html("""<div
                    class="progress #{PROGRESS_BY_STATE[state]}">
                        <div class="bar" style="width: #{percentage}%"></div>
                    </div>""")
                # add action buttons
                ICON_BY_STATE =
                    DONE: null
                    RUNNING: "stop"
                    PAUSED: "play"
                    PLANNED: "play"
                ACTION_BY_STATE =
                    DONE: null
                    RUNNING: "stop"
                    PAUSED: "start"
                    PLANNED: "start"
                if (action = ACTION_BY_STATE[state])?
                    icon = ICON_BY_STATE[state]
                    $actionCell = $row.find("td:nth(2)")
                    $actionCell.html("""<a class="btn btn-small
                        #{action}"><i class="icon icon-#{icon}"></i></a>""")
                    $actionCell.find(".btn").click(@actionHandler action)

    _displaySelected: ($row) =>
        @baseElement.find("tbody tr").removeClass("info"); $row.addClass("info")

    openBatchStatus: (batchId, $row) =>
        @currentBatchId = batchId
        $row ?= @baseElement.find("tbody tr").filter(-> $(this).text() is batchId)
        @_displaySelected $row
        @status.load @currentBatchId
        do @persist

    reload: =>
        @dataTable.fnPageChange "first"

    actionHandler: (action) =>
        act = ($row) =>
            batchId = $row.find("td:nth(0)").text()
            log "#{action}ing #{batchId}"
            $.getJSON("#{ExpKitServiceBaseURL}/api/#{batchId}:#{action}")
                # TODO feedback on failure
        (e) ->
            act $(this).closest("tr")
            do e.preventDefault
            do e.stopPropagation




class PlanTableBase extends CompositeElement
    constructor: (@planTableId, @baseElement, @conditions, @optionElements) ->
        super @baseElement
        @plan = null
        do @initButtons
        $('html').on('click.popover.data-api touchstart.popover.data-api', null, (e) =>
                @popovers?.popover("hide")
            )

    @HEAD_SKELETON: $("""
        <script type="text/x-jsrender">
          <tr>
            <th class="fixed"></th>
            <th class="fixed">#</th>
            <th class="fixed">State</th>
            {{for columns}}
            <th>{{>name}}</th>
            {{/for}}
          </tr>
        </script>
        """)
    @ROW_SKELETON: $("""
        <script type="text/x-jsrender">
          <tr class="run {{>className}} {{>state}}" id="{{>~batchId}}-{{>serial}}">
            <td class="order">{{>ordinal}}</td>
            <td class="serial">{{>serial}}</td>
            <td class="state"><div class="detail"
            {{if run}}
            title="Detailed Info"
            data-placement="bottom" data-html="true" data-trigger="click"
            data-content='<a href="{{>~ExpKitServiceBaseURL}}/{{>run}}">{{>run}}</a>'
            {{/if}}><span class="hide">{{>ordinalGroup}}</span><i class="icon icon-{{>icon}}"></i></div></td>
            {{for columns}}
            <td>{{>value}}</td>
            {{/for}}
          </tr>
        </script>
        """)

    display: (@plan) =>
        # prepare to distinguish metadata from condition columns
        columnIndex = {}; columnIndex[name] = idx for name,idx in @plan.names
        columnNames = (name for name of @conditions.conditions)
        metaColumnNames = {} # at the least, there should be SERIAL_COLUMN_NAME and STATE_COLUMN_NAME
        for name,idx in @plan.names
            if (m = name.match /^(.*)#$/)?
                nm = switch name
                    when STATE_COLUMN_NAME
                        "state"
                    when SERIAL_COLUMN_NAME
                        "serial"
                    else
                        m[1]
                metaColumnNames[nm] = idx
            else if not name in columnNames
                columnNames.push name

        # fold any artifacts left by previous DataTables construction
        @dataTable?.dataTable bDestroy:true

        # populate table head
        thead = @baseElement.find("thead")
        thead.find("tr").remove()
        thead.append(StatusTable.HEAD_SKELETON.render(
                columns:
                    for name in columnNames
                        name: name
            ))
        # populate table body
        @baseElement.find("tbody").remove()
        tbody = $("<tbody>").appendTo(@baseElement)
        extraData =
            batchId: @planTableId
            ExpKitServiceBaseURL: ExpKitServiceBaseURL
        ICON_BY_STATE =
            DONE: "ok"
            RUNNING: "spin icon-spinner"
            REMAINING: "time"
        CLASS_BY_STATE =
            DONE: "success"
            RUNNING: "info"
            PAUSED: "warning"
            REMAINING: ""
        ordUB = @plan.rows.length
        for row,ord in @plan.rows
            metadata = {}
            for name,idx of metaColumnNames
                metadata[name] = row[idx]
            metadata.className = CLASS_BY_STATE[metadata.state]
            tbody.append(StatusTable.ROW_SKELETON.render(_.extend(metadata,
                    ordinal: ord
                    ordinalGroup: if metadata.state == "REMAINING" then ordUB else ord
                    icon: ICON_BY_STATE[metadata.state]
                    columns:
                        for name in columnNames
                            value: row[columnIndex[name]]
                ), extraData))
        tbody.find("tr").each (i,tr) -> tr.ordinal = i
        # popover detail (link to run)
        t = @
        @popovers = tbody.find(".state .detail")
            .popover(trigger: "manual")
            .click((e) ->
                t.popovers.not(this).popover("hide")
                $(this).popover("show")
                e.stopPropagation()
                e.preventDefault()
            )
        # make it a DataTable
        @dataTable = $(@baseElement).dataTable
            sDom: 'R<"H"fir>t<"F"lp>'
            bDestroy: true
            bAutoWidth: false
            bLengthChange: false
            bPaginate: false
            bScrollInfinite: true
            bScrollCollapse: true
            sScrollY: "#{Math.max(400, .618 * window.innerHeight)}px"
            aaSortingFixed: [[2, "asc"]]
            # Use localStorage instead of cookies (See: http://datatables.net/blog/localStorage_for_state_saving)
            fnStateSave: (oSettings, oData) => localStorage["#{@planTableId}DataTablesState"] = JSON.stringify oData
            fnStateLoad: (oSettings       ) => try JSON.parse localStorage["#{@planTableId}DataTablesState"]
            bStateSave: true
            # Workaround for DataTables resetting the scrollTop after sorting/reordering
            # TODO port this to the jquery.dataTables.rowReordering project
            fnPreDrawCallback: =>
                @scrollTop = @scrollBody?.scrollTop
            fnDrawCallback: =>
                @scrollBody?.scrollTop = @scrollTop
                _.defer =>
                    # detect and reflect reordering to the given data
                    $trs = tbody.find("tr")
                    return unless $trs.is (i) -> this.ordinal isnt i
                    # reorder internal plan according to the order of rows in the table
                    newRows = []; rows = @plan.rows
                    $trs.each (i,tr) =>
                        if tr.ordinal?
                            newRows[i] = rows[tr.ordinal]
                        tr.ordinal = i
                    # finally, save the plan with reordered rows
                    @plan.rows = newRows
                    @trigger "reordered"
        @scrollBody = @dataTable.closest(".dataTables_wrapper").find(".dataTables_scrollBody")[0]
        indexColumn = @dataTable._oPluginColReorder?.fnGetCurrentOrder().indexOf(0) ? 0
        @dataTable.fnSort [[indexColumn, "asc"]]
        # with reordering possible
        @dataTable.rowReordering
            iIndexColumn: indexColumn
        @dataTable.find("tbody").sortable
            items:  "tr.REMAINING"
            cancel: "tr:not(.REMAINING)"
        @dataTable.find("tbody tr").disableSelection()
        # update buttons
        do @updateButtons

    updateButtons: =>
        # turn on/off buttons
        @optionElements.buttonClear ?.toggleClass("disabled", not @canClear())
        @optionElements.buttonCommit?.toggleClass("disabled", not @canCommit())
    initButtons: =>
        (btn = @optionElements.buttonClear )?.click (e) => @handleClear (e) unless btn.hasClass("disabled")
        (btn = @optionElements.buttonCommit)?.click (e) => @handleCommit(e) unless btn.hasClass("disabled")
        do @updateButtons
    handleClear: (e) => error "handleClear not implemented for", @
    canClear: => false
    handleCommit: (e) => error "handleCommit not implemented for", @
    canCommit: => false


class StatusTable extends PlanTableBase
    constructor: (args...) ->
        super args...
        @plan = null
        @batchId = null
        @on "reordered", =>
            # TODO see if it's actually different from the original
            @isReordered = true
            do @updateButtons
        # TODO check if there's uncommitted changes beforeunload of document

    load: (@batchId) =>
        $.getJSON("#{ExpKitServiceBaseURL}/api/#{@batchId}")
            .success(@display)

    display: (args...) =>
        # display the name of the batch
        @optionElements.nameDisplay?.text(@batchId)
        # render table
        super args...
        log "showing batch status", @batchId, @plan
        @isReordered = false
        # scroll to the first REMAINING row
        if (firstREMAININGrow = @dataTable.find("tbody tr.REMAINING:nth(0)")[0])?
            @scrollBody?.scrollTop = firstREMAININGrow.offsetTop - firstREMAININGrow.offsetHeight * 3.5

    canClear: => @batchId? and @isReordered
    handleClear: (e) =>
        do @load @batchId
    canCommit: => @batchId? and @isReordered
    handleCommit: (e) =>
        # send plan to server to create a new batch
        $.post("#{ExpKitServiceBaseURL}/api/#{@batchId}",
            shouldStart: if @optionElements.toggleShouldStart?.is(":checked") then true
            plan: JSON.stringify @plan
        )
            .success(@load)
            .fail (err) =>
                error err # TODO better error presentation



class PlanTable extends PlanTableBase
    constructor: (args...) ->
        super args...
        # load plan and display it
        @plan = (try JSON.parse localStorage[@planTableId]) ? @newPlan()
        # intialize UI and hook events
        do @attachToResultsTable
        @on "reordered", @persist
        # finally, show the current plan in table, and display count
        @display @plan
        do @updateCountDisplay

    persist: =>
        log "saving plan for later", @plan
        do @updateCountDisplay
        # persist in localStorage
        localStorage[@planTableId] = JSON.stringify @plan

    display: (args...) =>
        super args...
        # scroll to the last row
        if (lastRow = @dataTable.find("tbody tr").last()[0])?
            @scrollBody?.scrollTop = lastRow.offsetTop

    newPlan: =>
        names: [SERIAL_COLUMN_NAME, STATE_COLUMN_NAME, (name for name of @conditions.conditions)...]
        rows: []
        lastSerial: 0

    updatePlan: (plan) =>
        @plan = plan
        do @persist
        _.defer =>
            @display @plan

    updateCountDisplay: =>
        count = @plan.rows.length
        @optionElements.countDisplay
            ?.text(count)
             .toggleClass("hide", count == 0)

    canClear: => @plan?.rows.length > 0
    handleClear: (e) =>
        @updatePlan @newPlan()
    canCommit: => @plan?.rows.length > 0
    handleCommit: (e) =>
        # send plan to server to create a new batch
        $.post("#{ExpKitServiceBaseURL}/api/run/batch/",
            shouldStart: if @optionElements.toggleShouldStart?.is(":checked") then true
            plan: JSON.stringify @plan
        )
            .success (batchId) =>
                @updatePlan @newPlan()
                # FIXME clean this dependency by listening to batch changes directly via socket.io
                ExpKit.batches.openBatchStatus batchId
                do ExpKit.batches.reload
            .fail (err) =>
                error err # TODO better error presentation

    attachToResultsTable: =>
        # add a popover to the attached results table
        if (rt = @optionElements.resultsTable)?
            popover = @resultsActionPopover = $("""
                <div class="planner popover fade left" style="display:block;">
                    <div class="arrow"></div>
                    <div class="popover-inner">
                        <div class="popover-content">
                        <a class="btn add"><i class="icon icon-plus"></i> Add runs to <i class="icon icon-time"></i> Plan</a>
                        </div>
                    </div>
                </div>
                """).appendTo(document.body)
            # attach the popover to the results table
            #  in a somewhat complicated way to make it appear/disappear after a delay
            popoverShowTimeout = null
            displayPopover = ($tr) ->
                # TODO display only when there is an expanded condition column
                # try to avoid attaching to the same row more than once
                return if popover.closest("tr")?.index() is $tr.index()
                popover.removeClass("in")
                _.defer ->
                    $tr.find("td:nth(0)").append(popover)
                    pos = $tr.position()
                    popover.addClass("in")
                        .css
                            top:  "#{pos.top  - (popover.height() - $tr.height())/2}px"
                            left: "#{pos.left -  popover.width()                   }px"
            popoverHideTimeout = null
            rt.baseElement.parent()
                .on("mouseover", "tbody tr", (e) ->
                    popoverHideTimeout = clearTimeout popoverHideTimeout if popoverHideTimeout?
                    popoverShowTimeout = clearTimeout popoverShowTimeout if popoverShowTimeout?
                    popoverShowTimeout = setTimeout (=> displayPopover $(this).closest("tr")), 100
                    )
                .on("mouseout", "tbody tr", (e) ->
                    popoverHideTimeout = setTimeout ->
                        popoverShowTimeout = clearTimeout popoverShowTimeout if popoverShowTimeout?
                        popover.removeClass("in")
                        setTimeout (-> popover.remove()), 100
                        popoverHideTimeout = null
                    , 100
                    )
                .on("click", "tbody tr .add.btn", @addPlanFromRowHandler())
    @STATE: "REMAINING"
    addPlanFromRowHandler: =>
        add = ($tr) =>
            # first, remove our popover to prevent its content being mixed to the values
            $tr.find(".planner.popover").remove()
            cells = $tr.find("td").get()
            # see which columns are the expanded conditions
            expandedConditions = {}
            $tr.closest("table").find("thead th.condition.expanded").each ->
                $th = $(this)
                expandedConditions[$th.text().trim()] = $th.index()
            log "found expanded conditions", JSON.stringify expandedConditions
            # don't proceed if no condition is expanded
            if _.size(expandedConditions) is 0
                error "Cannot add anything to plan: no expanded condition"
                return
            # TODO estimate size and confirm before adding to plan if too big
            # and prepare the list of values
            valuesMatrix =
                for name,allValues of @conditions.conditions
                    if (i = expandedConditions[name])?
                        [$(cells[i]).text().trim()]
                    else
                        values = @conditions.conditionValues[name]
                        if values?.length > 0 then values
                        else allValues?.values ? []
            # check valuesMatrix to see if we are actually generating some plans
            for values,idx in valuesMatrix when not values? or values.length is 0
                name = (name of @conditions.conditions)[idx]
                error "Cannot add anything to plan: no values for condition #{name}"
                return
            # add generated combinations to the current plan
            log "adding plans for", valuesMatrix
            rows = @plan.rows
            prevSerialLength = String(rows.length).length
            forEachCombination valuesMatrix, (comb) => rows.push [++@plan.lastSerial, PlanTable.STATE, comb...]
            # rewrite serial numbers if needed
            serialLength = String(rows.length).length
            if serialLength > prevSerialLength
                serialIdx = @plan.names.indexOf(SERIAL_COLUMN_NAME)
                zeros = ""; zeros += "0" for i in [1..serialLength]
                rewriteSerial = (serial) -> "#{zeros.substring(String(serial).length)}#{serial}"
                for row in rows
                    row[serialIdx] = rewriteSerial row[serialIdx]
            @updatePlan @plan
        (e) ->
            # find out from which row we're going to extract values
            add $(e.srcElement).closest("tr")



## notifications via Socket.IO
initSocketIO = ->
    socket = io.connect ExpKitServiceBaseURL
    # TODO move /api/description to here?
    socket.on "news", (data) ->
        log data
        socket.emit "my other event", my: "data"

# initialize UI
$ ->
    # make things visible to the outside world
    window.ExpKit = exports =
        conditions: new ConditionsUI $("#conditions")
        measurements: new MeasurementsUI $("#measurements")
    # load conditions, measurements
    ExpKit.conditions.load().success ->
        ExpKit.measurements.load().success ->
            # and the results
            ExpKit.results = new ResultsTable $("#results-table"),
                ExpKit.conditions, ExpKit.measurements,
                toggleIncludeEmpty          : $("#results-include-empty")
                toggleShowHiddenConditions  : $("#results-show-hidden-conditions")
                buttonResetColumnOrder      : $("#results-reset-column-order")
                containerForStateDisplay    : $("#results")
            ExpKit.results.load()
            # plan
            ExpKit.planner = new PlanTable "currentPlan", $("#plan-table"),
                ExpKit.conditions,
                resultsTable: ExpKit.results
                countDisplay: $("#plan-count.label")
                buttonCommit: $("#plan-submit")
                buttonClear : $("#plan-clear")
                toggleShouldStart: $("#plan-start-after-create")
        # runs
        ExpKit.status = new StatusTable "status", $("#status-table"),
            ExpKit.conditions,
            nameDisplay : $("#status-name")
            buttonCommit: $("#status-submit")
            buttonClear : $("#status-clear")
            toggleShouldStart: $("#status-start-after-create")
        ExpKit.batches = new BatchesTable $("#batches-table"), $("#run-count.label"), ExpKit.status
    do initTitle
    do initNavBar
    do initChartUI
    do initBaseURLControl
    do initSocketIO

