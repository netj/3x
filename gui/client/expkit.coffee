###
# CoffeeScript for ExpKit GUI
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-11-11
###

log = (args...) -> console.log args...




conditions = null
conditionsActive = JSON.parse (localStorage.conditionsActive ?= "{}")

persistActiveConditions = ->
    localStorage.conditionsActive = JSON.stringify conditionsActive

updateConditionDisplay = (condUI) ->
    name = condUI.find(".condition-name")?.text()
    values = condUI.find(".condition-value.active").map( -> $(this).text()).get()
    conditionsActive[name] = values
    hasValues = values?.length > 0
    condUI.find(".condition-values")
        ?.html(if hasValues then "=#{
                ($("<div/>").text(v).html() for v in values).join "&shy;,"
            }" else "")
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
    $.getJSON "/api/conditions", (newConditions) ->
        conditions = newConditions
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

        # prepare the column ordering
        columnNames = (conditionName for conditionName of conditions)
        columnNames = columnNames.concat (name for name in results.names when name not in columnNames)
        columnIndex = {}; idx = 0; columnIndex[name] = idx++ for name in results.names

        table = $("#results-table")
        # populate table head
        headSkeleton = table.find("#results-table-head-skeleton")
        thead = table.find("thead tr").first()
        thead.find("td").remove()
        thead.append(headSkeleton.render(name: name) for name in columnNames)
        # and table body
        table.find("tbody").remove()
        tbody = $("<tbody>").appendTo(table)
        rowSkeleton = table.find("#results-table-row-skeleton")
        for dataRow in results.rows
            row = columns: (name: name, value: dataRow[columnIndex[name]] for name in columnNames)
            tbody.append(rowSkeleton.render(row))
        unless $.fn.DataTable.fnIsDataTable(table.get())
            table.dataTable(
                #bRetreive: true
                bDestroy: true
                bLengthChange: false
                bPaginate: false
                bAutoWidth: false
                sDom: '<"H"fir>t<"F"lp>'
                bStateSave: true
                #bProcessing: true
                #bScrollInfinite: true
                #bScrollCollapse: true
                #bDeferRender: true
                #sScrollY: "400px"
            )
    e.preventDefault()





# initialize UI
$ ->
    initConditions()
    $("#show-results").click(showResults)

