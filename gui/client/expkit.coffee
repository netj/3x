###
# CoffeeScript for ExpKit GUI
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###

ExpKitServiceBaseURL = localStorage.ExpKitServiceBaseURL ? ""

log   = (args...) -> console.log   args...; args[0]
error = (args...) -> console.error args...; args[0]

# See: http://stackoverflow.com/questions/1470810/wrapping-long-text-in-css
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

window.choose =
choose = (n, items) ->
    indexes = [0...items.length]
    indexesChosen =
        for i in [1..n]
            indexes.splice _.random(0, indexes.length - 1), 1
    indexesChosen.map (i) -> items[i]


enumerate = (vs) -> vs.joinTextsWithShy ","


FILTER_EXPR_REGEX = ///
        ^ \s*
    ( <= | >= | <> | != | = | < | > )    # comparison, membership, ...
        \s*
    ( (|[+-]) ( \d+(\.\d*)? | \.\d+ )
              ([eE] (|[+-])\d+)?         # number
    | [^<>=!]?.*                         # or string
    )
        \s* $
///
parseFilterExpr1 = (expr) ->
    [m[1], m[2]] if m = FILTER_EXPR_REGEX.exec expr.trim()
parseFilterExpr = (compoundExpr) ->
    parsed = [] # XXX CoffeeScript 1.4.0 doesnt treat "for" as expr when there's a return in its body
    for expr in compoundExpr?.split "&"
        if (parsed1 = parseFilterExpr1 expr)?
            parsed.push parsed1
        else
            return null
    parsed
serializeFilter = (parsedFilter) ->
    if _.isArray parsedFilter
        ("#{rel}#{literal}" for [rel, literal] in parsedFilter
        ).join " & "
    else
        parsedFilter



# different aggregation methods depending on data type or level of measurement
class Aggregation
    constructor: (@name, @type, @func) ->
        Aggregation.FOR_NAME[@name] = @

    @FOR_NAME: {}

    @FOR_TYPE: do ->
        typesToAgg = {}
        add = (maps...) -> _.extend typesToAgg, maps...
        aggs = (names...) -> _.pick Aggregation.FOR_NAME, names...

        # aggregation for standard measurement types N/O/I/R
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
        add nominal  : aggs "count"  , "mode"  , "enumeration"
        add ordinal  : aggs "median" , "mode"  , "min"       , "max"  , "count" , "enumeration"
        add interval : aggs "mean"   , "stdev" , "median"    , "mode" , "min"   , "max"       , "enumeration"
        add ratio    : aggs "mean"   , "stdev" , "median"    , "mode" , "min"   , "max"       , "enumeration"

        # aggregation for images
        new Aggregation "overlay", "object", do ->
            MAX_IMAGES = 20 # TODO Chrome is sluggish at rendering many translucent images
            BASE_OPACITY = 0.05 # minimum opacity
            VAR_OPACITY  = 0.50 # ratio to plus/minus the dividend opacity
            (imgs, rows, colIdx, colIdxs, col) ->
                if imgs?.length > 0
                    runColIdx = colIdxs[RUN_COLUMN_NAME]
                    numOverlaid = Math.min(MAX_IMAGES, rows.length)
                    sampledRows =
                        if rows.length <= MAX_IMAGES then rows
                        # TODO can we do a better sampling?
                        else rows[i] for i in [0...rows.length] by Math.floor(rows.length / MAX_IMAGES)
                    divOpacity = (1 - BASE_OPACITY) / numOverlaid
                    (for row,i in sampledRows
                        """
                        <img class="overlay"
                        src="#{ExpKitServiceBaseURL}/#{row[runColIdx]}/workdir/#{row[colIdx]}"
                        style="opacity: #{BASE_OPACITY + divOpacity * (1.0 + VAR_OPACITY/2 * (numOverlaid/2 - i) / numOverlaid)};">
                        """
                    ).join ""
        add "image/png": aggs "overlay", "count"

        # TODO allow user to plug-in their custom aggregation functions

        typesToAgg

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


initTabs = ->
    # re-render some tables since it could be in bad shape while the tab wasn't active
    $(".navbar a[data-toggle='tab']").on "shown", (e) ->
        tab = $(e.target).attr("href").substring(1)
        log "showing tab", tab
        switch tab
            when "results"
                ExpKit.results?.dataTable?.fnDraw()
            when "plan"
                ExpKit.planner?.dataTable?.fnDraw()
            when "runs"
                ExpKit.status?.dataTable?.fnDraw()
        # store last tab
        localStorage.lastTab = tab
    # restore last tab
    if localStorage.lastTab?
        $(".navbar a[href='##{localStorage.lastTab}']").click()



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



class MenuDropdown extends CompositeElement
    constructor: (@baseElement, @menuName) ->
        super @baseElement

        @menuLabelItemsPrefix    = "="
        @menuLabelItemsDelimiter = ","
        @menuLabelItemsPostfix   = ""

        @_menuDropdownSkeleton = $("""
            <script type="text/x-jsrender">
              <li id="#{@menuName}-{{>id}}" class="#{@menuName} dropdown">
                <a class="dropdown-toggle" role="button" href="#"
                  data-toggle="dropdown" data-target="##{@menuName}-{{>id}}"
                  ><span class="caret"></span><i class="icon menu-checkbox"></i><span
                      class="menu-label">{{>name}}</span><span class="menu-label-items"></span>&nbsp;</a>
                <ul class="dropdown-menu" role="menu">
                  {{for items}}
                  <li><a href="#" class="menu-dropdown-item">{{>#data}}</a></li>
                  {{/for}}
                  <li class="divider"></li>
                  <li><a href="#" class="menu-dropdown-toggle-all">All</a></li>
                </ul>
              </li>
            </script>
            """)

        @lastMenuItemsSelected = (localStorage["menuDropdownSelectedItems_#{@menuName}"] ?= "{}")
        @menuItemsSelected = try JSON.parse @lastMenuItemsSelected
        @lastMenusInactive = (localStorage["menuDropdownInactiveMenus_#{@menuName}"] ?= "{}")
        @menusInactive = try JSON.parse @lastMenusInactive

    persist: =>
        localStorage["menuDropdownSelectedItems_#{@menuName}"] = JSON.stringify @menuItemsSelected
        localStorage["menuDropdownInactiveMenus_#{@menuName}"] = JSON.stringify @menusInactive

    clearMenu: =>
        @baseElement.find("*").remove()

    addMenu: (name, items) =>
        id = safeId(name)
        @baseElement.append(@_menuDropdownSkeleton.render({name, id, items}))
        menuAnchor = @baseElement.find("##{@menuName}-#{id}")
        menu = menuAnchor.find(".dropdown-menu")
        isAllItemActive = do (menu) -> () ->
            menu.find(".menu-dropdown-item")
                .toArray().every (a) -> $(a).hasClass("active")
        menu.find(".menu-dropdown-item")
            .click(@menuItemActionHandler do (isAllItemActive) -> ($this, menuAnchor) ->
                $this.toggleClass("active")
                menuAnchor.find(".menu-dropdown-toggle-all")
                    .toggleClass("active", isAllItemActive())
            )
            .each (i,menuitem) =>
                $this = $(menuitem)
                item = $this.text()
                $this.toggleClass("active", item in (@menuItemsSelected[name] ? []))
        menu.find(".menu-dropdown-toggle-all")
            .toggleClass("active", isAllItemActive())
            .click(@menuItemActionHandler ($this, menuAnchor) ->
                $this.toggleClass("active")
                menuAnchor.find(".menu-dropdown-item")
                    .toggleClass("active", $this.hasClass("active"))
            )
        menuAnchor.toggleClass("active", not @menusInactive[name]?)
            .find(".menu-checkbox")
                .click(do (menuAnchor) => (e) =>
                    e.stopPropagation()
                    e.preventDefault()
                    menuAnchor.toggleClass("active")
                    @updateDisplay menuAnchor
                    do @persist
                    do @triggerIfChanged
                )
        menuAnchor

    menuItemActionHandler: (handle) =>
        m = @
        (e) ->
            e.stopPropagation()
            e.preventDefault()
            $this = $(this)
            menuAnchor = $this.closest(".dropdown")
            try
                ret = handle($this, menuAnchor, e)
                m.updateDisplay menuAnchor
                do m.persist
                do m.triggerChangedAfterMenuBlurs
                ret

    @ICON_CLASS_VISIBLE: "icon-check"
    @ICON_CLASS_HIDDEN:  "icon-check-empty"

    updateDisplay: (menuAnchor) =>
        name = menuAnchor.find(".menu-label")?.text()
        values = menuAnchor.find(".menu-dropdown-item.active").map( -> $(this).text()).get()
        hasValues = values?.length > 0
        isInactive = not menuAnchor.hasClass("active")
        @menuItemsSelected[name] =
            if hasValues
                values
        @menusInactive[name] =
            if isInactive
                true
        menuAnchor.find(".menu-label-items")
            ?.html(if hasValues then "#{@menuLabelItemsPrefix}#{
                values.joinTextsWithShy @menuLabelItemsDelimiter}#{
                    @menuLabelItemsPostfix}" else "")
        menuAnchor.find(".menu-checkbox")
            .removeClass("#{MenuDropdown.ICON_CLASS_VISIBLE} #{
                MenuDropdown.ICON_CLASS_HIDDEN}")
            .toggleClass(MenuDropdown.ICON_CLASS_VISIBLE, not isInactive)
            .toggleClass(MenuDropdown.ICON_CLASS_HIDDEN ,     isInactive)

    triggerChangedAfterMenuBlurs: =>
        # avoid multiple checks scheduled
        return if @_triggerChangedAfterMenuBlursTimeout?
        @_triggerChangedAfterMenuBlursTimeout = setInterval =>
            # wait until no menu stays open
            return if @baseElement.find(".dropdown.open").length > 0
            @_triggerChangedAfterMenuBlursTimeout = clearInterval @_triggerChangedAfterMenuBlursTimeout
            # and detect change to trigger events
            do @triggerIfChanged
        , 100

    triggerIfChanged: =>
        thisMenuItemsSelected = JSON.stringify @menuItemsSelected
        if @lastMenuItemsSelected != thisMenuItemsSelected
            @lastMenuItemsSelected = thisMenuItemsSelected
            _.defer => @trigger "activeMenuItemsChanged"
        thisMenusInactive = JSON.stringify @menusInactive
        if @lastMenusInactive != thisMenusInactive
            @lastMenusInactive = thisMenusInactive
            _.defer => @trigger "activeMenusChanged"


class ConditionsUI extends MenuDropdown
    constructor: (@baseElement) ->
        super @baseElement, "condition"
        @conditions = {}
    load: =>
        $.getJSON("#{ExpKitServiceBaseURL}/api/conditions")
            .success(@initialize)
    initialize: (@conditions) =>
        do @clearMenu
        for name,{type,values} of @conditions
            # add each condition with menu item for each value
            menuAnchor = @addMenu name, values
            @updateDisplay menuAnchor
            log "initCondition #{name}:#{type}=#{values.join ","}"

class MeasurementsUI extends MenuDropdown
    constructor: (@baseElement) ->
        super @baseElement, "measurement"
        @menuLabelItemsPrefix  = " ("
        @menuLabelItemsPostfix = ")"
        @measurements = {}

        # initialize menu filter
        @lastMenuFilter = (localStorage["menuDropdownFilter_#{@menuName}"] ?= "{}")
        @menuFilter = try JSON.parse @lastMenuFilter
    persist: =>
        super()
        localStorage["menuDropdownFilter_#{@menuName}"] = JSON.stringify @menuFilter

    load: =>
        $.getJSON("#{ExpKitServiceBaseURL}/api/measurements")
            .success(@initialize)
    initialize: (@measurements) =>
        do @clearMenu
        for name,{type} of @measurements
            aggregations = Aggregation.FOR_TYPE[type]
            # add each measurement with menu item for each aggregation
            menuAnchor = @addMenu name, (aggName for aggName of aggregations)

            # add input elements for filter
            menuAnchor
                .find(".menu-label-items").before("""<span class="menu-label-filter"></span>""").end()
                .find(".dropdown-menu li").first().before("""
                    <li><div class="filter control-group input-prepend">
                        <span class="add-on"><i class="icon icon-filter"></i></span>
                        <input type="text" class="input-medium" placeholder="e.g., >0 & <=12.345">
                    </div></li>
                    <li class="divider"></li>
                    """)
            menuAnchor.find(".filter")
                .find("input")
                    .val(serializeFilter(@menuFilter[name]))
                    .change(@menuItemActionHandler ($this, menuAnchor) ->
                        # ...
                    )
                    .end()
                .click(@menuItemActionHandler ($this, menuAnchor) ->
                    throw new Error "don't updateDisplay"
                )

            @updateDisplay menuAnchor
            log "initMeasurement #{name}:#{type}.#{(_.keys aggregations).join ","}"

    # display current filter for a menu
    updateDisplay: (menuAnchor) =>
        # At least one menu item (aggregation) must be active all the time.
        # To totally hide this measure, user can simply check off.
        if menuAnchor.find(".menu-dropdown-item.active").length is 0
            menuAnchor.find(".menu-dropdown-item:nth(0)").addClass("active")

        # then do what it's supposed to
        super menuAnchor

        # display for filter
        name = menuAnchor.find(".menu-label")?.text()
        menuFilterInput = menuAnchor.find(".filter input")
        rawFilterExpr = menuFilterInput.val()
        if rawFilterExpr?.length > 0
            filterToStore = parseFilterExpr rawFilterExpr
            # indicate error
            menuFilterInput.closest(".control-group").toggleClass("error", not filterToStore?)
            if filterToStore?
                # normalize input
                filterToShow = serializeFilter(filterToStore)
                menuFilterInput.val(filterToShow)
            else # otherwise, leave intact
                filterToShow = ""
                filterToStore = rawFilterExpr
        else
            filterToStore = null
            filterToShow = ""
        # store the filter, and display
        @menuFilter[name] = filterToStore
        menuAnchor.find(".menu-label-filter").text(filterToShow)

    # and trigger event when it changes
    triggerIfChanged: =>
        super()
        thisMenuFilter = JSON.stringify @menuFilter
        if @lastMenuFilter isnt thisMenuFilter
            @lastMenuFilter = thisMenuFilter
            _.defer => @trigger "filtersChanged"


class ResultsTable extends CompositeElement
    @EMPTY_RESULTS:
        names: []
        rows: []

    constructor: (@baseElement, @conditions, @measurements, @optionElements = {}) ->
        super @baseElement
        # TODO isolate localStorage key
        @columnsToExpand = (try JSON.parse localStorage.resultsColumnsToExpand) ? {}
        @columnNames = null
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
        @optionElements.buttonRefresh
           ?.toggleClass("disabled", false) # TODO keep disabled until new results arrive
            .click (e) =>
               do e.preventDefault
               do @load
        do @display # initializing results table with empty data first
        @conditions.on("activeMenuItemsChanged", @load)
                   .on("activeMenusChanged", @display)
        @measurements.on("activeMenuItemsChanged", @display)
                   .on("activeMenusChanged", @display)
                   .on("filtersChanged", @load)

    load: =>
        displayNewResults = (newResults) =>
            #log "got results:", newResults
            @results = newResults
            do @display
        (
            @optionElements.containerForStateDisplay?.addClass("loading")
            # prepare the query on conditions and measures
            conditions = {}
            for name,condition of @conditions.conditions
                values = @conditions.menuItemsSelected[name]
                if values?.length > 0
                    conditions[name] = values
            unless _.values(conditions).length > 0
                # try to fetch the entire result when no condition is selected
                conditions = {}
                firstCondition = _.keys(@conditions.conditions)?[0]
                conditions[firstCondition] = [""]
            measures = {}
            for name,measure of @measurements.measurements
                measures[name] = @measurements.menuFilter[name]
            # ask for results data
            $.getJSON("#{ExpKitServiceBaseURL}/api/results",
                runs: []
                batches: []
                conditions: JSON.stringify conditions
                measures: JSON.stringify measures
            ).success(displayNewResults)
        ).done(=> @optionElements.containerForStateDisplay?.removeClass("loading"))

    @HEAD_SKELETON: $("""
        <script id="results-table-head-skeleton" type="text/x-jsrender">
          <tr>
            {{for columns}}
            <th class="{{>className}}"><span class="dataName">{{>dataName}}</span>
                {{if isMeasured && !isExpanded}}<small>(<span class="aggregationName">{{>aggregation.name}}</span>)</small>{{/if}}
                {{if isRunIdColumn || !~isRunIdExpanded && !isMeasured }}<i class="aggregation-toggler
                icon icon-folder-{{if isExpanded}}open{{else}}close{{/if}}-alt"
                title="{{if isExpanded}}Aggregate and fold the values of {{>name}}{{else
                }}Expand the aggregated values of {{>name}}{{/if}}"
                ></i>{{/if}}</th>
            {{/for}}
          </tr>
        </script>
        """)
    @ROW_SKELETON: $("""
        <script id="results-table-row-skeleton" type="text/x-jsrender">
          <tr class="result" data-ordinal="{{>~ordinal}}">
            {{for columns}}
            <td class="{{>className}} {{>type}}-type" data-value="{{>value}}">
              {{if aggregation}}
              <div class="aggregated {{>aggregation.name}}"
                {{if type != "object" && values}}
                data-placement="{{if isLastColumn}}left{{else}}bottom{{/if}}" data-trigger="click"
                title="{{>aggregation.name}}{{if aggregation.name != 'enumeration'}} = {{:value}}{{/if}}"
                data-html="true" data-content='<ul>
                  {{for valuesDistinct}}
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
        {{if ~column.isRunIdColumn}}<a href="{{>~ExpKitServiceBaseURL}}/{{>~value}}/overview">{{>~value}}</a>{{else}}{{>~value}}{{/if}}
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
        do =>
            # construct column definitions
            columns = {}
            idx = 0
            #  first, conditions
            showHiddenConditions = @optionElements.toggleShowHiddenConditions?.is(":checked")
            for name,condition of @conditions.conditions
                isExpanded =  @columnsToExpand[RUN_COLUMN_NAME] or
                    @columnsToExpand[name] and (showHiddenConditions or not @conditions.menusInactive[name]?)
                columns[name] =
                    name: name
                    dataName: name
                    type: if isExpanded then condition.type else "string"
                    isMeasured: no
                    isInactive: @conditions.menusInactive[name]
                    isExpanded: isExpanded
                    aggregation: {name:"enumeration", type:"string", func:@_enumerateAll name} unless isExpanded
                    index: idx++
            #  then, measures
            for name,measure of @measurements.measurements when not @measurements.menusInactive[name]
                col =
                    dataName: name
                    type: measure.type
                    isMeasured: yes
                    isInactive: @measurements.menusInactive[name]
                    isExpanded: @columnsToExpand[RUN_COLUMN_NAME]
                    isRunIdColumn: name is RUN_COLUMN_NAME
                if col.isExpanded
                    columns[name] = _.extend col,
                        name: name
                        index: idx++
                else
                    aggs = Aggregation.FOR_TYPE[col.type] ? _.values(Aggregation.FOR_TYPE)[0]
                    for aggName in @measurements.menuItemsSelected[name] ? []
                        agg = aggs[aggName]
                        agg = _.values(aggs)[0] unless agg?
                        colName = "#{name}.#{aggName}"
                        columns[colName] = _.extend {}, col,
                            name: colName
                            type: agg.type
                            aggregation: agg
                            index: idx++
            @columns = columns
            @columnNames = []; @columnNames[col.index] = name for name,col of columns
        #log "column order:", @columnNames
        #log "column definitions:", @columns

        # prepare several other auxiliary structures
        idx = 0
        @columnNamesExpanded =
            for name in @columnNames when @columns[name].isExpanded
                @columns[name].indexAmongExpanded = idx++
                name
        columnIndex = {}; columnIndex[name] = idx for name,idx in @results.names

        # and preprocess data
        isRunIdExpanded = @columns[RUN_COLUMN_NAME]?.isExpanded ? false
            # or we could use: @columnsToExpand[RUN_COLUMN_NAME]
            #    (it will allow unaggregated tables without run column)
        @optionElements.toggleIncludeEmpty?.prop("disabled", isRunIdExpanded)
        if isRunIdExpanded
            # present results without aggregation
            log "no aggregation"
            @resultsForRendering =
                for row in @results.rows
                    for name in @columnNames
                        value: row[columnIndex[name]]
        else
            # aggregate data
            groupRowsByColumns = (rows) =>
                map = (row) => JSON.stringify (@columnNamesExpanded.map (name) -> row[columnIndex[name]])
                red = (key, groupedRows) =>
                    for name in @columnNames
                        col = @columns[name]
                        idx = columnIndex[col.dataName]
                        if col.isExpanded
                            value: groupedRows[0][idx]
                        else
                            values = (row[idx] for row in groupedRows)
                            value: col.aggregation.func(values, groupedRows, idx, columnIndex, name)
                            values: values
                            valuesDistinct: _.uniq values
                grouped = mapReduce(map, red)(rows)
                [_.values(grouped), _.keys(grouped)]
            [aggregatedRows, aggregatedGroups] = groupRowsByColumns(@results.rows)
            #log "aggregated results:", aggregatedRows
            #log "aggregated groups:", aggregatedGroups
            # pad aggregatedRows with missing combination of condition values
            emptyRows = []
            if @optionElements.toggleIncludeEmpty?.is(":checked")
                EMPTY_GROUPED_ROWS = EMPTY_VALUES = []
                columnValuesForGrouping =
                    for name in @columnNamesExpanded
                        @conditions.menuItemsSelected[name] ? @conditions.conditions[name].values
                forEachCombination columnValuesForGrouping, (group) =>
                    key = JSON.stringify group
                    unless key in aggregatedGroups
                        #log "padding empty row for #{key}"
                        emptyRows.push @columnNames.map (name) =>
                            col = @columns[name]
                            idx = columnIndex[col.dataName]
                            if col.isExpanded
                                value: group[col.indexAmongExpanded]
                            else
                                value: col.aggregation.func(EMPTY_VALUES, EMPTY_GROUPED_ROWS, idx, columnIndex, name) ? ""
                                values: EMPTY_VALUES
                                valuesDistinct: EMPTY_VALUES
                #log "padded empty groups:", emptyRows
            @resultsForRendering = aggregatedRows.concat emptyRows
        #log "rendering results:", @resultsForRendering

        # fold any artifacts made by previous DataTables
        @dataTable?.dataTable bDestroy:true

        # populate table head
        thead = @baseElement.find("thead")
        thead.find("tr").remove()
        columnMetadata = {}
        thead.append(ResultsTable.HEAD_SKELETON.render(
            columns:
                for name in @columnNames
                    col = @columns[name]
                    columnMetadata[name] = _.extend {}, col,
                        className: "#{if col.isMeasured then "measurement" else "condition"
                                   }#{if col.isInactive then " muted"      else ""
                                   }#{if col.isExpanded then " expanded"   else ""
                                   }"
                        formatter: Aggregation.DATA_FORMATTER_FOR_TYPE?(col.type, @resultsForRendering, col.index)
                        isLastColumn: col.index is @columnNames.length - 1
            , {ExpKitServiceBaseURL, isRunIdExpanded}
            ))
        # allow the column header to toggle aggregation
        t = @
        thead.find(".aggregation-toggler").click((e) ->
            return if e.shiftKey # to reduce interference with DataTables' sorting
            $this = $(this)
            th = $this.closest("th")
            th.toggleClass("expanded")
            name = th.find("span.dataName").text()
            t.columnsToExpand[name] = if th.hasClass("expanded") then true else null
            localStorage.resultsColumnsToExpand = JSON.stringify t.columnsToExpand
            do t.display
            do e.stopPropagation
        )

        # populate table body
        @baseElement.find("tbody").remove()
        tbody = $("<tbody>").appendTo(@baseElement)
        for row,ordinal in @resultsForRendering
            tbody.append(ResultsTable.ROW_SKELETON.render(
                columns: (
                    for name,idx in @columnNames
                        c = $.extend {}, columnMetadata[name], row[idx]
                        c.formattedValue = c.formatter c.value
                        c
                ), {
                    ExpKitServiceBaseURL
                    ordinal
                    CELL_SKELETON: ResultsTable.CELL_SKELETON
                }))
        tbody.find(".aggregated")
            .popover(trigger: "manual")
            .click((e) ->
                tbody.find(".aggregated").not(this).popover("hide")
                $(this).popover("show")
                e.stopPropagation()
                e.preventDefault()
            )

        computeRequireTableWidth = (columnMetadata) ->
            width = 0
            for name,col of columnMetadata
                width +=
                    # TODO be more precise
                    switch col.type
                        when "object"
                            300
                        when "number", "string"
                            150
                        else
                            100
            width


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
            bScrollCollapse: true
            sScrollX: "100%"
            #sScrollXInner: "#{Math.round Math.max(computeRequireTableWidth(@columnMetadata),
            #                      @baseElement.parent().size().width)}px"
            sScrollY: "#{Math.round Math.max(400, window.innerHeight - @baseElement.position().top - 80)}px"
            # Use localStorage instead of cookies (See: http://datatables.net/blog/localStorage_for_state_saving)
            # TODO isolate localStorage key
            fnStateSave: (oSettings, oData) -> localStorage.resultsDataTablesState = JSON.stringify oData
            fnStateLoad: (oSettings       ) -> try JSON.parse localStorage.resultsDataTablesState
            bStateSave: true
            oColReorder:
                fnReorderCallback: => @optionElements.buttonResetColumnOrder?.toggleClass("disabled", @isColumnReordered())
        do @updateColumnVisibility

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
            then (name) => not @columns[name].isInactive
            else (name) => true
        for name,idx in @columnNames
            @dataTable.fnSetColumnVis (colOrder.indexOf idx), (isVisible name), false
        do @dataTable.fnDraw




displayChart = ->
    chartBody = d3.select("#chart-body")
    margin = {top: 20, right: 20, bottom: 50, left: 100}
    width = 960 - margin.left - margin.right
    height = 500 - margin.top - margin.bottom

    xAxisLabel = ExpKit.results.columnNamesExpanded[0] # FIXME
    yAxisLabel = ExpKit.results.columnNamesMeasured[0] # FIXME
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
                log "running-count", count
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
            @dataTable.one "draw", =>
                @baseElement.find("tbody tr:nth(0)").click()

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
            data-content='<a href="{{>~ExpKitServiceBaseURL}}/{{>run}}/overview">{{>run}}</a>'
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
                        <h3 class="popover-title">Add to <i class="icon icon-time"></i>Plan</h3>
                        <div class="popover-content">
                        <ul class="nav nav-list">
                            <li><a class="btn add add-all"><i class="icon icon-repeat"></i> <b class="num-all">0</b> Full Combinations</a></li>
                            <li><a class="btn add add-random"><i class="icon icon-random"></i> <b class="num-random">10</b> Random Runs</a>
                            <input class="random-percent" type="range" min="1" max="100" step="1">
                            </li>
                        </ul>
                        <div>From conditions <span class="expanded-conditions"></span></div>
                        </div>
                    </div>
                </div>
                """).appendTo(document.body)
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
                resultsTableColumns = rt.columns
                conditionNames = []
                popover.valuesArray =
                    for name,allValues of @conditions.conditions
                        conditionNames.push name
                        column = resultsTableColumns[name]
                        if column.isExpanded
                            [currentDataRow[column.index].value]
                        else
                            values = @conditions.menuItemsSelected[name]
                            if values?.length > 0 then values
                            else allValues?.values ? [] # XXX latter should not happen in any case
                popover.numAllRuns = _.foldr popover.valuesArray.map((vs) -> vs.length), (a,b) -> a*b
                popover
                    .find(".num-all").text(popover.numAllRuns).end()
                    .find(".random-percent").change().end()
                    .find(".expanded-conditions").find("*").remove().end().append(
                        for name,i in conditionNames
                            $("<span>").addClass("label label-info")
                                .html("#{name}=#{popover.valuesArray[i].joinTextsWithShy(",")}")
                                .after(" ")
                    )
            # attach the popover to the results table
            displayPopover = ($tr) ->
                # TODO display only when there is an expanded condition column
                # try to avoid attaching to the same row more than once
                return if popover.closest("tr")?.index() is $tr.index()
                popover.removeClass("in")
                _.defer ->
                    updatePopoverContent $tr
                    # attach to the current row
                    $tr.find("td:nth(0)").append(popover)
                    pos = $tr.position()
                    popover.addClass("in")
                        .css
                            top:  "#{pos.top  - (popover.height() - $tr.height())/2}px"
                            left: "#{pos.left -  popover.width()                   }px"
                            "z-index": 1000
            #  in a somewhat complicated way to make it appear/disappear after a delay
            POPOVER_SHOW_DELAY_INITIAL = 3000
            POPOVER_SHOW_HIDE_DELAY    =  100
            popoverShowTimeout = null
            popoverHideTimeout = null
            popoverResetDelayTimeout = null
            resetTimerAndDo = (next) ->
                popoverResetDelayTimeout = clearTimeout popoverResetDelayTimeout if popoverResetDelayTimeout?
                popoverHideTimeout = clearTimeout popoverHideTimeout if popoverHideTimeout?
                # TODO is there any simple way to detect changes in row to fire displayPopover?
                popoverShowTimeout = clearTimeout popoverShowTimeout if popoverShowTimeout?
                do next
            rt.baseElement.parent()
                .on("click", "tbody tr", (e) -> resetTimerAndDo =>
                    popover.showDelay = POPOVER_SHOW_HIDE_DELAY
                    displayPopover $(this).closest("tr")
                    )
                .on("mouseover", "tbody tr", (e) -> resetTimerAndDo =>
                    popoverShowTimeout = setTimeout =>
                        popover.showDelay = POPOVER_SHOW_HIDE_DELAY
                        displayPopover $(this).closest("tr")
                        popoverShowTimeout = null
                    , popover.showDelay ?= POPOVER_SHOW_DELAY_INITIAL
                    )
                .on("mouseout",  "tbody tr", (e) -> resetTimerAndDo =>
                    popoverHideTimeout = setTimeout ->
                        popover.removeClass("in")
                            .css("z-index": -1000).appendTo(document.body)
                            # XXX .remove() will break all attached event handlers, so send it away somewhere
                        popoverResetDelayTimeout = clearTimeout popoverResetDelayTimeout if popoverResetDelayTimeout?
                        popoverResetDelayTimeout = setTimeout ->
                            popover.showDelay = POPOVER_SHOW_DELAY_INITIAL
                            popoverResetDelayTimeout = null
                        , POPOVER_SHOW_DELAY_INITIAL / 3
                        popoverHideTimeout = null
                    , POPOVER_SHOW_HIDE_DELAY
                    )
                .on("click", "tbody tr .add.btn", @addPlanFromRowHandler())

    @STATE: "REMAINING"
    addPlanFromRowHandler: =>
        add = (strategy) =>
            popover = @resultsActionPopover
            # don't proceed if no condition is expanded
            if popover.numAllRuns is 0
                error "Cannot add anything to plan: no expanded condition"
                return
            valuesArray = popover.valuesArray
            # check valuesArray to see if we are actually generating some plans
            for values,idx in valuesArray when not values? or values.length is 0
                name = (name of @conditions.conditions)[idx]
                error "Cannot add anything to plan: no values for condition #{name}"
                return
            # add generated combinations to the current plan
            log "adding #{strategy} plans for", valuesArray
            rows = @plan.rows
            prevSerialLength = String(rows.length).length
            # add to plans using the given strategy
            PlanTable.PLAN_ADDITION_STRATEGY[strategy](popover) valuesArray, (comb) =>
                rows.push [++@plan.lastSerial, PlanTable.STATE, comb...]
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
            # find which btn was pressed
            for c in $(this).closest(".add").attr("class")?.split(/\s+/)
                if m = c.match /^add-(.+)$/
                    return add m[1]

    @PLAN_ADDITION_STRATEGY:

        all: (popover) -> forEachCombination

        random: (popover) -> (valuesArray, addCombination) ->
            allCombos = []
            forEachCombination valuesArray, (comb) -> allCombos.push comb
            numRandom = +popover.find(".num-random").text()
            choose(numRandom, allCombos).forEach addCombination



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
                buttonRefresh               : $("#results-refresh")
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
    do initChartUI
    do initBaseURLControl
    do initSocketIO
    do initTabs

