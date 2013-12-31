define (require) -> (\

$ = require "jquery"

InputsView = require "cs!InputsView"
PlannerUI = require "cs!PlanView"

class PlanSection
    @plannerInputs: new InputsView $("#planner-inputs")
    @planner: new PlannerUI $("#Plan"),
        PlanSection.plannerInputs,
            buttonAddToQueue: $("#planner-add")

)
