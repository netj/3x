###
# CoffeeScript for ExpKit GUI
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###

conditionsActive = JSON.parse (localStorage.conditionsActive ?= "{}")

persistActiveConditions = ->
    localStorage.conditionsActive = JSON.stringify conditionsActive

updateConditionDisplay = (cond) ->
    name = cond.find(".condition-name")?.text()
    values = conditionsActive[name]
    hasValues = values?.length > 0
    cond.find(".condition-values")?.text(if hasValues then "=#{values.join ","}" else "")
    cond.toggleClass("active", hasValues)
    localStorage.conditionsActive

toggleConditionValue = (event) ->
    $this = $(this)
    cond = $this.closest(".condition")
    conditionName = cond.attr("id").replace("condition-", "")
    conditionValue = $this.text()
    conditionsActive[conditionName] ?= []
    wasActive = conditionValue in conditionsActive[conditionName]
    if wasActive
        conditionsActive[conditionName] = conditionsActive[conditionName]?.filter (v) -> v isnt conditionValue
    else
        (conditionsActive[conditionName] ?= []).push conditionValue
        try
            conditionsActive[conditionName].sort((a,b) -> (a - b))
        catch err
            conditionsActive[conditionName].sort()
    persistActiveConditions()
    updateConditionDisplay cond
    $this.toggleClass("active", not wasActive)
    console.log(conditionName, conditionValue, event)
    event.preventDefault()

conditionsUISkeleton = null
updateConditions = ->
    $.getJSON "/api/v1/conditions", (conditions) ->
        conditionsUI = $("#conditions")
        conditionsUISkeleton ?= conditionsUI.find(".skeleton").remove()
        for cond,values of conditions
            variableId = "condition-#{cond}"
            condUI = conditionsUISkeleton.clone()
                .attr(id: variableId)
                .removeClass("skeleton")
            condUI.find(".dropdown-toggle")
                .attr("data-target": "#"+variableId)
                .find(".condition-name").text(cond)
            valueSkeleton = condUI.find(".dropdown-menu .condition-value").remove()
            condUI.find(".dropdown-menu")
                .append(
                    for value in values
                        valueUI = valueSkeleton.first().clone()
                        valueUI.find("a").text(value)
                            .click(toggleConditionValue)
                        valueUI
                )
            conditionsUI.append(condUI)
        #conditionsUI.find(".dropdown-toggle").dropdown()
        for name,values of conditionsActive
            cond = conditionsUI.find("#condition-#{name}")
            cond.find(".dropdown-menu .condition-value").each ->
                # TODO avoid clicking twice when initializing
                $("a", this).click().click() if $(this).text() in values


$ ->
    updateConditions()
