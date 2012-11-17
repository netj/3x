###
# CoffeeScript for ExpKit GUI
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###

log = (args...) -> console.log args...

conditionsActive = JSON.parse (localStorage.conditionsActive ?= "{}")

persistActiveConditions = ->
    localStorage.conditionsActive = JSON.stringify conditionsActive

updateConditionDisplay = (condUI) ->
    name = condUI.find(".condition-name")?.text()
    values = condUI.find(".condition-value.active").map( -> $(this).text()).get()
    conditionsActive[name] = values
    hasValues = values?.length > 0
    condUI.find(".condition-values")?.text(if hasValues then "=#{values.join ","}" else "")
    condUI.toggleClass("active", hasValues)

handleConditionMenuAction = (handle) -> (e) ->
    $this = $(this)
    condUI = $this.closest(".condition")
    ret = handle($this, condUI, e)
    updateConditionDisplay condUI
    persistActiveConditions()
    e.stopPropagation()
    e.preventDefault()
    ret

conditionsUISkeleton = null
initConditions = ->
    $.getJSON "/api/v1/conditions", (conditions) ->
        conditionsUI = $("#conditions")
        conditionsUISkeleton ?= conditionsUI.find(".condition.skeleton").remove()
        for name,values of conditions
            variableId = "condition-#{name}"
            # construct a dropdown button for each variable
            condUI = conditionsUISkeleton.clone()
                .attr(id: variableId)
                .removeClass("skeleton")
                .toggleClass("numeric", values.every (v) -> not isNaN parseFloat v)
            # and a dropdown menu
            condUI.find(".dropdown-toggle")
                .attr("data-target": "#"+variableId)
                .find(".condition-name").text(name)
            # with menu items for each value
            menu = condUI.find(".dropdown-menu")
            valueSkeleton = menu.find("li.skeleton").remove()
                .first().removeClass("skeleton")
            isAllActive = do (menu) -> () ->
                menu.find(".condition-value")
                    .toArray().every (a) -> $(a).hasClass("active")
            menu.find(".divider").before(
                for value in values
                    valueUI = valueSkeleton.clone()
                    valueUI.find("a").text(value)
                        .toggleClass("active", value in conditionsActive[name] ? [])
                        .click(do (isAllActive) -> handleConditionMenuAction ($this, condUI) ->
                            $this.toggleClass("active")
                            condUI.find(".condition-values-toggle")
                                .toggleClass("active", isAllActive())
                        )
                    valueUI
                )
            menu.find(".condition-values-toggle")
                .toggleClass("active", isAllActive())
                .click(handleConditionMenuAction ($this, condUI) ->
                    $this.toggleClass("active")
                    condUI.find(".condition-value")
                        .toggleClass("active", $this.hasClass("active"))
                )
            conditionsUI.append(condUI)
            updateConditionDisplay(condUI)
            log "initCondition #{name}=#{values.join ","}"


$ ->
    initConditions()
