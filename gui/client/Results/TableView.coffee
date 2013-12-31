define (require) -> (\

$ = require "jquery"
_ = require "underscore"
require "jsrender"
require "jquery.dataTables"
require "jquery.dataTables.sorting.num-html"
require "jquery.dataTables.type-detection.num-html"
require "jquery.dataTables.bootstrap"
require "jquery.dataTables.ColReorder"
require "jquery.dataTables.Scroller"

_3X_ = require "3x"
{
    log
    error
} =
utils = require "utils"


CompositeElement = require "CompositeElement"
Aggregation      = require "Aggregation"
DataRenderer     = require "DataRenderer"
require "ComplexDataTypes"

# TODO rename to TableView
class ResultsTable extends CompositeElement
    @EMPTY_RESULTS:
        names: []
        rows: []

    constructor: (@baseElement, @conditions, @measurements, @optionElements = {}) ->
        super @baseElement

        loadAfterBothInitialized = _.after 2, @load
        @conditions.one   "initialized", loadAfterBothInitialized
        @measurements.one "initialized", loadAfterBothInitialized

        # TODO isolate localStorage key
        @columnsToExpand = (try JSON.parse localStorage.resultsColumnsToExpand)
        unless @columnsToExpand?
            @columnsToExpand = {}
            for name of @conditions.conditions
                @columnsToExpand[name] = true
                break
        @columnNames = null
        @dataTable = null
        @results = ResultsTable.EMPTY_RESULTS
        @resultsForRendering = null
        t = @
        @optionElements.toggleIncludeEmpty
           ?.prop("checked", (try JSON.parse localStorage.resultsIncludeEmpty) ? true)
            .change((e) ->
                # TODO isolate localStorage key
                localStorage.resultsIncludeEmpty = JSON.stringify this.checked
                do t.displayProcessed
            )
        @optionElements.toggleShowHiddenConditions
           ?.prop("checked", (try JSON.parse localStorage.resultsShowHiddenConditions) ? false)
            .change((e) ->
                # TODO isolate localStorage key
                localStorage.resultsShowHiddenConditions = JSON.stringify this.checked
                do t.displayProcessed
            )
        @optionElements.buttonResetColumnOrder
           ?.toggleClass("disabled", @isColumnReordered())
            .click((e) ->
                do t.dataTable?._oPluginColReorder?.fnReset
                $(this).addClass("disabled")
                e.preventDefault()
            )
        @optionElements.buttonRefresh
           ?.toggleClass("disabled", false) # TODO keep disabled until new results arrive
            .click (e) =>
               do e.preventDefault
               do @load
        @optionElements.buttonExport
           ?.click (e) =>
               do e.preventDefault
               do @exportData
        if @optionElements.containerForStateDisplay?
            @on "renderBegan processingBegan", => @optionElements.containerForStateDisplay?.addClass("displaying")
            @on "renderEnded", => @optionElements.containerForStateDisplay?.removeClass("displaying")
        $(window).resize(_.throttle @maximizeDataTable, 100)
            .resize(_.debounce (=> @display true), 500)
        @conditions.on("activeMenuItemsChanged", @load)
                   .on("activeMenusChanged", @displayProcessedHandler)
        @measurements.on("activeMenuItemsChanged", @displayProcessedHandler)
                   .on("activeMenusChanged", @displayProcessedHandler)
                   .on("filtersChanged", @load)

        do @initBrushing

    load: =>
        (
            @optionElements.containerForStateDisplay?.addClass("loading")
            # prepare the query on conditions and measures
            conditions = {}
            for name,condition of @conditions.conditions
                values = @conditions.menuItemsSelected[name]
                if values?.length > 0
                    conditions[name] = values
            unless _.values(conditions).length > 0
                # try to fetch the entire result when no condition is selected
                conditions = {}
                firstCondition = _.keys(@conditions.conditions)?[0]
                conditions[firstCondition] = [""]
            measures = {}
            for name,measure of @measurements.measurements
                measures[name] = @measurements.menuFilter[name]
            # ask for results data
            $.getJSON("#{_3X_.BASE_URL}/api/results",
                runs: []
                batches: []
                inputs: JSON.stringify conditions
                outputs: JSON.stringify measures
            ).success(@displayProcessed)
        ).done(=> @optionElements.containerForStateDisplay?.removeClass("loading"))

    @HEAD_SKELETON: $("""
        <script type="text/x-jsrender">
          <tr>
            {{for columns}}
            <th class="{{>className}}" data-index="{{>index}}" data-dataIndex="{{>dataIndex}}"
                style="text-align: left; vertical-align: middle; white-space: nowrap;"
            ><span class="dataName pull-left">{{>dataName}}</span>
                {{if isMeasured && !isExpanded}}<small>[<span class="aggregationName">{{>aggregation.name}}</span>]</small>{{/if}}
                {{if unit}}(<span class="unit">{{>unit}}</span>){{/if}}
                {{if isRunIdColumn || !~isRunIdExpanded && !isMeasured }}<button
                    class="aggregation-toggler pull-right btn btn-mini {{if isExpanded}}btn-info{{/if}}"
                    style="margin-left:1ex;"
                    title="{{if isExpanded}}Aggregate and fold the values of {{>name}}{{else
                    }}Expand the aggregated values of {{>name}}{{/if}}"
                    ><i class="icon icon-folder-{{if isExpanded}}open{{else}}close{{/if}}-alt"
                        style="vertical-align:text-bottom;"></i></button>{{/if}}</th>
            {{/for}}
          </tr>
        </script>
        """)
    @ROW_SKELETON: $("""
        <script type="text/x-jsrender">
          <tr class="result" data-ordinal="{{>ordinal}}">
            {{for columns}}
            <td class="{{>className}} {{>type}}-type{{if aggregation
                }} aggregated {{>aggregation.name}}{{/if}}"
                data-value="{{>value}}">{{:valueFormatted}}</td>
            {{/for}}
          </tr>
        </script>
        """)
    @CELL_SKELETON: """
        {{if ~column.isRunIdColumn}}<a href="{{>~BASE_URL}}/{{>~value}}/overview" target="run-details">{{>~value}}</a>{{else}}{{>~value}}{{/if}}
        """

    _enumerateAll: (name) =>
        if ({values} = @conditions.conditions[name])?
            (vs) -> (v for v in values when v in vs).joinTextsWithShy ","
        else
            enumerate

    displayProcessedHandler: (e) => do @displayProcessed
    displayProcessed: (newResults) =>
        if newResults?
            @results = newResults
            log "got results:", @results
        do @processData
        do @display

    processData: =>
        @trigger "processingBegan"
        columnIndex = {}; columnIndex[name] = idx for name,idx in @results.names
        @resultsRunIdIndex = columnIndex[_3X_.RUN_COLUMN_NAME]
        do =>
            # construct column definitions
            columns = {}
            idx = 0
            #  first, conditions
            showHiddenConditions = @optionElements.toggleShowHiddenConditions?.is(":checked")
            for name,condition of @conditions.conditions
                isExpanded =  @columnsToExpand[_3X_.RUN_COLUMN_NAME] or
                    @columnsToExpand[name] and (showHiddenConditions or not @conditions.menusInactive[name]?)
                columns[name] =
                    name: name
                    dataName: name
                    dataIndex: columnIndex[name]
                    dataType: condition.type
                    dataUnit: condition.unit
                    unit: if isExpanded then condition.unit
                    type: if isExpanded then condition.type else "string"
                    isMeasured: no
                    isInactive: @conditions.menusInactive[name]
                    isExpanded: isExpanded
                    aggregation: {name:"enumeration", type:"string", func:@_enumerateAll name} unless isExpanded
                    index: idx++
            #  then, measures
            for name,measure of @measurements.measurements when not @measurements.menusInactive[name]
                type = if name is _3X_.RUN_COLUMN_NAME then "hyperlink" else measure.type
                unit = if name is _3X_.RUN_COLUMN_NAME then null        else measure.unit
                col =
                    dataName: name
                    dataIndex: columnIndex[name]
                    dataType: type
                    dataUnit: unit
                    type: type
                    unit: unit
                    isMeasured: yes
                    isInactive: @measurements.menusInactive[name]
                    isExpanded: @columnsToExpand[_3X_.RUN_COLUMN_NAME]
                    isRunIdColumn: name is _3X_.RUN_COLUMN_NAME
                if col.isExpanded
                    columns[name] = _.extend col,
                        name: name
                        index: idx++
                else
                    aggs = Aggregation.FOR_TYPE[col.type] ? _.values(Aggregation.FOR_TYPE)[0]
                    for aggName in @measurements.menuItemsSelected[name] ? []
                        agg = aggs[aggName]
                        agg = _.values(aggs)[0] unless agg?
                        colName = "#{name}.#{aggName}"
                        columns[colName] = _.extend {}, col,
                            name: colName
                            type: agg.type
                            unit: agg.transUnit(unit)
                            aggregation: agg
                            index: idx++
            @columns = columns
            @columnNames = []; @columnNames[col.index] = name for name,col of columns
        #log "column order:", @columnNames
        #log "column definitions:", @columns

        # prepare several other auxiliary structures
        idx = 0
        @columnNamesExpanded =
            for name in @columnNames when @columns[name].isExpanded
                @columns[name].indexAmongExpanded = idx++
                name

        # and preprocess data
        @isRunIdExpanded = @columns[_3X_.RUN_COLUMN_NAME]?.isExpanded ? false
            # or we could use: @columnsToExpand[_3X_.RUN_COLUMN_NAME]
            #    (it will allow unaggregated tables without run column)
        @optionElements.toggleIncludeEmpty?.prop("disabled", @isRunIdExpanded)
        if @isRunIdExpanded
            # present results without aggregation
            #log "no aggregation"
            @resultsForRendering =
                for row,rowIdx in @results.rows
                    for name in @columnNames
                        value: row[columnIndex[name]]
                        origin: rowIdx
        else
            # aggregate data
            groupRowsByColumns = (rows) =>
                idxs = [0...rows.length]
                map = (rowIdx) => JSON.stringify (@columnNamesExpanded.map (name) -> rows[rowIdx][columnIndex[name]])
                red = (key, groupedRowIdxs) =>
                    for name in @columnNames
                        col = @columns[name]
                        colIdx = col.dataIndex
                        if col.isExpanded
                            value: rows[groupedRowIdxs[0]][colIdx]
                        else
                            value: col.aggregation.func(rows[rowIdx][colIdx] for rowIdx in groupedRowIdxs)
                            origin: _.sortBy(groupedRowIdxs,
                                    if utils.isAllNumeric (groupedRowIdxs.map (rowIdx) -> rows[rowIdx][colIdx])
                                        (rowIdx) -> +rows[rowIdx][colIdx]
                                    else
                                        (rowIdx) ->  rows[rowIdx][colIdx]
                                )
                grouped = utils.mapReduce(map, red)(idxs)
                [_.values(grouped), _.keys(grouped)]
            [aggregatedRows, aggregatedGroups] = groupRowsByColumns(@results.rows)
            #log "aggregated results:", aggregatedRows
            #log "aggregated groups:", aggregatedGroups
            # pad aggregatedRows with missing combination of condition values
            emptyRows = []
            if @optionElements.toggleIncludeEmpty?.is(":checked")
                EMPTY_VALUES = []
                columnValuesForGrouping =
                    for name in @columnNamesExpanded
                        @conditions.menuItemsSelected[name] ? @conditions.conditions[name].values
                utils.forEachCombination columnValuesForGrouping, (group) =>
                    key = JSON.stringify group
                    unless key in aggregatedGroups
                        #log "padding empty row for #{key}"
                        emptyRows.push @columnNames.map (name) =>
                            col = @columns[name]
                            if col.isExpanded
                                value: group[col.indexAmongExpanded]
                            else
                                value: col.aggregation.func(EMPTY_VALUES) ? ""
                #log "padded empty groups:", emptyRows
            @resultsForRendering = aggregatedRows.concat emptyRows
        #log "rendering results:", @resultsForRendering
        _.defer => @trigger "changed" #; log "ResultsTable changed"

    render: => # render the table based on what @processData has prepared
        # fold any artifacts made by previous DataTables
        @dataTable?.dataTable bDestroy:true

        # populate table head
        thead = @baseElement.find("thead")
        thead.find("tr").remove()
        columnMetadata = []
        thead.append(ResultsTable.HEAD_SKELETON.render(
            columns:
                for name,idx in @columnNames
                    col = @columns[name]
                    columnMetadata[idx] = _.extend col,
                        className: "#{if col.isMeasured then "measurement" else "condition"
                                   }#{if col.isInactive then " muted"      else ""
                                   }#{if col.isExpanded then " expanded"   else ""
                                   }"
                        # renderer can't be defined earlier because it needs to see the data
                        renderHTML: DataRenderer.htmlGeneratorForTypeAndData(col.type, @resultsForRendering, col.index)
                        renderDOM:  DataRenderer.domManipulatorForTypeAndData(col.type, @resultsForRendering, col.index)
                        isLastColumn: col.index == @columnNames.length - 1
            , {BASE_URL:_3X_.BASE_URL, @isRunIdExpanded}
            ))
        # allow the column header to toggle aggregation
        t = @
        thead.find(".aggregation-toggler").click((e) ->
            return if e.shiftKey # to reduce interference with DataTables' sorting
            $this = $(this)
            th = $this.closest("th")
            th.toggleClass("expanded")
            name = th.find("span.dataName").text()
            t.columnsToExpand[name] = if th.hasClass("expanded") then true else null
            localStorage.resultsColumnsToExpand = JSON.stringify t.columnsToExpand
            do t.displayProcessed
            do e.stopPropagation
        )

        # populate table body
        @baseElement.find("tbody").remove()
        tbody = $("<tbody>").append(
            for row,ordinal in @resultsForRendering
                ResultsTable.ROW_SKELETON.render {
                        ordinal
                        columns:
                            for c,idx in columnMetadata
                                $.extend {}, c, row[idx],
                                    valueFormatted: c.renderHTML(row[idx].value,
                                            row[idx].origin, @results, c, @resultsRunIdIndex)
                    }, {
                        BASE_URL:_3X_.BASE_URL
                    }
        ).appendTo(@baseElement)
        # apply DataRenderer DOM mainpulator
        for c,idx in columnMetadata when c.renderDOM?
            tbody.find("tr").find("td:nth(#{idx})").each (ordinal, td) =>
                row = @resultsForRendering[ordinal]
                c.renderDOM td, row[idx].origin, @results, c, @resultsRunIdIndex

        # finally, make the table interactive with DataTable
        @dataTable = $(@baseElement).dataTable
            # XXX @baseElement must be enclosed by a $() before .dataTable(),
            # because otherwise @baseElement gets polluted by DataTables, and that
            # previous state will make it behave very weirdly.
            sDom: 'R<"H"fir>t<"F"lp>'
            bDestroy: true
            bLengthChange: false
            bPaginate: false
            bAutoWidth: true
            bScrollCollapse: true
            sScrollX: "100%"
            sScrollY: "#{window.innerHeight - @baseElement.offset().top}px"
            # Use localStorage instead of cookies (See: http://datatables.net/blog/localStorage_for_state_saving)
            # TODO isolate localStorage key
            fnStateSave: (oSettings, oData) -> localStorage.resultsDataTablesState = JSON.stringify oData
            fnStateLoad: (oSettings       ) -> try JSON.parse localStorage.resultsDataTablesState
            bStateSave: true
            oColReorder:
                fnReorderCallback: =>
                    @optionElements.buttonResetColumnOrder?.toggleClass("disabled", @isColumnReordered())
                    do @updateColumnIndexMappings
        do @updateColumnVisibility
        do @updateColumnIndexMappings
        do @maximizeDataTable

        # trigger event for others
        @dataTable.off "draw.ResultsTable"
        @dataTable.on "draw.ResultsTable", _.debounce (=> @trigger "updated"), 100

    maximizeDataTable: =>
        return unless @dataTable?
        s = @dataTable.fnSettings()
        s.oScroll.sY = "#{window.innerHeight - @baseElement.offset().top}px"
        @dataTable.fnDraw()
        # XXX above doesn't guarantee full height, so force it
        scrollBody = $(s.nTableWrapper).find(".#{s.oClasses.sScrollBody}")
        scrollBody.css height: "#{window.innerHeight - scrollBody.offset().top}px"

    updateColumnIndexMappings: =>
        # Construct column index mappings for others to build functions on top of it.
        # Mapping the observed DOM index to the actual column index for either
        # @resultsForRendering or @results.rows is hard because DataTables'
        # ColReorder and fnSetColumnVis significantly changes the DOM.
        $ths = @dataTable.find("thead:nth(0)").find("th")
        @columnsRenderedToProcessed = $ths.map((i,th) -> +$(th).attr("data-index")    ).toArray()
        @columnsRenderedToData      = $ths.map((i,th) -> +$(th).attr("data-dataIndex")).toArray()
        @columnsRendered            = (@columns[@columnNames[i]] for i in @columnsRenderedToProcessed)
        #log "updateColumnIndexMappings", @columnsRenderedToProcessed, @columnsRenderedToProcessed, @columnsRendered

    isColumnReordered: =>
        colOrder = @getColumnOrdering()
        (JSON.stringify colOrder) == (JSON.stringify (_.range colOrder?.length))
    getColumnOrdering: =>
        @dataTable?._oPluginColReorder?.fnGetCurrentOrder?() ?
        try (JSON.parse localStorage.resultsDataTablesState).ColReorder

    updateColumnVisibility: =>
        return unless @dataTable?
        # Hide some columns if necessary
        colOrder = @getColumnOrdering()
        return unless colOrder?.length == @columnNames.length
        isVisible =
            unless @optionElements.toggleShowHiddenConditions?.is(":checked")
            then (name) => not @columns[name].isInactive
            else (name) => true
        for name,idx in @columnNames
            @dataTable.fnSetColumnVis (colOrder.indexOf idx), (isVisible name), false
        do @dataTable.fnDraw


    initBrushing: =>
        # setup brushing table cells, so as we hover over a td element, the
        # cell as well as others will be displaying the raw data value
        provenancePopoverParent = @baseElement.parent()
        provenancePopover = @brushingProvenancePopover = $("""
            <div class="provenance popover hide fade top">
                <div class="arrow"></div>
                <div class="popover-inner">
                    <div class="popover-content">
                        <a class="provenance-link"></a>
                    </div>
                </div>
            </div>
            """).appendTo(provenancePopoverParent)
        # TODO clean these popover code with https://github.com/jakesgordon/javascript-state-machine
        hideTimeout = null
        detachProvenancePopoverTimeout = null
        attachProvenancePopover = ($td, e, cursorRelPos, runId) =>
            detachProvenancePopoverTimeout = clearTimeout detachProvenancePopoverTimeout if detachProvenancePopoverTimeout?
            hideTimeout = clearTimeout hideTimeout if hideTimeout?
            pos = $td.position()
            provenancePopover
                .find(".provenance-link").text(runId)
                    .attr(href:"#{_3X_.BASE_URL}/#{runId}/overview", target: "run-details").end()
                .removeClass("hide")
                .css
                    top:  "#{pos.top              - (provenancePopover.height())}px"
                    left: "#{pos.left + e.offsetX - (provenancePopover.width()/2)}px"
            _.defer => provenancePopover.addClass("in")
        endBrushingTimeout = null
        detachProvenancePopover = =>
            detachProvenancePopoverTimeout = clearTimeout detachProvenancePopoverTimeout if detachProvenancePopoverTimeout?
            hideTimeout = clearTimeout hideTimeout if hideTimeout?
            detachProvenancePopoverTimeout = setTimeout ->
                    provenancePopover.removeClass("in")
                    hideTimeout = clearTimeout hideTimeout if hideTimeout?
                    hideTimeout = setTimeout (=> provenancePopover.addClass("hide")), 150
                , 100
        provenancePopover
            .on("mouseover", (e) ->
                endBrushingTimeout = clearTimeout endBrushingTimeout if endBrushingTimeout?
                detachProvenancePopoverTimeout = clearTimeout detachProvenancePopoverTimeout if detachProvenancePopoverTimeout?
            )
            .on("mouseout", (e) ->
                endBrushingTimeout = clearTimeout endBrushingTimeout if endBrushingTimeout?
                endBrushingTimeout = setTimeout endBrushing, 100
                do detachProvenancePopover
            )
        brushingMode = off
        brushingIsPossible = no
        brushingTRIndex = null
        brushingRowProcessed = null
        brushingLastRowIdx = null
        brushingSetupRow = null
        brushingCellHTMLRenderer = null
        brushingCellDOMRenderer = null
        brushingTDs = null
        brushingTDsOrigContent = null
        brushingTDsAll = null
        brushingTDsOrigCSSText = null
        updateBrushing = ($td, e) =>
            return unless brushingIsPossible
            colIdxRendered = $td.index()
            return if @columnsRendered[colIdxRendered].isExpanded or not brushingTDs?
            colIdxProcessed = @columnsRenderedToProcessed[colIdxRendered]
            brushingCell = brushingRowProcessed[colIdxProcessed]
            return unless brushingCell?.origin?.length > 0
            # find out the relative position we're brushing
            cursorRelPos = e.offsetX / $td[0].offsetWidth
            n = brushingCell.origin.length - 1
            brushingPos = Math.max(0, Math.min(n, Math.round(n * cursorRelPos)))
            rowIdxData  = brushingCell.origin[brushingPos]
            attachProvenancePopover $td, e, brushingPos, @results.rows[rowIdxData][@resultsRunIdIndex]
            return if brushingLastRowIdx == rowIdxData # update only when there's change, o.w. flickering happens
            brushingLastRowIdx = rowIdxData
            #log "updating", brushingLastRowIdx
            #do => # XXX debug
            #    window.status = "#{@columnsRendered[colIdxRendered].name}: #{brushingPos}/#{brushingCell.origin.length-1} = #{cursorRelPos}"
            #    log "updateBrushing", @columnsRendered[colIdxRendered].name, brushingSetupRow, rowIdxData, brushingPos, brushingCell.origin.length-1
            # then, update the cells to corresponding values
            brushingTDs.each (i,td) =>
                colIdxRendered = $(td).index()
                colIdxProcessed = @columnsRenderedToProcessed[colIdxRendered]
                colIdxData      = @columnsRenderedToData[colIdxRendered]
                # use DataRenderer to show them
                c = @columnsRendered[colIdxRendered]
                args = [rowIdxData, @results, c, @resultsRunIdIndex]
                $(td).html(
                    # XXX somehow, the first row isn't refreshing even though correct html is being set
                    (if brushingTRIndex == 0 then "<span></span>" else "") +
                    (brushingCellHTMLRenderer[i]?(
                        @results.rows[rowIdxData][colIdxData], args...) ? "")
                )
                brushingCellDOMRenderer[i]?(td, args...)
        endBrushing = =>
            # restore DOM of previous TR
            if brushingSetupRow?
                #log "endBrushing", brushingSetupRow #, brushingTDs, brushingTDsOrigContent
                brushingTDs?.removeClass("brushing").each (i,td) =>
                    $(td).contents().remove().end().append(brushingTDsOrigContent[i])
                brushingTDsAll?.each (i,td) =>
                    td.style.cssText = brushingTDsOrigCSSText[i]
                do detachProvenancePopover
                brushingRowProcessed = brushingSetupRow = brushingLastRowIdx =
                    brushingCellHTMLRenderer = brushingCellDOMRenderer =
                    brushingTDs = brushingTDsOrigContent =
                    brushingTDsAll = brushingTDsOrigCSSText =
                        null
        startBrushing = ($td, e) =>
            # find which row we're brushing
            $tr = $td.closest("tr")
            rowIdxProcessed = $tr.attr("data-ordinal")
            brushingIsPossible = not @columnsRendered[$td.index()].isExpanded and rowIdxProcessed?
            if brushingIsPossible
                rowIdxProcessed = +rowIdxProcessed
                #log "startBrushing", rowIdxProcessed
                # setup the cells to start brushing
                unless brushingSetupRow == rowIdxProcessed
                    do endBrushing
                    #log "setting up row #{rowIdxProcessed} for brushing"
                    brushingSetupRow = rowIdxProcessed
                    brushingTRIndex = $tr.index()
                    brushingRowProcessed = @resultsForRendering[brushingSetupRow]
                    brushingTDsAll = $tr.find("td")
                    brushingTDs = brushingTDsAll.filter((i,td) => not @columnsRendered[i].isExpanded)
                    groupedRowIdxs = brushingRowProcessed[@columnsRenderedToProcessed[brushingTDs.index()]]?.origin
                    unless groupedRowIdxs?
                        # filled empty row, makes no sense to brush here
                        brushingRowProcessed = brushingSetupRow =
                            brushingTDs = brushingTDsAll =
                                null
                        brushingIsPossible = no
                        return
                    brushingTDsOrigCSSText = []
                    brushingTDsAll.each (i,td) =>
                        # fix width of each cell we're going to touch
                        brushingTDsOrigCSSText[i] = td.style.cssText
                        # copy from thead
                        $th = @dataTable.find("thead").eq(0).find("th").eq(i)
                        td.style.cssText += """;
                            width: #{$th.css("width")} !important;
                            min-height: #{td.offsetHeight}px !important;
                            word-break: break-all;
                            word-wrap: break-word;
                        """ # XXX .style.cssText is the only way to give !important :S
                    brushingTDsOrigContent = []
                    brushingTDs.addClass("brushing").each (i,td) =>
                        # detach the contents DOM and keep it safe
                        brushingTDsOrigContent[i] = $(td).contents().detach()
                    # prepare DataRenderer for each cell
                    brushingCellHTMLRenderer = []
                    brushingCellDOMRenderer = []
                    processedForThisRow =
                        for rowIdx in groupedRowIdxs
                            for col in @results.rows[rowIdx]
                                value: col
                    #log "DataRenderer", brushingRowProcessed, processedForThisRow
                    brushingTDs.each (i,td) =>
                        # derive a renderer using only the values within this row
                        col = @columnsRendered[$(td).index()]
                        brushingCellHTMLRenderer[i] =
                            try DataRenderer.htmlGeneratorForTypeAndData(col.dataType, processedForThisRow, col.dataIndex)
                        brushingCellDOMRenderer[i] =
                            try DataRenderer.domManipulatorForTypeAndData(col.dataType, processedForThisRow, col.dataIndex)
                updateBrushing $td, e
            else
                # not on a brushable cell
                do endBrushing
        @baseElement.parent()
            .on("mouseover", "tbody td", (e) ->
                brushingMode = e.shiftKey
                return unless brushingMode
                endBrushingTimeout = clearTimeout endBrushingTimeout if endBrushingTimeout?
                startBrushing $(@), e
            )
            .on("mousemove", "tbody td", # XXX throttling mousemove significantly degrades the experience. _.throttle , 100
                (e) ->
                    # changing the shift key immediately toggles the brushingMode.
                    # releasing shift key pauses the brushing, until mouseout,
                    # and resumes when shift is pressed back
                    unless brushingMode
                        if e.shiftKey
                            brushingMode = on
                            startBrushing $(@), e
                            return
                    else
                        unless e.shiftKey
                            brushingMode = off
                    updateBrushing $(@), e if brushingMode
            )
            .on("mouseout", "tbody td", (e) ->
                endBrushingTimeout = clearTimeout endBrushingTimeout if endBrushingTimeout?
                endBrushingTimeout = setTimeout endBrushing, 100
            )

    exportData: =>
        # generate tab separated text from the rendered result data
        textRow = (cells) -> cells.join "\t"
        textEsc = (value) ->
            s = ""+value
            if ///^\S+$///.test s then s
            else "\"#{s.replace /"/g, "\"\""}\""
        data = (textRow (textEsc c.name for c in @columnsRendered)) + "\n"
        for row in @resultsForRendering
            data += (textRow (textEsc c.value for c in row)) + "\n"
        # open it using the data URI scheme to make it appear as plain text
        dataURI = "data:text/plain;charset=UTF-8,#{encodeURIComponent data}"
        popup = open dataURI, "data-export", "menubar=no"

)
