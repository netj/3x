define (require) -> (\

$ = require "jquery"

ChartView = require "ChartView"

ResultsSection = require "ResultsSection" # FIXME get rid of inter-section dependency

class ChartSection
    @chart: new ChartView $("#chart-body"),
        $("#chart-type"),
        $("#chart-axis-controls"),
        ResultsSection.table,
            toggleInterpolateLines  : $("#chart-toggle-interpolate-lines")
            toggleHideLines         : $("#chart-toggle-hide-lines")
            toggleLogScaleX         : $("#chart-toggle-log-scale-x")
            toggleLogScaleY1        : $("#chart-toggle-log-scale-y1")
            toggleLogScaleY2        : $("#chart-toggle-log-scale-y2")
            toggleOriginX           : $("#chart-toggle-origin-x")
            toggleOriginY1          : $("#chart-toggle-origin-y1")
            toggleOriginY2          : $("#chart-toggle-origin-y2")
            alertChartImpossible    : $("#chart-impossible")
            chartOptions            : $("#chart-options")

)
