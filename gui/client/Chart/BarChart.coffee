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

class BarChart extends Chart
    constructor: (args...) ->
        super args...
        @type = "Bar"

    renderXaxis: => ## Setup and draw X axis
        @setXAxisDomain "Bar"
        axisX = @axes[0]
        xData = @data.accessorFor @data.varX
        x = axisX.scale = d3.scale.ordinal()
            .domain(axisX.domain)
            .rangeRoundBands([0, @width], .5)
        axisX.coord = (d) -> x(xData(d)) # d is really the index; xData grabs the value for that index
        axisX.barWidth = x.rangeBand() / @data.varsY.length / Object.keys(@data.idsBySeries).length
        super

    renderDataShapes: (series, seriesLabel, seriesDataIds, seriesColor, yCoord, yVar, xMap) =>
        axisX = @axes[0]
        xCoord = axisX.coord
        @svg.selectAll(".databar.series-#{series}")
            .data(seriesDataIds)
          .enter().append("rect")
            .attr("class", "databar series-#{series}")
            .attr("width", (d, ix) => axisX.barWidth / xMap[xCoord(d)].count)
            .attr("x", (d, ix) => 
                xVal = xCoord(d)
                xIndex = xMap[xVal].index
                xMap[xVal].index++
                xVal + (series * axisX.barWidth) + axisX.barWidth * xIndex / xMap[xVal].count)
            .attr("y", (d) => yCoord(d))
            .attr("height", (d) => @height - yCoord(d))
            .style("fill", seriesColor)
            # popover
            .attr("title",        seriesLabel)
            .attr("data-content", @formatDataPoint yVar)
            .attr("data-placement", (d) =>
                if xCoord(d) < @width/2 then "right" else "left"
            )

    specifyTickValuesAndFormat: (axisX) =>
        x = axisX.scale
        skipEvery = Math.ceil(x.domain().length / (@width / 55)) # allow 55 pixels per axis label
        return axisX.axis.tickValues(x.domain().filter((d, ix) => !(ix % skipEvery)))