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

initConditions = ->
    $.getJSON "/api/conditions", (conditions) ->
        conditionsUI = $("#conditions")
        skeleton = $("#condition-skeleton")
        for name,values of conditions
            # add each variable by filling the skeleton
            conditionsUI.append(skeleton.render({name, values}))
            condUI = conditionsUI.find("#condition-#{name}")
                .toggleClass("numeric", values.every (v) -> not isNaN parseFloat v)
            # with menu items for each value
            menu = condUI.find(".dropdown-menu")
            isAllActive = do (menu) -> () ->
                menu.find(".condition-value")
                    .toArray().every (a) -> $(a).hasClass("active")
            menu.find(".condition-value")
                .click(do (isAllActive) -> handleConditionMenuAction ($this, condUI) ->
                    $this.toggleClass("active")
                    condUI.find(".condition-values-toggle")
                        .toggleClass("active", isAllActive())
                )
                .each ->
                    $this = $(this)
                    value = $this.text()
                    $this.toggleClass("active", value in conditionsActive[name] ? [])
            menu.find(".condition-values-toggle")
                .toggleClass("active", isAllActive())
                .click(handleConditionMenuAction ($this, condUI) ->
                    $this.toggleClass("active")
                    condUI.find(".condition-value")
                        .toggleClass("active", $this.hasClass("active"))
                )
            updateConditionDisplay(condUI)
            log "initCondition #{name}=#{values.join ","}"




showResults = (e) ->
    $.get "/api/results", {
        runs: []
        batches: []
        conditions: JSON.stringify conditionsActive
    }, (results) ->
        log "got results:", results
        #$("#results-raw").text(JSON.stringify results, null, 2)
        table = $("#results-table")
        # populate table head
        headSkeleton = $("#results-table-head-skeleton")
        thead = table.find("thead tr").first()
        thead.find("td").remove()
        thead.append(headSkeleton.render(name: col) for col of results.index)
        # and table body
        tbody = table.find("tbody").first()
        tbody.find("tr").remove()
        rowSkeleton = $("#results-table-row-skeleton")
        recno = 0
        for run in results.data[0]
            row = columns: (value: results.data[idx][recno] for col,idx of results.index)
            tbody.append(rowSkeleton.render(row))
            recno++
        table.dataTable()
    e.preventDefault()





# initialize UI
$ ->
    initConditions()
    $("#show-results").click(showResults)

