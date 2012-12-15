###
# CoffeeScript for ExpKit GUI
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###

ExpKitServiceBaseURL = "http://iln29.stanford.edu:38917"

log = (args...) -> console.log args...; args[0]

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

# DataTables Numbers with HTML sorting
# See: http://datatables.net/plug-ins/sorting#numbers_html
# See: http://datatables.net/plug-ins/type-detection#numbers_html
`
jQuery.extend( jQuery.fn.dataTableExt.oSort, {
    "num-html-pre": function ( a ) {
        var x = a.replace( /<[\s\S]*?>/g, "" );
        return parseFloat( x );
    },
 
    "num-html-asc": function ( a, b ) {
        return ((a < b) ? -1 : ((a > b) ? 1 : 0));
    },
 
    "num-html-desc": function ( a, b ) {
        return ((a < b) ? 1 : ((a > b) ? -1 : 0));
    }
} );
jQuery.fn.dataTableExt.aTypes.unshift( function ( sData )
{
    sData = typeof sData.replace == 'function' ?
        sData.replace( /<[\s\S]*?>/g, "" ) : sData;
    sData = $.trim(sData);
      
    var sValidFirstChars = "0123456789-";
    var sValidChars = "0123456789.";
    var Char;
    var bDecimal = false;
      
    /* Check for a valid first char (no period and allow negatives) */
    Char = sData.charAt(0);
    if (sValidFirstChars.indexOf(Char) == -1)
    {
        return null;
    }
      
    /* Check all the other characters are valid */
    for ( var i=1 ; i<sData.length ; i++ )
    {
        Char = sData.charAt(i);
        if (sValidChars.indexOf(Char) == -1)
        {
            return null;
        }
          
        /* Only allowed one decimal place... */
        if ( Char == "." )
        {
            if ( bDecimal )
            {
                return null;
            }
            bDecimal = true;
        }
    }
      
    return 'num-html';
} );
`

safeId = (str) -> str.replace(/[#-]/g, "-")


RUN_COLUMN_NAME = "run#"
RUN_MEASUREMENT = null

# user interface building blocks
UI_CONDITIONS = null
UI_MEASUREMENTS = null


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
        for x in xs
            forEachCombination rest, f, (acc.concat [x])
    else
        f acc
mapCombination = (nestedList, f) ->
    mapped = []
    forEachCombination nestedList, (combination) -> mapped.push (f combination)
    mapped

enumerate = (vs) -> vs.joinTextsWithShy ","

enumerateAll = (name) ->
    if ({values} = UI_CONDITIONS.conditions[name])?
        (vs) -> (v for v in values when v in vs).joinTextsWithShy ","
    else
        enumerate

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


updateScrollSpy = ->
    $('[data-spy="scroll"]').each(-> $(this).scrollspy('refresh'))


class ConditionsUI
    constructor: (@baseElement) ->
        @conditions = {}
        @conditionsActive = JSON.parse (localStorage.conditionsActive ?= "{}")

    persist: =>
        localStorage.conditionsActive = JSON.stringify @conditionsActive

    load: =>
        $.getJSON("#{ExpKitServiceBaseURL}/api/conditions")
            .success(@initialize)

    @SKELETON: $("""
        <script id="condition-skeleton" type="text/x-jsrender">
          <li id="condition-{{>id}}" class="condition dropdown">
            <a class="dropdown-toggle" role="button" href="#"
              data-toggle="dropdown" data-target="#condition-{{>id}}"
              ><span class="caret"></span><span class="condition-name">{{>name}}</span><span
                class="condition-values"></span></a>
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
        @baseElement.find("*").remove()
        for name,{type,values} of @conditions
            id = safeId(name)
            # add each variable by filling the skeleton
            @baseElement.append(ConditionsUI.SKELETON.render({name, id, type, values}, {ExpKitServiceBaseURL}))
            condUI = @baseElement.find("#condition-#{id}")
                .toggleClass("numeric", values.every (v) -> not isNaN parseFloat v)
            # with menu items for each value
            menu = condUI.find(".dropdown-menu")
            isAllActive = do (menu) -> () ->
                menu.find(".condition-value")
                    .toArray().every (a) -> $(a).hasClass("active")
            menu.find(".condition-value")
                .click(@menuActionHandler do (isAllActive) -> ($this, condUI) ->
                    $this.toggleClass("active")
                    condUI.find(".condition-values-toggle")
                        .toggleClass("active", isAllActive())
                )
                .each (i,menuitem) =>
                    $this = $(menuitem)
                    value = $this.text()
                    $this.toggleClass("active", value in (@conditionsActive[name] ? []))
            menu.find(".condition-values-toggle")
                .toggleClass("active", isAllActive())
                .click(@menuActionHandler ($this, condUI) ->
                    $this.toggleClass("active")
                    condUI.find(".condition-value")
                        .toggleClass("active", $this.hasClass("active"))
                )
            @updateDisplay condUI
            log "initCondition #{name}:#{type}=#{values.join ","}"
        do updateScrollSpy

    updateDisplay: (condUI) =>
        name = condUI.find(".condition-name")?.text()
        values = condUI.find(".condition-value.active").map( -> $(this).text()).get()
        @conditionsActive[name] = values
        hasValues = values?.length > 0
        condUI.find(".condition-values")
            ?.html(if hasValues then "=#{values.joinTextsWithShy ","}" else "")
        wasActive = condUI.hasClass("active")
        condUI.toggleClass("active", hasValues)
        condUI.trigger("changed", hasValues) if wasActive != hasValues

    menuActionHandler: (handle) =>
        c = @
        (e) ->
            $this = $(this)
            condUI = $this.closest(".condition")
            ret = handle($this, condUI, e)
            c.updateDisplay condUI
            do c.persist
            e.stopPropagation()
            e.preventDefault()
            # TODO skip updateResults if another menu has been open
            $('html').one('click.dropdown.data-api touchstart.dropdown.data-api', e, updateResults)
            ret



class MeasurementsUI
    constructor: (@baseElement) ->
        @measurements = {}
        @measurementsAggregation = try JSON.parse (localStorage.measurementsAggregation ?= "{}")

    persist: =>
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
            RUN_MEASUREMENT = measUI if name == RUN_COLUMN_NAME
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
        wasActive = measUI.hasClass("active")
        isActive = true if name == RUN_COLUMN_NAME
        measUI.toggleClass("active", isActive)
        measUI.trigger("changed", isActive) if wasActive != isActive or name == RUN_COLUMN_NAME

    menuActionHandler: (handle) ->
        m = @
        (e) ->
            $this = $(this)
            measUI = $this.closest(".measurement")
            ret = handle($this, measUI, e)
            m.updateDisplay measUI
            do m.persist
            e.preventDefault()
            # TODO skip updateResults if another menu has been open
            $('html').one('click.dropdown.data-api touchstart.dropdown.data-api', e, displayResults)
            ret




columnNames = null
columnNamesGrouping = null
columnNamesMeasured = null
columnAggregation = null

dataTable = null

emptyResults =
    names: []
    rows: []
updateResults = (e) ->
    (
        if _.values(UI_CONDITIONS.conditionsActive).some((vs) -> vs?.length > 0)
            $("#results").addClass("loading")
            $.get("#{ExpKitServiceBaseURL}/api/results",
                runs: []
                batches: []
                conditions: JSON.stringify UI_CONDITIONS.conditionsActive
            ).success(displayNewResults)
        else
            $.when displayNewResults(emptyResults)
    ).done(-> $("#results").removeClass("loading"))
    e?.preventDefault?()

results = emptyResults
resultsForRendering = null
displayNewResults = (newResults) ->
    log "got results:", newResults
    results = newResults
    #$("#results-raw").text(JSON.stringify results, null, 2)
    do displayResults

displayResults = ->
    # prepare the column ordering
    columnIndex = {}; idx = 0; columnIndex[name] = idx++ for name in results.names
    columnNamesGrouping = (name for name of UI_CONDITIONS.conditions when UI_CONDITIONS.conditionsActive[name]?.length > 0)
    columnNamesMeasured = (name for name of UI_MEASUREMENTS.measurements when UI_MEASUREMENTS.measurementsAggregation[name]?)
    if RUN_COLUMN_NAME not in columnNamesMeasured
        columnNamesGrouping.push RUN_COLUMN_NAME
        columnNamesMeasured.unshift RUN_COLUMN_NAME
    columnNames = (name for name of UI_CONDITIONS.conditions).concat columnNamesMeasured
    columnAggregation = {}

    if RUN_COLUMN_NAME in columnNamesGrouping
        # present results without aggregation
        log "no aggregation"
        resultsForRendering =
            for row in results.rows
                for name in columnNames
                    value: row[columnIndex[name]]
    else
        # aggregate data
        for name in columnNamesMeasured
            aggs = Aggregation.FOR_TYPE[UI_MEASUREMENTS.measurements[name].type] ? _.values(Aggregation.FOR_TYPE)[0]
            aggName = UI_MEASUREMENTS.measurementsAggregation[name]
            aggName = _.keys(aggs)[0] unless aggs[aggName]
            columnAggregation[name] = aggs[aggName]
        for name of UI_CONDITIONS.conditions
            columnAggregation[name] ?= {name:"enumerate", type:"string", func:enumerateAll name}
        log "aggregation:", JSON.stringify columnAggregation
        groupRowsByColumns = (rows) ->
            map = (row) -> JSON.stringify (columnNamesGrouping.map (name) -> row[columnIndex[name]])
            red = (key, groupedRows) ->
                for name in columnNames
                    idx = columnIndex[name]
                    if name in columnNamesGrouping
                        value: groupedRows[0][idx]
                    else
                        values = _.uniq (row[idx] for row in groupedRows)
                        value: columnAggregation[name].func(values)
                        values: values
            grouped = mapReduce(map, red)(rows)
            [_.values(grouped), _.keys(grouped)]
        [aggregatedRows, aggregatedGroups] = groupRowsByColumns(results.rows)
        #log "aggregated results:", aggregatedRows
        #log "aggregated groups:", aggregatedGroups

        # pad aggregatedRows with missing combination of condition values
        emptyRows = []
        if $("#results-include-empty").is(":checked")
            emptyValues = []
            forEachCombination (UI_CONDITIONS.conditionsActive[name] for name in columnNamesGrouping), (group) ->
                key = JSON.stringify group
                unless key in aggregatedGroups
                    #log "padding empty row for #{key}"
                    emptyRows.push columnNames.map (name) ->
                        if name in columnNamesGrouping
                            value: group[columnNamesGrouping.indexOf(name)]
                        else
                            value: columnAggregation[name].func(emptyValues) ? ""
                            values: emptyValues
            #log "padded empty groups:", emptyRows
        resultsForRendering = aggregatedRows.concat emptyRows

    log "rendering results:", resultsForRendering

    table = $("#results-table")
    # populate table head
    headSkeleton = $("#results-table-head-skeleton")
    thead = table.find("thead")
    thead.find("tr").remove()
    columnMetadata = {}
    thead.append(headSkeleton.render(
        columns: (
            idx = -1
            for name in columnNames
                idx++
                isForGrouping = name in columnNamesGrouping
                # use aggregation type or the type of original data
                type = (columnAggregation[name]?.type unless isForGrouping) ?
                    UI_CONDITIONS.conditions[name]?.type ? UI_MEASUREMENTS.measurements[name]?.type
                columnMetadata[name] =
                    name: name
                    type: type
                    className:
                        if name in columnNamesMeasured then "measurement"
                        else if name in columnNamesGrouping then "condition"
                        else "muted"
                    isForGrouping: isForGrouping
                    isMeasured: name in columnNamesMeasured
                    isntImportant: UI_CONDITIONS.conditions[name]? and not isForGrouping
                    isRunIdColumn: name == RUN_COLUMN_NAME
                    aggregation: columnAggregation[name]?.name unless isForGrouping
                    formatter: Aggregation.DATA_FORMATTER_FOR_TYPE?(type, resultsForRendering, idx)
        )
    , {ExpKitServiceBaseURL}
    ))

    # populate table body
    table.find("tbody").remove()
    tbody = $("<tbody>").appendTo(table)
    rowSkeleton = $("#results-table-row-skeleton")
    for row in resultsForRendering
        tbody.append(rowSkeleton.render(
            columns: (
                idx = 0
                for name in columnNames
                    c = $.extend columnMetadata[name], row[idx++]
                    c.formattedValue = c.formatter c.value
                    c
            )
        , {ExpKitServiceBaseURL}
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
    dataTable = table.dataTable
        sDom: 'R<"H"fir>t<"F"lp>'
        bStateSave: true
        bDestroy: true
        bLengthChange: false
        bPaginate: false
        bAutoWidth: false
        # Use localStorage instead of cookies (See: http://datatables.net/blog/localStorage_for_state_saving)
        fnStateSave: (oSettings, oData) -> localStorage.resultsDataTablesState = JSON.stringify oData
        fnStateLoad: (oSettings       ) -> try JSON.parse localStorage.resultsDataTablesState
        oColReorder:
            fnReorderCallback: -> $("#results-reset-column-order").toggleClass("disabled", isColumnReordered())
    do updateColumnVisibility
    do updateScrollSpy

    # trigger event for others
    try
        table.trigger("changed", resultsForRendering)

isColumnReordered = ->
    colOrder = getColumnOrdering()
    (JSON.stringify colOrder) == (JSON.stringify (_.range colOrder?.length))
getColumnOrdering = ->
    dataTable?._oPluginColReorder?.fnGetCurrentOrder?() ?
    try (JSON.parse localStorage.resultsDataTablesState).ColReorder

updateColumnVisibility = ->
    return unless dataTable?
    # Hide some columns if necessary
    isVisible =
        if $("#results-hide-inactive-conditions").is(":checked")
        then (name) -> (name in columnNamesMeasured or name in columnNamesGrouping)
        else (name) -> true
    colOrder = getColumnOrdering()
    return unless colOrder?.length == columnNames.length
    idx = 0
    for name in columnNames
        dataTable.fnSetColumnVis (colOrder.indexOf idx++), (isVisible name), false
    do dataTable.fnDraw

initResultsUI = ->
    $('html').on 'click.popover.data-api touchstart.popover.data-api', null, (e) ->
        $("#results-table .aggregated").popover("hide")
    $("#results-include-empty")
        .prop("checked", (try JSON.parse localStorage.resultsIncludeEmpty) ? false)
        .change((e) ->
            localStorage.resultsIncludeEmpty = JSON.stringify this.checked
            do displayResults
        )
    $("#results-hide-inactive-conditions")
        .prop("checked", (try JSON.parse localStorage.resultsHideInactiveConditions) ? false)
        .change((e) ->
            localStorage.resultsHideInactiveConditions = JSON.stringify this.checked
            do updateColumnVisibility
        )
    $("#results-reset-column-order")
        .toggleClass("disabled", isColumnReordered())
        .click((e) ->
            do dataTable?._oPluginColReorder?.fnReset
            $(this).addClass("disabled")
            e.preventDefault()
        )
    runAggregations = RUN_MEASUREMENT.find(".dropdown-menu .measurement-aggregation")
    updateResultsWithoutAgg = ->
        $("#results-without-aggregation")
            .prop("checked", runAggregations.filter(".active").length == 0)
    updateResultsWithoutAgg()
        .change((e) ->
            if this.checked
                runAggregations.filter(".active").click()
            else
                runAggregations.first().click()
        )
    RUN_MEASUREMENT
        .bind("changed", (e, isActive) -> do updateResultsWithoutAgg)




initNavBar = ->
    $("body > .navbar-fixed-top .nav a").click((e) ->
        [target] = $($(this).attr("href")).get()
        do target.scrollIntoView
        e.preventDefault()
    )




displayChart = ->
    chartBody = d3.select("#chart-body")
    margin = {top: 20, right: 20, bottom: 50, left: 100}
    width = 960 - margin.left - margin.right
    height = 500 - margin.top - margin.bottom

    xAxisLabel = columnNamesGrouping[1]
    yAxisLabel = columnNamesMeasured[1]
    xIndex = columnNames.indexOf(xAxisLabel)
    yIndex = columnNames.indexOf(yAxisLabel)

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




# initialize UI
$ ->
    UI_CONDITIONS = new ConditionsUI $("#conditions")
    UI_MEASUREMENTS = new MeasurementsUI $("#measurements")
    UI_CONDITIONS.load().success ->
        UI_MEASUREMENTS.load().success ->
            do initResultsUI
            do displayResults # initializing results table with empty data first
            do updateResults
    do initNavBar
    do initChartUI

    # make things visible to the outside world
    window.UI = exports =
        conditions: UI_CONDITIONS
        measurements: UI_MEASUREMENTS

