define (require) -> (\

$ = require "jquery"

StatusTable = require "cs!RunHistoryView"
TargetsUI   = require "cs!TargetsView"
QueuesUI    = require "cs!QueuesView"

ResultsSection = require "cs!ResultsSection" # FIXME get rid of inter-section dependency

class RunsSection
    @status: new StatusTable $("#status-table"),
        ResultsSection.inputs,
            nameDisplay : $("#status-name")
            # TODO status -> HistoryTable and PlanTable
            resultsTable: ResultsSection.table
            actions: $("#status-actions")
            selectionSummary: $("#status-selection-summary")
    @targets: new TargetsUI $("#targets")
    @queues: new QueuesUI $("#queues"),
        RunsSection.status,
        RunsSection.targets,
            addNewQueue: $("#queue-create")
            sortByName: $("#queue-sortby-name")
            sortByTime: $("#queue-sortby-time")
            toggleAbsoluteProgress: $("#queue-toggle-absolute-progress")
            activeCountDisplay: $("#active-count.label")
            remainingCountDisplay: $("#remaining-count.label")

)
