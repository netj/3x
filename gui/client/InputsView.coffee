$ = require "jquery"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"

MenuDropdown = require "MenuDropdownView"

# TODO rename to InputsView
class ConditionsUI extends MenuDropdown
    constructor: (@baseElement) ->
        super @baseElement, "condition-#{@baseElement.attr("id")}"
        @conditions = {}
        do @load
    load: =>
        $.getJSON("#{_3X_.BASE_URL}/api/inputs")
            .success(@initialize)
    initialize: (@conditions) =>
        do @clearMenu
        for name,{type,values} of @conditions
            # add each condition with menu item for each value
            menuAnchor = @addMenu name, values
            @updateDisplay menuAnchor
            try log "initCondition #{name}:#{type}=#{values.join ","}"
        @trigger "initialized"
