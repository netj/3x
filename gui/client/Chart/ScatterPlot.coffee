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

class ScatterPlot extends Chart
    constructor: (args...) ->
        super args...
        @type = "Scatter"

    renderXaxis: => ## Setup and draw X axis
        @setXAxisDomain "Scatter"
        axisX = @axes[0]
        xData = @data.accessorFor @data.varX
        x = axisX.scale = @pickScale(axisX).nice()
            .range([0, @width])
        axisX.coord = (d) -> x(xData(d))
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

    specifyTickValuesAndFormat: (axisX) =>
        if axisX.isLogScaleEnabled
            axisX.axis.tickFormat((d, ix) => 
                formatter = d3.format(".3s")
                if ix % 2 == 0 then formatter d else "")
        else
            axisX.axis.tickFormat d3.format(".3s")