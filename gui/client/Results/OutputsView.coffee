define (require) -> (\

$ = require "jquery"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"

Aggregation = require "Aggregation"
MenuDropdown = require "MenuDropdownView"

# TODO encapsulate these in class
FILTER_EXPR_REGEX = ///
        ^ \s*
    ( <= | >= | <> | != | = | < | > )    # comparison, membership, ...
        \s*
    ( (|[+-]) ( \d+(\.\d*)? | \.\d+ )
              ([eE] (|[+-])\d+)?         # number
    | [^<>=!]?.*                         # or string
    )
        \s* $
///
parseFilterExpr1 = (expr) ->
    [m[1], m[2]] if m = FILTER_EXPR_REGEX.exec expr.trim()
parseFilterExpr = (compoundExpr) ->
    parsed = [] # XXX CoffeeScript 1.4.0 doesnt treat "for" as expr when there's a return in its body
    for expr in compoundExpr?.split "&"
        if (parsed1 = parseFilterExpr1 expr)?
            parsed.push parsed1
        else
            return null
    parsed
serializeFilter = (parsedFilter) ->
    if _.isArray parsedFilter
        ("#{rel}#{literal}" for [rel, literal] in parsedFilter
        ).join " & "
    else
        parsedFilter


# TODO rename to OutputsView
class MeasurementsUI extends MenuDropdown
    constructor: (@baseElement) ->
        super @baseElement, "measurement-#{@baseElement.attr("id")}"
        @menuLabelItemsPrefix  = " ["
        @menuLabelItemsPostfix = "]"
        @measurements = {}

        # initialize menu filter
        @lastMenuFilter = (localStorage["menuDropdownFilter_#{@menuName}"] ?= "{}")
        @menuFilter = try JSON.parse @lastMenuFilter

        do @load
    persist: =>
        super()
        localStorage["menuDropdownFilter_#{@menuName}"] = JSON.stringify @menuFilter

    # XXX create class Filter instead of exposing through OutputsView
    @serializeFilter: serializeFilter

    load: =>
        $.getJSON("#{_3X_.BASE_URL}/api/outputs")
            .success(@initialize)
    initialize: (@measurements) =>
        do @clearMenu
        for name,{type} of @measurements
            aggregations = Aggregation.FOR_TYPE[type]
            # add each measurement with menu item for each aggregation
            menuAnchor = @addMenu name, (aggName for aggName of aggregations)

            # add input elements for filter
            menuAnchor
                .find(".menu-label-items").before("""<span class="menu-label-filter"></span>""").end()
                .find(".dropdown-menu li").first().before("""
                    <li><div class="filter control-group input-prepend">
                        <span class="add-on"><i class="icon icon-filter"></i></span>
                        <input type="text" class="input-medium" placeholder="e.g., >0 & <=12.3, !=''">
                    </div></li>
                    <li class="divider"></li>
                    """)
            menuAnchor.find(".filter")
                .find("input")
                    .val(serializeFilter(@menuFilter[name]))
                    .change(@menuItemActionHandler ($this, menuAnchor) ->
                        # ...
                    )
                    .end()
                .click(@menuItemActionHandler ($this, menuAnchor) ->
                    throw new Error "don't updateDisplay"
                )
            menu = menuAnchor.find(".dropdown-menu")
            menu.selectable("option", "cancel", ".filter, #{
                menu.selectable("option", "cancel")}")

            @updateDisplay menuAnchor
            try log "initMeasurement #{name}:#{type}.#{(_.keys aggregations).join ","}"
        @trigger "initialized"

    # display current filter for a menu
    updateDisplay: (menuAnchor) =>
        # At least one menu item (aggregation) must be active all the time.
        # To totally hide this measure, user can simply check off.
        if menuAnchor.find(".menu-dropdown-item.ui-selected").length == 0
            menuAnchor.find(".menu-dropdown-item:nth(0)").addClass("ui-selected")

        # then do what it's supposed to
        super menuAnchor

        # display for filter
        name = menuAnchor.find(".menu-label")?.text()
        menuFilterInput = menuAnchor.find(".filter input")
        rawFilterExpr = menuFilterInput.val()
        if rawFilterExpr?.length > 0
            filterToStore = parseFilterExpr rawFilterExpr
            # indicate error
            menuFilterInput.closest(".control-group").toggleClass("error", not filterToStore?)
            if filterToStore?
                # normalize input
                filterToShow = serializeFilter(filterToStore)
                menuFilterInput.val(filterToShow)
            else # otherwise, leave intact
                filterToShow = ""
                filterToStore = rawFilterExpr
        else
            filterToStore = null
            filterToShow = ""
        # store the filter, and display
        @menuFilter[name] = filterToStore
        menuAnchor.find(".menu-label-filter").text(filterToShow)

    # and trigger event when it changes
    triggerIfChanged: =>
        super()
        thisMenuFilter = JSON.stringify @menuFilter
        if @lastMenuFilter isnt thisMenuFilter
            @lastMenuFilter = thisMenuFilter
            _.defer => @trigger "filtersChanged"

)
