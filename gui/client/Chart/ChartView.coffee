$ = require "jquery"
_ = require "underscore"
d3 = require "d3"
require "jsrender"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"

CompositeElement = require "CompositeElement"

ChartData = require "ChartData"
Chart = require "Chart"
BarChart = require "BarChart"
ScatterPlot = require "ScatterPlot"
LineChart = require "LineChart"

class ChartView extends CompositeElement
    constructor: (@baseElement, @typeSelection, @axesControl, @table, @optionElements = {}) ->
        super @baseElement

        # use local storage to remember previous axes
        @axisNames = try JSON.parse localStorage["chartAxes"]
        @chartType = try JSON.parse localStorage["chartType"]

        # axis-change are the currently used axis pickers; axis-add is the 1 that lets you add more (and has a ...)
        @axesControl
            .on("click", ".axis-add    .axis-var", @actionHandlerForAxisControl @handleAxisAddition)
            .on("click", ".axis-change .axis-var", @actionHandlerForAxisControl @handleAxisChange)
            .on("click", ".axis-change .axis-remove", @actionHandlerForAxisControl @handleAxisRemoval)

        @typeSelection
            .on("click", ".chart-type-li", @actionHandlerForChartTypeControl @handleChartTypeChange)

        @table.on "changed", @initializeAxes
        @table.on "updated", @display

        # if user resizes window, call display at most once every 100 ms
        $(window).resize(_.throttle @display, 100)

        # hide all popover when not clicked on one
        $('html').on("click", (e) =>
            if $(e.target).closest(".dot, .popover").length == 0
                @baseElement.find(".dot").popover("hide")
            if $(e.target).closest(".databar, .popover").length == 0
                @baseElement.find(".databar").popover("hide")
        )
        # enable nested popover on-demand
        @baseElement.on("click", ".popover [data-toggle='popover']", (e) =>
            $(e.target).closest("[data-toggle='popover']").popover("show")
        )

        # vocabularies for option persistence
        @chartOptions = (try JSON.parse localStorage["chartOptions"]) ? {}
        persistOptions = => localStorage["chartOptions"] = JSON.stringify @chartOptions
        optionToggleHandler = (e) =>
            btn = $(e.target).closest(".btn")
            return e.preventDefault() if btn.hasClass("disabled")
            chartOption = btn.attr("data-toggle-option")
            @chartOptions[chartOption] = not btn.hasClass("active")
            do persistOptions
            do @display
        # vocabs for installing toggle handler to buttons
        installToggleHandler = (chartOption, btn) =>
            return btn
               ?.toggleClass("active", @chartOptions[chartOption] ? false)
                .attr("data-toggle-option", chartOption)
                .click(optionToggleHandler)
        # vocabularies for axis options
        forEachAxisOptionElement = (prefix, chartOptionPrefix, job) =>
            for axisName in @constructor.AXIS_NAMES
                optionKey = chartOptionPrefix + axisName
                job optionKey, @optionElements["#{prefix}#{axisName}"], axisName

        installToggleHandler "interpolateLines", @optionElements.toggleInterpolateLines
        installToggleHandler "hideLines",        @optionElements.toggleHideLines
        # log scale
        @optionElements.toggleLogScale =
            $(forEachAxisOptionElement "toggleLogScale", "logScale", installToggleHandler)
                .toggleClass("disabled", true)
        # origin
        @optionElements.toggleOrigin =
            $(forEachAxisOptionElement "toggleOrigin", "origin", installToggleHandler)
                .toggleClass("disabled", true)

    @AXIS_NAMES: "X Y".trim().split(/\s+/)

    persist: =>
        localStorage["chartAxes"] = JSON.stringify @axisNames
        localStorage["chartType"] = JSON.stringify @chartType

    # axis change dropdown HTML skeleton
    @AXIS_PICK_CONTROL_SKELETON: $("""
        <script type="text/x-jsrender">
          <div data-order="{{>ord}}" class="axis-control axis-change btn-group">
            <a class="btn btn-small dropdown-toggle" data-toggle="dropdown"
              href="#"><span class="axis-name">{{>axis.name}}</span>
                  <span class="caret"></span></a>
            <ul class="dropdown-menu" role="menu" aria-labelledby="dLabel">
              {{for variables}}
                <li class="axis-var" data-name="{{>name}}"><a href="#"><i
                    class="icon icon-{{if isMeasured}}dashboard{{else}}tasks{{/if}}"></i>
                        {{>name}}</a></li>
              {{/for}}
              {{if isOptional}}
                {{if variables.length > 0}}<li class="divider"></li>{{/if}}
                <li class="axis-remove"><a href="#"><i class="icon icon-remove"></i> Remove</a></li>
              {{/if}}
            </ul>
          </div>
        </script>
        """)

    # axis add dropdown HTML skeleton
    @AXIS_ADD_CONTROL_SKELETON: $("""
        <script type="text/x-jsrender">
          <div class="axis-control axis-add btn-group">
            <a class="btn btn-small dropdown-toggle" data-toggle="dropdown"
              href="#">… <span class="caret"></span></a>
            <ul class="dropdown-menu" role="menu" aria-labelledby="dLabel">
              {{for variables}}
                <li class="axis-var" data-name="{{>name}}"><a href="#"><i
                    class="icon icon-{{if isMeasured}}dashboard{{else}}tasks{{/if}}"></i>
                    {{>name}}</a></li>
              {{/for}}
            </ul>
          </div>
        </script>
        """)

    @CHART_PICK_CONTROL_SKELETON: $("""
        <script type="text/x-jsrender">
            {{for names}}
                <li class="chart-type-li"><a href="#"><i class="icon icon-signal"></i> {{>#data}}</a></li>
            {{/for}}
        </script>
        """)

    actionHandlerForChartTypeControl: (action) => (e) =>
        e.preventDefault()
        $this = $(e.target)
        $axisControl = $this.closest("#chart-type")
        name = $this.closest("a").text()
        action name, $axisControl, $this, e

    handleChartTypeChange: (name, $axisControl) =>
        $axisControl.find(".chart-name").text(name)
        @chartType = name.trim()
        @chartOptions.justChanged = "chartType"
        do @persist
        do @initializeAxes

    actionHandlerForAxisControl: (action) => (e) =>
        e.preventDefault()
        $this = $(e.target)
        $axisControl = $this.closest(".axis-control")
        ord = +$axisControl.attr("data-order")
        name = $this.closest(".axis-var").attr("data-name")
        action ord, name, $axisControl, $this, e
    handleAxisChange: (ord, name, $axisControl) =>
        $axisControl.find(".axis-name").text(name)
        @axisNames[ord] = name
        if ord == 1 then @chartOptions.justChanged = "axis"
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
    
    # initialize @axes from @axisNames (which is saved in local storage)
    initializeAxes: => 
        if @table.deferredDisplay?
            do @table.render # XXX charting heavily depends on the rendered table, so force rendering
        return unless @table.columnsRendered?.length
        # collect candidate variables for chart axes from ResultsTable
        axisCandidates =
            # only the expanded input variables (usually a condition) or output variables (usually measurement) can be charted
            # below logic will add to the axis candidates any expanded input variable or any rendered measured output variable
            # columns are not rendered if they are unchecked in the left-hand panel
            (col for col in @table.columnsRendered when col.isExpanded or col.isMeasured)
        axisCandidates[ord].unit = null for ax,ord in axisCandidates when not ax.unit? or not ax.unit.length? or ax.unit.length is 0
        nominalVariables =
            (axisCand for axisCand in axisCandidates when utils.isNominal axisCand.type)
        ratioVariables =
            (axisCand for axisCand in axisCandidates when utils.isRatio axisCand.type)
        # check if there are enough variables to construct a two-dimensional chart: if so, add toggle buttons on RHS, if not, show a message
        canDrawChart = (possible) =>
            @baseElement.add(@optionElements.chartOptions).toggleClass("hide", not possible)
            @optionElements.alertChartImpossible?.toggleClass("hide", possible)
        # we need at least 1 ratio variable and 2 variables total
        if ratioVariables.length >= 1 and nominalVariables.length + ratioVariables.length >= 2
            canDrawChart yes
        else
            canDrawChart no
            return
        # validate the variables chosen for axes
        defaultAxes = []
        defaultAxes[@constructor.X_AXIS_ORDINAL] = nominalVariables[0]?.name ? ratioVariables[1]?.name
        defaultAxes[@constructor.Y_AXIS_ORDINAL] = ratioVariables[0]?.name
        if @axisNames?
            # find if all axisNames are valid, don't appear more than once, or make them default
            for name,ord in @axisNames when (@axisNames.indexOf(name) isnt ord or not axisCandidates.some (col) => col.name is name)
                @axisNames[ord] = defaultAxes[ord] ? null
            # discard any null/undefined elements
            @axisNames = @axisNames.filter (name) => name?
        else
            # default axes when axisNames are not in local storage
            @axisNames = defaultAxes
        # collect ResultsTable columns that corresponds to the @axisNames
        @vars = @axisNames.map (name) => @table.columns[name]
        # standardize no-units so that "undefined", "null", and an empty string all have null unit
        # TODO: don't set units to null in 2 different places
        @vars[ord].unit = null for ax,ord in @vars when not ax.unit? or not ax.unit.length? or ax.unit.length is 0
        @varX      = @vars[@constructor.X_AXIS_ORDINAL]
        # pivot variables in an array if there are additional nominal variables
        @varsPivot = (ax for ax,ord in @vars when ord isnt @constructor.X_AXIS_ORDINAL and utils.isNominal ax.type)
        # y-axis variables in an array
        # TODO: there should only be 1 y-axis variable for now
        @varsY     = (ax for ax,ord in @vars when ord isnt @constructor.X_AXIS_ORDINAL and utils.isRatio   ax.type)
        # establish which chart type we're using
        chartTypes = "Line Bar".trim().split(/\s+/)
        noSpecifiedChartType = not @chartType?
        # specify which chart types are allowed
        if utils.isRatio @varX.type
            chartTypes.push "Scatter"
            # Keep it a scatterplot
            @chartType = "Scatter" if noSpecifiedChartType or @chartOptions.justChanged is "axis"
        else
            @chartType = "Bar" if @chartType != "Line"
            # when local storage does not specify origin toggle value, or
            # if just changed chart types, then insist first view of bar chart is grounded at 0
            # and make sure that button is toggled down
            if @chartOptions.justChanged is "chartType" or (@chartType == "Bar" and noSpecifiedChartType)
                @chartOptions["originY"] = true
                @optionElements.toggleOriginY.toggleClass("active", true)
        @chartOptions.justChanged = ""
        
        $axisControl = @typeSelection.closest("#chart-type")
        $axisControl.find(".chart-name").text(" " + @chartType)

        # clear title
        @optionElements.chartTitle?.text("")
        # TODO: this won't be necessary for now...
        # check if there is more than 1 unit for Y-axis, and discard any variables that violates it
        @varsYbyUnit = _.groupBy @varsY, (col) => col.unit
        if (_.size @varsYbyUnit) > 1
            @varsYbyUnit = {}
            for ax,ord in @varsY
                u = ax.unit
                (@varsYbyUnit[u] ?= []).push ax
                # remove Y axis variable if it uses a second unit
                if (_.size @varsYbyUnit) > 1
                    delete @varsYbyUnit[u]
                    @varsY[ord] = null
                    ord2 = @vars.indexOf ax
                    @vars.splice ord2, 1
                    @axisNames.splice ord2, 1
            @varsY = @varsY.filter (v) => v?
        # TODO validation of each axis type with the chart type
        # find out remaining variables: all the axis candidates that haven't been used as in @axisNames yet
        remainingVariables = (
                # if @axisNames.length < 3 or (_.size @varsYbyUnit) < 2
                if @axisNames.length < 2
                    axisCandidates
                else # filter variables in a third unit when there're already two axes
                    ax for ax in axisCandidates when @varsYbyUnit[ax.unit]? or utils.isNominal ax.type
            ).filter((col) => col.name not in @axisNames)
        # render the controls
        @axesControl
            .find(".axis-control").remove().end()
            .append(
                for ax,ord in @vars
                    @constructor.AXIS_PICK_CONTROL_SKELETON.render({
                        ord: ord
                        axis: ax
                        variables: (if ord == @constructor.Y_AXIS_ORDINAL then ratioVariables else if ord == @constructor.X_AXIS_ORDINAL then axisCandidates else remainingVariables)
                                    # the first axis (Y) must always be of ratio type
                            .filter((col) => col not in @vars[0..ord]) # and without the current one
                        isOptional: (ord > 1) # there always has to be at least two axes
                    })
            )
        @axesControl.append(@constructor.AXIS_ADD_CONTROL_SKELETON.render(
            variables: remainingVariables
        )) if remainingVariables.length > 0

        @typeSelection
            .find("li.chart-type-li").remove().end()
            .append(@constructor.CHART_PICK_CONTROL_SKELETON.render(
                names: chartTypes
            ))

        do @display

    render: =>
        # create a visualizable data from the table data and current axes/series configuration
        @chartData = new ChartData @table, @varX, @varsY, @varsPivot

        do @renderTitle

        chartClass =
            # decide the actual Chart class here
            switch @chartType
                when "Scatter"
                    ScatterPlot
                when "Bar"
                    BarChart
                when "Line"
                    LineChart
                else
                    throw new Error "#{@chartType}: unknown chart type"

        # create and render the chart
        # TODO reuse the created chart?
        @chart = new chartClass @baseElement, @chartData, @chartOptions,
            @optionElements # TODO don't pass optionElements, but listen to change events from @chartOptions
        do @chart.render


    renderTitle: =>
        # set up title
        @optionElements.chartTitle?.html(
            # TODO move this code to a model class, e.g., ResultsQuery
            """
            <strong>#{@varsY[0]?.name}</strong>
            by <strong>#{@varX.name}</strong> #{
                if @varsPivot.length > 0
                    "for each #{
                        ("<strong>#{name}</strong>" for {name} in @varsPivot
                        ).join ", "}"
                else ""
            } #{
                # XXX remove these hacks into ResultsSection, InputsView, OutputsView
                {inputs,outputs} = _3X_.ResultsSection
                filters = (
                    for name,values of inputs.menuItemsSelected when values?.length > 0
                        "<strong>#{name}=#{values.join(",")}</strong>"
                ).concat(
                    for name,filter of outputs.menuFilter when filter?
                        "<strong>#{name}#{outputs.constructor.serializeFilter filter}</strong>"
                )
                if filters.length > 0
                    "<br>(#{filters.join(" and ")})"
                else ""
            }
            """
        )

