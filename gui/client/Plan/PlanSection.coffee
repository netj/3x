$ = require "jquery"

InputsView = require "InputsView"
PlannerUI = require "PlanView"

class PlanSection
    @plannerInputs: new InputsView $("#planner-inputs")
    @planner: new PlannerUI $("#Plan"),
        PlanSection.plannerInputs,
            buttonAddToQueue: $("#planner-add")
