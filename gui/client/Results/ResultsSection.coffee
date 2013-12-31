define (require) -> (\

$ = require "jquery"

InputsView  = require "cs!InputsView"
OutputsView = require "cs!OutputsView"
TableView   = require "cs!TableView"

class ResultsSection
    @inputs  : new InputsView  $("#conditions")
    @outputs : new OutputsView $("#measurements")
    @table   : new TableView   $("#results-table"),
        ResultsSection.inputs, ResultsSection.outputs,
            toggleIncludeEmpty          : $("#results-include-empty")
            toggleShowHiddenConditions  : $("#results-show-hidden-conditions")
            buttonResetColumnOrder      : $("#results-reset-column-order")
            containerForStateDisplay    : $("#results")
            buttonRefresh               : $("#results-refresh")
            buttonExport                : $("#results-export")

)
