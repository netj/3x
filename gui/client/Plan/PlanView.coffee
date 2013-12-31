define (require) -> (\

$ = require "jquery"
_ = require "underscore"
ko = require "knockout"
require "bootstrap"

_3X_ = require "cs!3x"
{
    log
    error
} =
utils = require "cs!utils"

CompositeElement = require "cs!CompositeElement"
StatusTable = require "cs!RunHistoryView"

RunsSection = require "cs!RunsSection" # FIXME bad dependency

class PlannerUI extends CompositeElement
    constructor: (@baseElement, @inputs, @optionElements = {}) ->
        @inputs.baseElement.find(".menu-checkbox").remove() # TODO add option to remove these checkboxes in MenuDropdown

        # setup data binding for planners
        @inputsSelected = ko.observable null
        @hasSelection = ko.observable null
        updateViewModel = (e) =>
            @inputsSelected (
                for name,input of @inputs.conditions
                    {
                        name
                        selection: @inputs.menuItemsSelected[name] ? input.values
                    }
            )
            @hasSelection (_.values @inputs.menuItemsSelected).some (s) -> s?
        do updateViewModel
        @inputs.on "activeMenuItemsChanged", updateViewModel
        @inputs.on "initialized", updateViewModel

        # full combination
        @fullCombo =
            totalCount: ko.computed =>
                count = 1
                for {name,selection} in @inputsSelected()
                    count *= selection.length
                count
            addToQueue: =>
                @addRunsToQueue StatusTable.PLAN_ADDITION_STRATEGY.all()

        @randomSamplingPercentage = ko.observable (
            (try JSON.parse localStorage.plannerRandomSamplingPercentage) ? 10)
        @randomSamplingPercentage.subscribe (val) =>
            localStorage.plannerRandomSamplingPercentage = JSON.stringify val

        @randomSampling =
            totalCount: ko.computed =>
                Math.round (@fullCombo.totalCount() * @randomSamplingPercentage()/100)
            addToQueue: =>
                @addRunsToQueue StatusTable.PLAN_ADDITION_STRATEGY.random {
                    randomPercent: +@randomSamplingPercentage()
                }

        ko.applyBindings @, @baseElement[0]

        # remember last visible strategy and restore it
        @baseElement.find(".accordion-body#{
                lastActive = localStorage.plannerLastActiveStrategy
                if lastActive then "##{lastActive}" else ":first"
            }").addClass("in")
        @baseElement.find(".accordion-body").on "show", ->
            localStorage.plannerLastActiveStrategy = @id

    resetSelection: (e) =>
        do @inputs.clearSelection

    addRunsToQueue: (runGenerator) =>
        valuesArray = (selection for {selection} in @inputsSelected())
        moreRuns = []
        runGenerator valuesArray, (run) -> moreRuns.push run
        RunsSection.status.addPlan moreRuns # FIXME remove direct dependency, global variable

)
