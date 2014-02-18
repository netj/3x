$ = require "jquery"

InputsView  = require "InputsView"
OutputsView = require "OutputsView"
TableView   = require "TableView"

class ResultsSection
    @inputs  : new InputsView  $("#conditions")
    @outputs : new OutputsView $("#measurements")
    @table   : new TableView   $("#results-table"),
        ResultsSection.inputs, ResultsSection.outputs,
            toggleIncludeEmpty          : $("#results-include-empty")
            toggleShowHiddenConditions  : $("#results-show-hidden-conditions")
            buttonResetColumnOrder      : $("#results-reset-column-order")
            containerForStateDisplay    : $("#Results")
            buttonRefresh               : $("#results-refresh")
            buttonExport                : $("#results-export")
