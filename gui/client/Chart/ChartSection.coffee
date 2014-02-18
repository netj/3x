$ = require "jquery"

ChartView = require "ChartView"

ResultsSection = require "ResultsSection" # FIXME get rid of inter-section dependency

class ChartSection
    @chart: new ChartView $("#chart-body"),
        $("#chart-type .chart-types-list"),
        $("#chart-axis-controls"),
        ResultsSection.table,
            toggleInterpolateLines  : $("#chart-toggle-interpolate-lines")
            toggleHideLines         : $("#chart-toggle-hide-lines")
            toggleLogScaleX         : $("#chart-toggle-log-scale-x")
            toggleLogScaleY         : $("#chart-toggle-log-scale-y")
            toggleOriginX           : $("#chart-toggle-origin-x")
            toggleOriginY           : $("#chart-toggle-origin-y")
            alertChartImpossible    : $("#chart-impossible")
            chartOptions            : $("#chart-options")
            chartTitle              : $("#chart-title")
