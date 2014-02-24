$ = require "jquery"
_ = require "underscore"
d3 = require "d3"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"
Chart = require "Chart"

class LineChart extends Chart
    constructor: (args...) ->
        super args...
        @type = "Line"

    renderXaxis: => ## Setup and draw X axis
        @setXAxisDomain "Line"
        axisX = @axes[0]
        xData = @data.accessorFor @data.varX
        x = axisX.scale = d3.scale.ordinal()
            .domain(axisX.domain)
            .rangeRoundBands([0, @width], .1)
        axisX.coord = (d) -> x(xData(d)) + x.rangeBand() / 2
        super

    renderDataShapes: (series, seriesLabel, seriesDataIds, seriesColor, yCoord, yVar, xMap) =>
        axisX = @axes[0]
        xCoord = axisX.coord
        @svg.selectAll(".dot.series-#{series}")
            .data(seriesDataIds)
          .enter().append("circle")
            .attr("class", "dot series-#{series}")
            .attr("r", 5)
            .attr("cx", xCoord)
            .attr("cy", yCoord)
            .style("fill", seriesColor)
            # popover
            .attr("title",        seriesLabel)
            .attr("data-content", @formatDataPoint yVar)
            .attr("data-placement", (d) =>
                if xCoord(d) < @width/2 then "right" else "left"
            )

        unless @chartOptions.hideLines
            line = d3.svg.line().x(xCoord).y(yCoord)
            line.interpolate("basis") if @chartOptions.interpolateLines
            @svg.append("path")
                .datum(seriesDataIds)
                .attr("class", "line")
                .attr("d", line)
                .style("stroke", seriesColor)

    specifyTickValuesAndFormat: (axisX) =>
        x = axisX.scale
        skipEvery = Math.ceil(x.domain().length / (@width / 55)) # allow 55 pixels per axis label
        return axisX.axis.tickValues(x.domain().filter((d, ix) => !(ix % skipEvery)))