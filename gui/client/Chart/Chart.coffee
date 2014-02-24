$ = require "jquery"
_ = require "underscore"
d3 = require "d3"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"

class Chart
    constructor: (@baseElement, @data, @chartOptions,  @optionElements) ->
        @type = null # TODO REFACTORING instead of branching off with @type, override with subclasses

    render: =>
        do @setupAxes
        do @createSVG
        do @renderXaxis
        do @renderYaxis
        do @renderData
        do @updateOptionsFromData

    setupAxes: => ## Setup Axes
        @axes = []
        # X axis
        @axes.push axisX =
            name: "X"
            unit: @data.varX.unit
            vars: [@data.varX]
        # Y axis: analyze the extent of Y axes data
        vY = @data.varsY[0]
        @axes.push axisY =
            name: "Y"
            unit: vY.unit
            vars: @data.varsY
            isRatio: utils.isRatio vY
        # figure out the extent for the Y axis
        extent = []
        for col in @data.varsY
            extent = d3.extent(extent.concat(d3.extent(@data.ids, (@data.accessorFor col))))
        axisY.domain = extent
    
    @SVG_STYLE_SHEET: """
        <style>
          .axis path,
          .axis line {
            fill: none;
            stroke: #000;
            shape-rendering: crispEdges;
          }

          .dot, .databar {
            opacity: 0.75;
            cursor: pointer;
          }

          .line {
            fill: none;
            stroke-width: 1.5px;
          }
        </style>
        """
    createSVG: => ## Determine the chart dimension and initialize the SVG root as @svg
            chartBody = d3.select(@baseElement[0])
            @baseElement.find("style").remove().end().append(@constructor.SVG_STYLE_SHEET)
            chartWidth  = window.innerWidth  - @baseElement.position().left * 2
            chartHeight = window.innerHeight - @baseElement.position().top - 20
            @baseElement.css
                width:  "#{chartWidth }px"
                height: "#{chartHeight}px"
            @margin =
                top: 20, bottom: 50
                right: 40, left: 40
            # adjust margins while we prepare the Y scales
            for axisY,i in @axes[1..]
                y = axisY.scale = @pickScale(axisY).nice()
                axisY.axis = d3.svg.axis()
                    .scale(axisY.scale)
                if axisY.isLogScaleEnabled
                    axisY.axis = axisY.axis.tickFormat((d, ix) => 
                        formatter = d3.format(".3s")
                        if ix % 2 == 0 then formatter d else "")
                else
                    axisY.axis = axisY.axis.tickFormat d3.format(".3s")
                numDigits = Math.max _.pluck(y.ticks(axisY.axis.ticks()).map(y.tickFormat()), "length")...
                tickWidth = Math.ceil(numDigits * 6.5) #px per digit
                if i == 0
                    @margin.left += tickWidth
                else
                    @margin.right += tickWidth
            @width  = chartWidth  - @margin.left - @margin.right
            @height = chartHeight - @margin.top  - @margin.bottom
            chartBody.select("svg").remove()
            @svg = chartBody.append("svg")
                .attr("width",  chartWidth)
                .attr("height", chartHeight)
              .append("g")
                .attr("transform", "translate(#{@margin.left},#{@margin.top})")

    setXAxisDomain: (supposedType) =>
        axisX = @axes[0]
        if @type isnt supposedType
            error "Unsupported variable type for X axis", axisX.column
        axisX.domain = @data.ids.map(@data.accessorFor @data.varX)

    renderXaxis: => ## Setup and draw X axis
        axisX = @axes[0]
        axisX.label = @formatAxisLabel axisX
        axisX.axis = d3.svg.axis()
            .scale(axisX.scale)
            .orient("bottom")
            .ticks(@width / 100) # allow 100 pixels per tick
        axisX.axis = @specifyTickValuesAndFormat axisX
        @svg.append("g")
            .attr("class", "x axis")
            .attr("transform", "translate(0,#{@height})")
            .call(axisX.axis)
          .append("text")
            .attr("x", @width/2)
            .attr("dy", "3em")
            .style("text-anchor", "middle")
            .text(axisX.label)

    renderYaxis: => ## Setup and draw Y axis
        @axisByUnit = {}
        for axisY,i in @axes[1..]
            y = axisY.scale
                .range([@height, 0])
            axisY.label = @formatAxisLabel axisY
            # draw axis
            orientation = if i == 0 then "left" else "right"
            axisY.axis.orient(orientation)
            @svg.append("g")
                .attr("class", "y axis")
                .attr("transform", if orientation isnt "left" then "translate(#{@width},0)")
                .call(axisY.axis)
              .append("text")
                .attr("transform", "translate(#{
                        if orientation is "left" then -@margin.left else @margin.right
                    },#{@height/2}), rotate(-90)")
                .attr("dy", if orientation is "left" then "1em" else "-.3em")
                .style("text-anchor", "middle")
                .text(axisY.label)
            @axisByUnit[axisY.unit] = axisY

    renderData: =>
        # See: https://github.com/mbostock/d3/wiki/Ordinal-Scales#wiki-category10
        #TODO @decideColors
        color = d3.scale.category10()

        ## Finally, draw each varY and series
        series = 0
        axisX = @axes[0]
        xCoord = axisX.coord
        for yVar in @data.varsY
            axisY = @axisByUnit[yVar.unit]
            yData = @data.accessorFor yVar
            yCoord = (d) -> axisY.scale(yData(d))

            for seriesLabel,seriesDataIds of @data.idsBySeries
                seriesColor = (d) -> color(series)

                # Splits bars if same x-value within a series; that's why it maintains a count and index
                xMap = {}
                for d in seriesDataIds
                    xVal = xCoord(d)
                    if xMap[xVal]?
                        xMap[xVal].count++
                    else
                        xMap[xVal] =
                            count: 1
                            index: 0

                @renderDataShapes series, seriesLabel, seriesDataIds, seriesColor, yCoord, yVar, xMap

                if _.size(@data.varsY) > 1
                    if seriesLabel
                        seriesLabel = "#{seriesLabel} (#{yVar.name})"
                    else
                        seriesLabel = yVar.name
                else
                    unless seriesLabel
                        seriesLabel = yVar.name
                if _.size(@data.varsY) == 1 and _.size(@data.idsBySeries) == 1
                    seriesLabel = null

                # legend
                if seriesLabel?
                    i = seriesDataIds.length - 1
                    #i = Math.round(Math.random() * i) # TODO find a better way to place labels
                    d = seriesDataIds[i]
                    x = xCoord(d)
                    leftHandSide = x < @width/2
                    inTheMiddle = false # @width/4 < x < @width*3/4
                    @svg.append("text")
                        .datum(d)
                        .attr("transform", "translate(#{xCoord(d)},#{yCoord(d)})")
                        .attr("x", if leftHandSide then 5 else -5).attr("dy", "-.5em")
                        .style("text-anchor", if inTheMiddle then "middle" else if leftHandSide then "start" else "end")
                        .style("fill", seriesColor)
                        .text(seriesLabel)

                series++

        # popover
        @baseElement.find(".dot, .databar").popover(
            trigger: "click"
            html: true
            container: @baseElement
        )

    updateOptionsFromData: =>
        # TODO REFACTORING change the following code to modify ChartOptions
        # TODO REFACTORING let ChartView listen to ChartOptions' change events and update @optionElements instead
        ## update optional UI elements
        @optionElements.toggleLogScale.toggleClass("disabled", true)
        for axis in @axes
            @optionElements["toggleLogScale#{axis.name}"]
               ?.toggleClass("disabled", not axis.isLogScalePossible)

        @optionElements.toggleOrigin.toggleClass("disabled", true)
        @optionElements["toggleOriginY"]?.toggleClass("disabled", utils.intervalContains axis.domain, 0)
        if @type is "Scatter"
            @optionElements["toggleOriginX"]?.toggleClass("disabled", utils.intervalContains axis.domain, 0)

        isLineChartDisabled = @type isnt "Line" # TODO REFACTORING use: @ instanceof LineChart
        $(@optionElements.toggleHideLines)
           ?.toggleClass("disabled", isLineChartDisabled)
            .toggleClass("hide", isLineChartDisabled)
        $(@optionElements.toggleInterpolateLines)
           ?.toggleClass("disabled", isLineChartDisabled or @chartOptions.hideLines)
            .toggleClass("hide", isLineChartDisabled or @chartOptions.hideLines)



    pickScale: (axis) =>
        dom = d3.extent(axis.domain)
        # here is where you ground at 0 if origin selected - by adding it to the extent
        dom = d3.extent(dom.concat([0])) if @chartOptions["origin#{axis.name}"]
        # if the extent min and max are the same, extend each by 1
        if dom[0] == dom[1] or Math.abs (dom[0] - dom[1]) == Number.MIN_VALUE
            dom[0] -= 1
            dom[1] += 1
        axis.isLogScalePossible = not utils.intervalContains dom, 0
        axis.isLogScaleEnabled = @chartOptions["logScale#{axis.name}"]
        if axis.isLogScaleEnabled and not axis.isLogScalePossible
            error "log scale does not work for domains including zero", axis, dom
            axis.isLogScaleEnabled = no
        (
            if axis.isLogScaleEnabled then d3.scale.log()
            else d3.scale.linear()
        ).domain(dom)


    formatAxisLabel: (axis) ->
        unit = axis.unit
        unitStr = if unit then "(#{unit})" else ""
        if axis.vars?.length == 1
            "#{axis.vars[0].name}#{if unitStr then " " else ""}#{unitStr}"
        else
            unitStr

    formatDataPoint: (varY) =>
        vars = @data.relatedVarsFor(varY)
        varAccessors = ([v, (@data.accessorFor v)] for v in vars)
        provenanceFor = @data.provenanceAccessorFor(vars)
        (d) ->
            provenance = provenanceFor(d)
            return "" unless provenance?
            """<table class="table table-condensed">""" + [
                (for [v,vAccessor] in varAccessors
                    val = vAccessor(d)
                    {
                        name: v.name
                        value: """<span class="value" title="#{val}">#{val}</span>#{
                            unless v.unit then ""
                            else "<small class='unit'> (#{v.unit})<small>"}"""
                    }
                )...
                {
                    name: "run#.count"
                    value: """<span class="run-details"
                        data-toggle="popover" data-html="true"
                        title="#{provenance?.length} runs" data-content="
                        <small><ol class='chart-run-details'>#{
                            provenance.map((row) ->
                                # TODO show more variables
                                yValue = row[varY.name]
                                runId = row[_3X_.RUN_COLUMN_NAME]
                                "<li><a href='#{runId}/overview'
                                    target='run-details' title='#{runId}'>#{
                                    # show value of varY for this particular run
                                    row[varY.name]
                                }</a></li>"
                            ).join("")
                        }</ol></small>"><span class="value">#{provenance.length
                            }</span><small class="unit"> (runs)</small></span>"""
                }
                # TODO links to runIds
            ].map((row) -> "<tr><td>#{row.name}</td><th>#{row.value}</th></tr>")
             .join("") + """</table>"""