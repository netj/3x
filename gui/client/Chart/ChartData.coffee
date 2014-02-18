utils = require "utils"

class ChartData
    constructor: (@_table, @varX, @varsY, @varsPivot) ->
        # collect data to plot from @_table
        $trs = @_table.baseElement.find("tbody tr")
        @ids = $trs.map((i, tr) -> +tr.dataset.ordinal).get()

        # setup accessors
        @_accessorByName = {}
        @_originAccessorByName = {}

        # group @ids by pivot variables into series
        @idsBySeries = _.groupBy @ids, (rowIdx) =>
            @varsPivot.map((pvVar) => (@accessorFor pvVar)(rowIdx)).join(", ")

    accessorFor: (v) =>
        @_accessorByName[v.name] ?= do (vIdx = v.index) =>
            resultsForRendering = @_table.resultsForRendering
            (rowIdx) ->
                utils.tryConvertingToNumber resultsForRendering[rowIdx][vIdx].value

    originAccessorFor: (v) =>
        @_originAccessorByName[v.name] ?= do (vIdx = v.index) =>
            resultsForRendering = @_table.resultsForRendering
            (rowIdx) ->
                resultsForRendering[rowIdx][vIdx].origin

    provenanceAccessorFor: (vars) =>
        tableRows = @_table.results.rows
        runIdVar =
            name: _3X_.RUN_COLUMN_NAME
            dataIndex: @_table.results.names.indexOf _3X_.RUN_COLUMN_NAME
        vars = [vars..., runIdVar]
        getProvenanceRows = @originAccessorFor vars[0]
        (rowIdx) ->
            for i in (getProvenanceRows rowIdx) ? []
                row = {}
                row[v.name] = tableRows[i][v.dataIndex] for v in vars
                row

    relatedVarsFor: (varY) =>
        vars = [varY, @varX]
        varsImplied = vars.concat @varsPivot
        vars = vars.concat (
            col for col in @_table.columnsRendered when \
                col.isExpanded and col not in varsImplied
        )
        vars

