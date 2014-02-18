class ChartData
    constructor: (@table, @varX, @varsY, @varsPivot) ->
        ## Collect data to plot from @table
        $trs = @table.baseElement.find("tbody tr")
        @entireRowIndexes = $trs.map((i, tr) -> +tr.dataset.ordinal).get()
        @dataBySeries = _.groupBy @entireRowIndexes, (rowIdx) =>
            @varsPivot.map((pvVar) => @accessorFor(pvVar)(rowIdx)).join(", ")

    # functions to get numbers for plotting
    accessorFor: (v) => (rowIdx) => # TODO change back to single arrows?
        toReturn = @table.resultsForRendering[rowIdx][v.index].value
        return if isNaN(+toReturn) then toReturn else +toReturn

    originFor: (v) => (rowIdx) => # TODO change back to single arrows?
        toReturn = @table.resultsForRendering[rowIdx][v.index].origin
        return if isNaN(+toReturn) then toReturn else +toReturn

    provenanceAccessorFor: (vars) =>
        tableRows = @table.results.rows
        runIdVar =
            name: _3X_.RUN_COLUMN_NAME
            dataIndex: @table.results.names.indexOf _3X_.RUN_COLUMN_NAME
        vars = [vars..., runIdVar]
        getProvenanceRows = @originFor(vars[0])
        (rowIdx) ->
            originRows = getProvenanceRows(rowIdx) ? []
            for i in originRows
                row = {}
                row[v.name] = tableRows[i][v.dataIndex] for v in vars
                row

    relatedVarsFor: (varY) =>
        vars = [varY, @varX]
        varsImplied = vars.concat @varsPivot
        vars = vars.concat (
            col for col in @table.columnsRendered when \
                col.isExpanded and col not in varsImplied
        )
        vars

