###
# CoffeeScript for ExpKit GUI
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###

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
                .text(cond + " ")
                .append("<span class='caret'>")
            valueSkeleton = condUI.find(".dropdown-menu li").remove()
            condUI.find(".dropdown-menu")
                .append(
                    for value in values
                        valueUI = valueSkeleton.first().clone()
                        valueUI.find("a").text(value)
                        valueUI
                )
            conditionsUI.append(condUI)
        conditionsUI.find(".dropdown-toggle").dropdown()


$ ->
    updateConditions()
