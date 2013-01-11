###
# CoffeeScript for ExpKit GUI
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###

ExpKitServiceBaseURL = localStorage.ExpKitServiceBaseURL ? ""

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


updateScrollSpy = ->
    $('[data-spy="scroll"]').each(-> $(this).scrollspy('refresh'))

initNavBar = ->
    $("body > .navbar-fixed-top .nav a").click((e) ->
        [target] = $($(this).attr("href")).get()
        do target.scrollIntoView
        e.preventDefault()
    )


# TODO find a cleaner way to do this, i.e., leveraging jQuery
class CompositeElement
    constructor: (@baseElement) ->
        @on      = $.proxy @baseElement.on,      @baseElement
        @one     = $.proxy @baseElement.one,     @baseElement
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
                localStorage.resultsIncludeEmpty = JSON.stringify this.checked
                do t.display
            )
        @optionElements.toggleShowHiddenConditions
           ?.prop("checked", (try JSON.parse localStorage.resultsShowHiddenConditions) ? false)
            .change((e) ->
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
                $.get("#{ExpKitServiceBaseURL}/api/results",
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
        columnIndex = {}; idx = 0; columnIndex[name] = idx++ for name in @results.names
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

        # populate table head
        thead = @baseElement.find("thead")
        thead.find("tr").remove()
        columnMetadata = {}
        thead.append(ResultsTable.HEAD_SKELETON.render(
            columns: (
                idx = -1
                for name in @columnNames
                    idx++
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
                    idx = 0
                    for name in @columnNames
                        c = $.extend columnMetadata[name], row[idx++]
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
            bStateSave: true
            bDestroy: true
            bLengthChange: false
            bPaginate: false
            bAutoWidth: false
            # Use localStorage instead of cookies (See: http://datatables.net/blog/localStorage_for_state_saving)
            fnStateSave: (oSettings, oData) -> localStorage.resultsDataTablesState = JSON.stringify oData
            fnStateLoad: (oSettings       ) -> try JSON.parse localStorage.resultsDataTablesState
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
        idx = 0
        for name in @columnNames
            @dataTable.fnSetColumnVis (colOrder.indexOf idx++), (isVisible name), false
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




# initialize UI
$ ->
    # make things visible to the outside world
    window.ExpKit = exports =
        conditions: new ConditionsUI $("#conditions")
        measurements: new MeasurementsUI $("#measurements")
    # load conditions, measurements
    ExpKit.conditions.load().success -> ExpKit.measurements.load().success ->
        # and the results
        ExpKit.results = new ResultsTable $("#results-table"),
            ExpKit.conditions, ExpKit.measurements,
            toggleIncludeEmpty          : $("#results-include-empty")
            toggleShowHiddenConditions  : $("#results-show-hidden-conditions")
            buttonResetColumnOrder      : $("#results-reset-column-order")
            containerForStateDisplay    : $("#results")
        ExpKit.results.load()
    do initNavBar
    do initChartUI

