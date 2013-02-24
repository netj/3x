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

choose = (n, items) ->
    indexes = [0...items.length]
    indexesChosen =
        for i in [1..n]
            indexes.splice _.random(0, indexes.length - 1), 1
    indexesChosen.map (i) -> items[i]


enumerate = (vs) -> vs.joinTextsWithShy ","

isNominal = (type) -> type in ["string", "nominal"]
isRatio   = (type) -> type in ["number","ratio"]

isAllNumeric = (vs) -> not vs.some (v) -> isNaN parseFloat v
tryConvertingToNumbers = (vs) ->
    if isAllNumeric vs
        vs.map (v) -> +v
    else
        vs


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
    constructor: (@name, @type, @func, @transUnit = _.identity) ->
        Aggregation.FOR_NAME[@name] = @
    @FOR_NAME: {}
    @FOR_TYPE: {}
    @registerForType: (type, names...) ->
        _.extend (Aggregation.FOR_TYPE[type] ?= {}), (_.pick Aggregation.FOR_NAME, names...)
    do ->
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
        Aggregation.registerForType "nominal"  , "count"  , "mode"  , "enumeration"
        Aggregation.registerForType "ordinal"  , "median" , "mode"  , "min"       , "max"  , "count" , "enumeration"
        Aggregation.registerForType "interval" , "mean"   , "stdev" , "median"    , "mode" , "min"   , "max"       , "enumeration"
        Aggregation.registerForType "ratio"    , "mean"   , "stdev" , "median"    , "mode" , "min"   , "max"       , "enumeration"


# different rendering methods depending on data type
class DataRenderer
    # HTML generator, or DOM manipulator, or both can be used
    @_ID:   (v,   rowIdxs, data, col, runColIdx) -> v
    @_NOOP: ($td, rowIdxs, data, col, runColIdx) -> null
    @ID:    (allRows, colIdx) -> DataRenderer._ID
    @NOOP:  (allRows, colIdx) -> DataRenderer._NOOP
    @FOR_TYPE: {}
    constructor: (@type, @html = DataRenderer.ID, @dom = DataRenderer.NOOP) ->
        DataRenderer.FOR_TYPE[@type] = @
    @DEFAULT_RENDERER: new DataRenderer ""
    @TYPE_ALIASES: {}
    @addAliases: (ty, tys...) -> DataRenderer.TYPE_ALIASES[t] = ty for t in tys
    @forType: (type) ->
        # resolve type aliases
        type = DataRenderer.TYPE_ALIASES[type] ? type
        DataRenderer.FOR_TYPE[type] ? DataRenderer.DEFAULT_RENDERER
    @htmlGeneratorForTypeAndData: (type, rows, colIdx) -> DataRenderer.forType(type).html rows, colIdx
    @domManipulatorForTypeAndData: (type, rows, colIdx) -> DataRenderer.forType(type).dom rows, colIdx
do ->
    new DataRenderer "string"
    DataRenderer.addAliases "string", "nominal"
    new DataRenderer "number", (allRows, colIdx) ->
        #when "number", "ordinal", "interval", "ratio"
        # go through all the values of allRows at colIdx and determine precision
        sumIntegral   = 0; maxIntegral   = 0; minIntegral   = 0
        sumFractional = 0; maxFractional = 0; minFractional = 0
        count = 0
        for row in allRows
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
        do (prec) -> (v) ->
            parseFloat(v).toFixed(prec) if v? and v != ""
    DataRenderer.addAliases "number", "ratio", "interval", "ordinal"
    # TODO ordinals could be or not be numbers, how about trying to detect them first?


# More complex types
do ->
    new DataRenderer "hyperlink", (allRows, colIdx) ->
        (v, rowIdxs, data, col, runColIdx) ->
            if typeof rowIdxs is "number"
                """
                <a href="#{ExpKitServiceBaseURL}/#{v}/overview">#{v}</a>
                """
            else
                v
    # aggregation/rendering for images
    new Aggregation "overlay", "image", Aggregation.FOR_NAME.count.func
    Aggregation.registerForType "image/png", "overlay", "count"
    new DataRenderer "image", (allRows, colIdx) ->
        MAX_IMAGES = 20 # TODO Chrome is sluggish at rendering many translucent images
        BASE_OPACITY = 0.05 # minimum opacity
        VAR_OPACITY  = 0.50 # ratio to plus/minus the dividend opacity
        (v, rowIdxs, data, col, runColIdx) ->
            rowIdxs = [rowIdxs] if typeof rowIdxs is "number"
            if rowIdxs?.length > 0
                rows = (data.rows[rowIdx] for rowIdx in rowIdxs)
                colIdx = col.dataIndex
                numOverlaid = Math.min(MAX_IMAGES, rows.length)
                sampledRows =
                    if rows.length <= MAX_IMAGES then rows
                    # TODO can we do a better sampling?
                    else rows[i] for i in [0...rows.length] by Math.floor(rows.length / MAX_IMAGES)
                divOpacity = (1 - BASE_OPACITY) / numOverlaid
                """<span class="overlay-frame">"""+
                (for row,i in sampledRows
                    """
                    <img class="overlay"
                    src="#{ExpKitServiceBaseURL}/#{row[runColIdx]}/workdir/#{row[colIdx]}"
                    style="opacity: #{BASE_OPACITY + divOpacity * (1.0 + VAR_OPACITY/2 * (numOverlaid/2 - i) / numOverlaid)};">
                    """
                ).join("") + """</span>"""
    DataRenderer.addAliases "image", "image/png", "image/jpeg", "image/gif" #, TODO ...




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
        #log "showing tab", tab
        switch tab
            when "results"
                ExpKit.results?.dataTable?.fnDraw()
            when "chart"
                do ExpKit.chart?.display
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
        $.getJSON("#{ExpKitServiceBaseURL}/api/inputs")
            .success(@initialize)
    initialize: (@conditions) =>
        do @clearMenu
        for name,{type,values} of @conditions
            # add each condition with menu item for each value
            menuAnchor = @addMenu name, values
            @updateDisplay menuAnchor
            try log "initCondition #{name}:#{type}=#{values.join ","}"

class MeasurementsUI extends MenuDropdown
    constructor: (@baseElement) ->
        super @baseElement, "measurement"
        @menuLabelItemsPrefix  = " ["
        @menuLabelItemsPostfix = "]"
        @measurements = {}

        # initialize menu filter
        @lastMenuFilter = (localStorage["menuDropdownFilter_#{@menuName}"] ?= "{}")
        @menuFilter = try JSON.parse @lastMenuFilter
    persist: =>
        super()
        localStorage["menuDropdownFilter_#{@menuName}"] = JSON.stringify @menuFilter

    load: =>
        $.getJSON("#{ExpKitServiceBaseURL}/api/outputs")
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
            try log "initMeasurement #{name}:#{type}.#{(_.keys aggregations).join ","}"

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
        $(window).resize(_.throttle @maximizeDataTable, 100)
        @conditions.on("activeMenuItemsChanged", @load)
                   .on("activeMenusChanged", @display)
        @measurements.on("activeMenuItemsChanged", @display)
                   .on("activeMenusChanged", @display)
                   .on("filtersChanged", @load)

        do @initBrushing

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
                inputs: JSON.stringify conditions
                outputs: JSON.stringify measures
            ).success(displayNewResults)
        ).done(=> @optionElements.containerForStateDisplay?.removeClass("loading"))

    @HEAD_SKELETON: $("""
        <script type="text/x-jsrender">
          <tr>
            {{for columns}}
            <th class="{{>className}}" data-index="{{>index}}" data-dataIndex="{{>dataIndex}}"><span class="dataName">{{>dataName}}</span>
                {{if unit}}(<span class="unit">{{>unit}}</span>){{/if}}
                {{if isMeasured && !isExpanded}}<small>[<span class="aggregationName">{{>aggregation.name}}</span>]</small>{{/if}}
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
        <script type="text/x-jsrender">
          <tr class="result" data-ordinal="{{>ordinal}}">
            {{for columns}}
            <td class="{{>className}} {{>type}}-type{{if aggregation
                }} aggregated {{>aggregation.name}}{{/if}}"
                data-value="{{>value}}">{{:valueFormatted}}</td>
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
        columnIndex = {}; columnIndex[name] = idx for name,idx in @results.names
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
                    dataIndex: columnIndex[name]
                    dataType: condition.type
                    dataUnit: condition.unit
                    unit: if isExpanded then condition.unit
                    type: if isExpanded then condition.type else "string"
                    isMeasured: no
                    isInactive: @conditions.menusInactive[name]
                    isExpanded: isExpanded
                    aggregation: {name:"enumeration", type:"string", func:@_enumerateAll name} unless isExpanded
                    index: idx++
            #  then, measures
            for name,measure of @measurements.measurements when not @measurements.menusInactive[name]
                type = if name is RUN_COLUMN_NAME then "hyperlink" else measure.type
                unit = if name is RUN_COLUMN_NAME then null        else measure.unit
                col =
                    dataName: name
                    dataIndex: columnIndex[name]
                    dataType: type
                    dataUnit: unit
                    type: type
                    unit: unit
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
                            unit: agg.transUnit(unit)
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

        # and preprocess data
        isRunIdExpanded = @columns[RUN_COLUMN_NAME]?.isExpanded ? false
            # or we could use: @columnsToExpand[RUN_COLUMN_NAME]
            #    (it will allow unaggregated tables without run column)
        @optionElements.toggleIncludeEmpty?.prop("disabled", isRunIdExpanded)
        if isRunIdExpanded
            # present results without aggregation
            #log "no aggregation"
            @resultsForRendering =
                for row,rowIdx in @results.rows
                    for name in @columnNames
                        value: row[columnIndex[name]]
                        origin: rowIdx
        else
            # aggregate data
            groupRowsByColumns = (rows) =>
                idxs = [0...rows.length]
                map = (rowIdx) => JSON.stringify (@columnNamesExpanded.map (name) -> rows[rowIdx][columnIndex[name]])
                red = (key, groupedRowIdxs) =>
                    for name in @columnNames
                        col = @columns[name]
                        colIdx = col.dataIndex
                        if col.isExpanded
                            value: rows[groupedRowIdxs[0]][colIdx]
                        else
                            value: col.aggregation.func(rows[rowIdx][colIdx] for rowIdx in groupedRowIdxs)
                            origin: _.sortBy(groupedRowIdxs,
                                    if isAllNumeric (groupedRowIdxs.map (rowIdx) -> rows[rowIdx][colIdx])
                                        (rowIdx) -> +rows[rowIdx][colIdx]
                                    else
                                        (rowIdx) ->  rows[rowIdx][colIdx]
                                )
                grouped = mapReduce(map, red)(idxs)
                [_.values(grouped), _.keys(grouped)]
            [aggregatedRows, aggregatedGroups] = groupRowsByColumns(@results.rows)
            #log "aggregated results:", aggregatedRows
            #log "aggregated groups:", aggregatedGroups
            # pad aggregatedRows with missing combination of condition values
            emptyRows = []
            if @optionElements.toggleIncludeEmpty?.is(":checked")
                EMPTY_VALUES = []
                columnValuesForGrouping =
                    for name in @columnNamesExpanded
                        @conditions.menuItemsSelected[name] ? @conditions.conditions[name].values
                forEachCombination columnValuesForGrouping, (group) =>
                    key = JSON.stringify group
                    unless key in aggregatedGroups
                        #log "padding empty row for #{key}"
                        emptyRows.push @columnNames.map (name) =>
                            col = @columns[name]
                            if col.isExpanded
                                value: group[col.indexAmongExpanded]
                            else
                                value: col.aggregation.func(EMPTY_VALUES) ? ""
                #log "padded empty groups:", emptyRows
            @resultsForRendering = aggregatedRows.concat emptyRows
        #log "rendering results:", @resultsForRendering

        # fold any artifacts made by previous DataTables
        @dataTable?.dataTable bDestroy:true

        # populate table head
        thead = @baseElement.find("thead")
        thead.find("tr").remove()
        columnMetadata = []
        thead.append(ResultsTable.HEAD_SKELETON.render(
            columns:
                for name,idx in @columnNames
                    col = @columns[name]
                    columnMetadata[idx] = _.extend col,
                        className: "#{if col.isMeasured then "measurement" else "condition"
                                   }#{if col.isInactive then " muted"      else ""
                                   }#{if col.isExpanded then " expanded"   else ""
                                   }"
                        # renderer can't be defined earlier because it needs to see the data
                        renderer: DataRenderer.htmlGeneratorForTypeAndData(col.type, @resultsForRendering, col.index)
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
        tbody = $("<tbody>").append(do =>
            runColIdx = columnIndex[RUN_COLUMN_NAME]
            for row,ordinal in @resultsForRendering
                ResultsTable.ROW_SKELETON.render {
                        ordinal
                        columns:
                            for c,idx in columnMetadata
                                $.extend {}, c, row[idx],
                                    valueFormatted: c.renderer(row[idx].value,
                                            row[idx].origin, @results, c, runColIdx)
                    }, {
                        ExpKitServiceBaseURL
                    }
        ).appendTo(@baseElement)
        # TODO apply DataRenderer dom mainpulator

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
            sScrollY: "#{window.innerHeight - @baseElement.position().top}px"
            # Use localStorage instead of cookies (See: http://datatables.net/blog/localStorage_for_state_saving)
            # TODO isolate localStorage key
            fnStateSave: (oSettings, oData) -> localStorage.resultsDataTablesState = JSON.stringify oData
            fnStateLoad: (oSettings       ) -> try JSON.parse localStorage.resultsDataTablesState
            bStateSave: true
            oColReorder:
                fnReorderCallback: =>
                    @optionElements.buttonResetColumnOrder?.toggleClass("disabled", @isColumnReordered())
                    do @updateColumnIndexMappings
        do @updateColumnVisibility
        do @updateColumnIndexMappings
        do @maximizeDataTable

        # trigger event for others
        _.defer => @trigger("changed", @resultsForRendering)
        @dataTable.on "draw", => try @trigger("updated")

    maximizeDataTable: =>
        @dataTable.fnSettings().oScroll.sY = "#{window.innerHeight - @baseElement.position().top}px"
        @dataTable.fnDraw()

    updateColumnIndexMappings: =>
        # Construct column index mappings for others to build functions on top of it.
        # Mapping the observed DOM index to the actual column index for either
        # @resultsForRendering or @results.rows is hard because DataTables'
        # ColReorder and fnSetColumnVis significantly changes the DOM.
        $ths = @dataTable.find("thead:nth(0)").find("th")
        @columnsRenderedToProcessed = $ths.map((i,th) -> +$(th).attr("data-index")    ).toArray()
        @columnsRenderedToData      = $ths.map((i,th) -> +$(th).attr("data-dataIndex")).toArray()
        @columnsRendered            = (@columns[@columnNames[i]] for i in @columnsRenderedToProcessed)
        #log "updateColumnIndexMappings", @columnsRenderedToProcessed, @columnsRenderedToProcessed, @columnsRendered

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


    initBrushing: =>
        # setup brushing table cells, so as we hover over a td element, the
        # cell as well as others will be displaying the raw data value
        provenancePopoverParent = @baseElement.parent()
        provenancePopover = @brushingProvenancePopover = $("""
            <div class="provenance popover fade top">
                <div class="arrow"></div>
                <div class="popover-inner">
                    <div class="popover-content">
                        <a class="provenance-link"></a>
                    </div>
                </div>
            </div>
            """).appendTo(provenancePopoverParent)
        # TODO clean these popover code with https://github.com/jakesgordon/javascript-state-machine
        hideTimeout = null
        detachProvenancePopoverTimeout = null
        attachProvenancePopover = ($td, e, cursorRelPos, runId) =>
            detachProvenancePopoverTimeout = clearTimeout detachProvenancePopoverTimeout if detachProvenancePopoverTimeout?
            hideTimeout = clearTimeout hideTimeout if hideTimeout?
            pos = $td.position()
            provenancePopover
                .find(".provenance-link").text(runId)
                    .attr(href:"#{ExpKitServiceBaseURL}/#{runId}/overview").end()
                .removeClass("hide")
                .css
                    top:  "#{pos.top              - (provenancePopover.height())}px"
                    left: "#{pos.left + e.offsetX - (provenancePopover.width()/2)}px"
            _.defer => provenancePopover.addClass("in")
        endBrushingTimeout = null
        detachProvenancePopover = =>
            detachProvenancePopoverTimeout = clearTimeout detachProvenancePopoverTimeout if detachProvenancePopoverTimeout?
            hideTimeout = clearTimeout hideTimeout if hideTimeout?
            detachProvenancePopoverTimeout = setTimeout ->
                    provenancePopover.removeClass("in")
                    hideTimeout = clearTimeout hideTimeout if hideTimeout?
                    hideTimeout = setTimeout (=> provenancePopover.addClass("hide")), 150
                , 100
        provenancePopover
            .on("mouseover", (e) ->
                endBrushingTimeout = clearTimeout endBrushingTimeout if endBrushingTimeout?
                detachProvenancePopoverTimeout = clearTimeout detachProvenancePopoverTimeout if detachProvenancePopoverTimeout?
            )
            .on("mouseout", (e) ->
                endBrushingTimeout = clearTimeout endBrushingTimeout if endBrushingTimeout?
                endBrushingTimeout = setTimeout endBrushing, 100
                do detachProvenancePopover
            )
        brushingMode = off
        brushingIsPossible = no
        brushingTRIndex = null
        brushingRowProcessed = null
        brushingLastRowIdx = null
        brushingSetupRow = null
        brushingCellRenderer = null
        brushingTDs = null
        brushingTDsOrigContent = null
        brushingTDsAll = null
        brushingTDsOrigCSSText = null
        # cached
        runColIdx = null
        @on "changed", => # precompute frequently used info every once the table changes
            runColIdx = @results.names.indexOf RUN_COLUMN_NAME
        updateBrushing = ($td, e) =>
            return unless brushingIsPossible
            colIdxRendered = $td.index()
            return if @columnsRendered[colIdxRendered].isExpanded or not brushingTDs?
            colIdxProcessed = @columnsRenderedToProcessed[colIdxRendered]
            brushingCell = brushingRowProcessed[colIdxProcessed]
            return unless brushingCell?.origin?.length > 0
            # find out the relative position we're brushing
            cursorRelPos = e.offsetX / $td[0].offsetWidth
            n = brushingCell.origin.length - 1
            brushingPos = Math.max(0, Math.min(n, Math.round(n * cursorRelPos)))
            rowIdxData  = brushingCell.origin[brushingPos]
            attachProvenancePopover $td, e, brushingPos, @results.rows[rowIdxData][runColIdx]
            return if brushingLastRowIdx is rowIdxData # update only when there's change, o.w. flickering happens
            brushingLastRowIdx = rowIdxData
            #log "updating", brushingLastRowIdx
            #do => # XXX debug
            #    window.status = "#{@columnsRendered[colIdxRendered].name}: #{brushingPos}/#{brushingCell.origin.length-1} = #{cursorRelPos}"
            #    log "updateBrushing", @columnsRendered[colIdxRendered].name, brushingSetupRow, rowIdxData, brushingPos, brushingCell.origin.length-1
            # then, update the cells to corresponding values
            brushingTDs.each (i,td) =>
                colIdxRendered = $(td).index()
                colIdxProcessed = @columnsRenderedToProcessed[colIdxRendered]
                colIdxData      = @columnsRenderedToData[colIdxRendered]
                # use DataRenderer to show them
                c = @columnsRendered[colIdxRendered]
                $(td).html(
                    # XXX somehow, the first row isn't refreshing even though correct html is being set
                    (if brushingTRIndex is 0 then "<span></span>" else "") +
                    brushingCellRenderer[i]?(@results.rows[rowIdxData][colIdxData],
                            rowIdxData, @results, c, runColIdx) ? ""
                )
        endBrushing = =>
            # restore DOM of previous TR
            if brushingSetupRow?
                #log "endBrushing", brushingSetupRow #, brushingTDs, brushingTDsOrigContent
                brushingTDs?.removeClass("brushing").each (i,td) =>
                    $(td).contents().remove().end().append(brushingTDsOrigContent[i])
                brushingTDsAll?.each (i,td) =>
                    td.style.cssText = brushingTDsOrigCSSText[i]
                do detachProvenancePopover
                brushingRowProcessed = brushingSetupRow = brushingLastRowIdx =
                    brushingCellRenderer =
                    brushingTDs = brushingTDsOrigContent =
                    brushingTDsAll = brushingTDsOrigCSSText =
                        null
        startBrushing = ($td, e) =>
            # find which row we're brushing
            $tr = $td.closest("tr")
            rowIdxProcessed = $tr.attr("data-ordinal")
            brushingIsPossible = not @columnsRendered[$td.index()].isExpanded and rowIdxProcessed?
            if brushingIsPossible
                rowIdxProcessed = +rowIdxProcessed
                #log "startBrushing", rowIdxProcessed
                # setup the cells to start brushing
                unless brushingSetupRow is rowIdxProcessed
                    do endBrushing
                    #log "setting up row #{rowIdxProcessed} for brushing"
                    brushingSetupRow = rowIdxProcessed
                    brushingTRIndex = $tr.index()
                    brushingRowProcessed = @resultsForRendering[brushingSetupRow]
                    brushingTDsAll = $tr.find("td")
                    brushingTDs = brushingTDsAll.filter((i,td) => not @columnsRendered[i].isExpanded)
                    groupedRowIdxs = brushingRowProcessed[@columnsRenderedToProcessed[brushingTDs.index()]]?.origin
                    unless groupedRowIdxs?
                        # filled empty row, makes no sense to brush here
                        brushingRowProcessed = brushingSetupRow =
                            brushingTDs = brushingTDsAll =
                                null
                        brushingIsPossible = no
                        return
                    brushingTDsOrigCSSText = []
                    brushingTDsAll.each (i,td) =>
                        # fix width of each cell we're going to touch
                        brushingTDsOrigCSSText[i] = td.style.cssText
                        # copy from thead
                        $th = @dataTable.find("thead").eq(0).find("th").eq(i)
                        td.style.cssText += """;
                            width: #{$th.css("width")} !important;
                            min-height: #{td.offsetHeight}px !important;
                            word-break: break-all;
                            word-wrap: break-word;
                        """ # XXX .style.cssText is the only way to give !important :S
                    brushingTDsOrigContent = []
                    brushingTDs.addClass("brushing").each (i,td) =>
                        # detach the contents DOM and keep it safe
                        brushingTDsOrigContent[i] = $(td).contents().detach()
                    # prepare DataRenderer for each cell
                    brushingCellRenderer = []
                    processedForThisRow =
                        for rowIdx in groupedRowIdxs
                            for col in @results.rows[rowIdx]
                                value: col
                    #log "DataRenderer", brushingRowProcessed, processedForThisRow
                    brushingTDs.each (i,td) =>
                        # derive a renderer using only the values within this row
                        col = @columnsRendered[$(td).index()]
                        brushingCellRenderer[i] =
                            try DataRenderer.htmlGeneratorForTypeAndData(col.dataType, processedForThisRow, col.dataIndex)
                updateBrushing $td, e
            else
                # not on a brushable cell
                do endBrushing
        @baseElement.parent()
            .on("mouseover", "tbody td", (e) ->
                brushingMode = e.shiftKey
                return unless brushingMode
                endBrushingTimeout = clearTimeout endBrushingTimeout if endBrushingTimeout?
                startBrushing $(@), e
            )
            .on("mousemove", "tbody td", # XXX throttling mousemove significantly degrades the experience. _.throttle , 100
                (e) ->
                    # changing the shift key immediately toggles the brushingMode.
                    # releasing shift key pauses the brushing, until mouseout,
                    # and resumes when shift is pressed back
                    unless brushingMode
                        if e.shiftKey
                            brushingMode = on
                            startBrushing $(@), e
                            return
                    else
                        unless e.shiftKey
                            brushingMode = off
                    updateBrushing $(@), e if brushingMode
            )
            .on("mouseout", "tbody td", (e) ->
                endBrushingTimeout = clearTimeout endBrushingTimeout if endBrushingTimeout?
                endBrushingTimeout = setTimeout endBrushing, 100
            )



class ResultsChart extends CompositeElement
    constructor: (@baseElement, @typeSelection, @axesControl, @table, @optionElements = {}) ->
        super @baseElement

        @axisNames = try JSON.parse localStorage["chartAxes"]
        @axesControl
            .on("click", ".axis-add    .axis-var", @actionHandlerForAxisControl @handleAxisAddition)
            .on("click", ".axis-change .axis-var", @actionHandlerForAxisControl @handleAxisChange)
            .on("click", ".axis-change .axis-remove", @actionHandlerForAxisControl @handleAxisRemoval)

        @table.on "changed", @initializeAxes
        @table.on "updated", @display # TODO make ResultsTable emit the event when it's redrawn

        $(window).resize(_.throttle @display, 100)

    persist: =>
        localStorage["chartAxes"] = JSON.stringify @axisNames

    @AXIS_PICK_CONTROL_SKELETON: $("""
        <script type="text/x-jsrender">
          <div data-order="{{>ord}}" class="axis-control axis-change btn-group">
            <a class="btn dropdown-toggle" data-toggle="dropdown"
              href="#"><span class="axis-name">{{>axis.name}}</span>
                  <span class="caret"></span></a>
            <ul class="dropdown-menu" role="menu" aria-labelledby="dLabel">
              {{for variables}}
                <li class="axis-var" data-name="{{>name}}"><a href="#">{{>name}}</a></li>
              {{/for}}
              {{if isOptional}}
              <li class="divider"></li>
              <li class="axis-remove"><a href="#">Remove</a></li>
              {{/if}}
            </ul>
          </div>
        </script>
        """)
    @AXIS_ADD_CONTROL_SKELETON: $("""
        <script type="text/x-jsrender">
          <div class="axis-control axis-add btn-group">
            <a class="btn dropdown-toggle" data-toggle="dropdown"
              href="#"><i class="icon icon-plus"></i> <span class="caret"></span></a>
            <ul class="dropdown-menu" role="menu" aria-labelledby="dLabel">
              {{for variables}}
                <li class="axis-var" data-name="{{>name}}"><a href="#">{{>name}}:{{>type}}</a></li>
              {{/for}}
            </ul>
          </div>
        </script>
        """)

    actionHandlerForAxisControl: (action) => (e) =>
        e.preventDefault()
        $this = $(e.srcElement)
        $axisControl = $this.closest(".axis-control")
        ord = +$axisControl.attr("data-order")
        name = $this.closest(".axis-var").attr("data-name")
        action ord, name, $axisControl, $this, e
    handleAxisChange: (ord, name, $axisControl) =>
        $axisControl.find(".axis-name").text(name)
        @axisNames[ord] = name
        # TODO proceed only when something actually changes
        do @persist
        do @initializeAxes
    handleAxisAddition: (ord, name, $axisControl) =>
        @axisNames.push name
        do @persist
        do @initializeAxes
    handleAxisRemoval: (ord, name, $axisControl) =>
        @axisNames.splice ord, 1
        do @persist
        do @initializeAxes

    @X_AXIS_ORDINAL: 1 # second variable is X
    @Y_AXIS_ORDINAL: 0 # first variable is Y
    initializeAxes: =>
        # initialize @axes from @axisNames
        # collect candidate variables for chart axes from ResultsTable
        axisCandidates =
            # only the expanded input variables or output variables can be charted
            (col for col in @table.columnsRendered when col.isExpanded or col.isMeasured)
        nominalVariables =
            (axisCand for axisCand in axisCandidates when isNominal axisCand.type)
        ratioVariables =
            (axisCand for axisCand in axisCandidates when isRatio axisCand.type)
        # validate the variables chosen for axes
        defaultAxes = [ nominalVariables[0].name, ratioVariables[0].name ]
        if @axisNames?
            # find if all axisNames are valid, don't appear more than once, or make them default
            for name,ord in @axisNames when (@axisNames.indexOf(name) isnt ord or
                    not axisCandidates.some (col) => col.name is name)
                @axisNames[ord] = defaultAxes[ord] ? null
            # discard any null/undefined elements
            @axisNames = @axisNames.filter (name) => name?
        else
            # default axes
            @axisNames = defaultAxes
        # collect ResultsTable columns that corresponds to the @axisNames
        @axes = @axisNames.map (name) => @table.columns[name]
        @varX      = @axes[ResultsChart.X_AXIS_ORDINAL]
        @varsPivot = (ax for ax,ord in @axes when ord isnt ResultsChart.X_AXIS_ORDINAL and isNominal ax.type)
        @varsY     = (ax for ax,ord in @axes when ord isnt ResultsChart.X_AXIS_ORDINAL and isRatio   ax.type)
        # check if there are more than two units for Y-axis, and discard any variables that violates it
        @varsYbyUnit = _.groupBy @varsY, (col) => col.unit
        if (_.size @varsYbyUnit) > 2
            @varsYbyUnit = {}
            for ax,ord in @varsY
                u = ax.unit
                (@varsYbyUnit[u] ?= []).push ax
                # remove Y axis variable if it uses a third unit
                if (_.size @varsYbyUnit) > 2
                    delete @varsYbyUnit[u]
                    @varsY[ord] = null
                    ord2 = @axes.indexOf ax
                    @axes.splice ord2, 1
                    @axisNames.splice ord2, 1
            @varsY = @varsY.filter (v) => v?
        # TODO validation of each axis type with the chart type
        # find out remaining variables
        remainingVariables = (
                if @axisNames.length < 3 or (_.size @varsYbyUnit) < 2
                    axisCandidates
                else # filter variables in a third unit when there're already two axes
                    ax for ax in axisCandidates when isNominal ax.type or @varsYbyUnit[ax.unit]?
            ).filter((col) => col.name not in @axisNames)
        # render the controls
        @axesControl
            .find(".axis-control").remove().end()
            .append(
                for ax,ord in @axes
                    ResultsChart.AXIS_PICK_CONTROL_SKELETON.render({
                        ord: ord
                        axis: ax
                        variables: (if ord is ResultsChart.Y_AXIS_ORDINAL then ratioVariables else axisCandidates)
                                    # the first axis (Y) must always be of ratio type
                            .filter((col) => col not in @axes[0..ord]) # and without the current one
                        isOptional: (ord > 1) # there always has to be at least two axes
                    })
            )
        @axesControl.append(ResultsChart.AXIS_ADD_CONTROL_SKELETON.render(
            variables: remainingVariables
        )) if remainingVariables.length > 0

        do @display

    display: =>
        chartBody = d3.select(@baseElement[0])
        margin = {top: 20, right: 20, bottom: 50, left: 100}
        chartWidth  = window.innerWidth  - @baseElement.position().left * 2
        chartHeight = window.innerHeight - @baseElement.position().top
        @baseElement.css
            width:  "#{chartWidth }px"
            height: "#{chartHeight}px"
        width = chartWidth - margin.left - margin.right
        height = chartHeight - margin.top - margin.bottom

        chartBody.select("svg").remove()
        svg = chartBody.append("svg")
            .attr("width",  chartWidth)
            .attr("height", chartHeight)
          .append("g")
            .attr("transform", "translate(#{margin.left},#{margin.top})")

        xVar = @varX
        yVars = @varsY
        pivotVars = @varsPivot

        # collect column data from table
        dataSeries = []
        $trs = @table.baseElement.find("tbody tr")
        entireRowIndexes = $trs.map((i, tr) -> +tr.dataset.ordinal).get()
        resultsForRendering = @table.resultsForRendering
        dataSeries = _.groupBy entireRowIndexes, (rowIdx) ->
            pivotVars.map((pvVar) -> resultsForRendering[rowIdx][pvVar.index].value).join(", ")
        # See: https://github.com/mbostock/d3/wiki/Ordinal-Scales#wiki-category10
        #TODO @decideColors
        color = d3.scale.category10()

        formatAxisLabel = (name, unit) ->
            unitStr = if unit then "(#{unit})" else ""
            if name?
                "#{name}#{if unitStr then " " else ""}#{unitStr}"
            else
                unitStr

        # X axis
        xAxisLabel = formatAxisLabel xVar.name, xVar.unit
        xData = (rowIdx) -> resultsForRendering[rowIdx][xVar.index].value
        x = d3.scale.ordinal()
            .rangeRoundBands([0, width], .1)
        # TODO see the type for x-axis, and decide
        #x = d3.scale.linear()
        #    .range([0, width])
        #x.domain(d3.extent(dataForCharting, xData))
        x.domain(entireRowIndexes.map(xData))
        xAxis = d3.svg.axis()
            .scale(x)
            .orient("bottom")
        svg.append("g")
            .attr("class", "x axis")
            .attr("transform", "translate(0,#{height})")
            .call(xAxis)
          .append("text")
            .attr("y", -3)
            .attr("x", width)
            .attr("dx", "-.35em")
            .attr("dy", "-.35em")
            .style("text-anchor", "end")
            .text(xAxisLabel)
        log "drawing chart by", xAxisLabel

        # Y axes (single or dual unit)
        ys = {}
        for yVar in yVars
            unit = yVar.unit
            continue if ys[unit]?
            y = ys[unit] =
                d3.scale.linear()
                    .range([height, 0])
            # figure out the extent for this axis
            extent = []
            for v in @varsYbyUnit[unit]
                extent = d3.extent(extent.concat(d3.extent(entireRowIndexes, (rowIdx) ->
                    resultsForRendering[rowIdx][v.index].value)))
            extent = d3.extent(extent.concat([0])) # include origin # TODO make this controllable
            y.domain(extent)
            yAxisLabel = formatAxisLabel (if @varsYbyUnit[unit].length is 1 then yVar.name), unit
            try log "y #{yAxisLabel} =", extent
            # draw axis
            orientation = if _.size(ys) is 1 then "left" else "right"
            yAxis = d3.svg.axis()
                .scale(y)
                .orient(orientation)
            svg.append("g")
                .attr("class", "y axis")
                .attr("transform", if orientation isnt "left" then "translate(#{width},0)")
                .call(yAxis)
              .append("text")
                .attr("transform", "rotate(-90)")
                .attr("y", 3)
                .attr("dy", "#{if orientation is "left" then "" else "-"}.71em")
                .style("text-anchor", "end")
                .text(yAxisLabel)

        log "data for charting", dataSeries

        series = 0

        for yVar in yVars
            y = ys[yVar.unit]
            yAxisLabel = yVar.name
            yData = (rowIdx) -> resultsForRendering[rowIdx][yVar.index].value
            log "drawing chart of", yAxisLabel

            for seriesLabel,dataForCharting of dataSeries

                if yVars.length > 1
                    if seriesLabel
                        seriesLabel = "#{seriesLabel} (#{yAxisLabel})"
                    else
                        seriesLabel = yAxisLabel
                else
                    unless seriesLabel
                        seriesLabel = yAxisLabel
                seriesColor = (d) -> color(series)

                xCoord = (d) -> x(xData(d)) + x.rangeBand()/2
                yCoord = (d) -> y(yData(d))

                svg.selectAll(".dot.series-#{series}")
                    .data(dataForCharting)
                  .enter().append("circle")
                    .attr("class", "dot series-#{series}")
                    .attr("r", 3.5)
                    .attr("cx",    (d) -> x(xData(d)) + x.rangeBand()/2)
                    .attr("cy",    (d) -> y(yData(d)))
                    .style("fill", seriesColor)

                line = d3.svg.line().x(xCoord).y(yCoord)
                svg.append("path")
                    .datum(dataForCharting)
                    .attr("class", "line")
                    .attr("d", line)
                    .style("stroke", seriesColor)
                # legend
                svg.append("text")
                    .datum(dataForCharting[dataForCharting.length-1])
                    .attr("transform", (d) ->
                        "translate(#{xCoord(d)},#{yCoord(d)})")
                    .attr("x", -5).attr("dy", "-.35em")
                    .style("text-anchor", "end")
                    .style("fill", seriesColor)
                    .text((d) -> seriesLabel)

                series++




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
                percentage = (100 * ((+value.done) + (+value.running)) / totalRuns).toFixed(0)
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
        #log "saving plan for later", @plan
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
            popoverParent = rt.baseElement.parent()
            popover = @resultsActionPopover = $("""
                <div class="planner popover fade left">
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
                return if popover.currentTR?.index() is $tr.index()
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
            if rt.baseElement.has(e.srcElement).length is 0
                popover.showDelay = POPOVER_SHOW_DELAY_INITIAL
        )


    @STATE: "REMAINING"
    addPlanFromRowHandler: =>
        add = (strategy) =>
            popover = @resultsActionPopover
            # don't proceed if no condition is expanded
            if popover.numAllRuns is 0
                error "Cannot add anything to plan: no expanded inputs"
                return
            valuesArray = popover.valuesArray
            # check valuesArray to see if we are actually generating some plans
            for values,idx in valuesArray when not values? or values.length is 0
                name = (name of @conditions.conditions)[idx]
                error "Cannot add anything to plan: no values for inputs variable #{name}"
                return
            # add generated combinations to the current plan
            #log "adding #{strategy} plans for", valuesArray
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
            # chart
            ExpKit.chart = new ResultsChart $("#chart-body"),
                $("#chart-type"), $("#chart-axis-controls"), ExpKit.results
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
    do initBaseURLControl
    do initTabs


# vim:undofile
