define (require) -> (\

_3X_ = require "cs!3x"
{
    log
    error
} =
utils = require "cs!utils"

Aggregation = require "cs!Aggregation"
DataRenderer = require "cs!DataRenderer"

# More complex types
class ComplexDataTypes
    @_: do ->
        new DataRenderer "hyperlink"
        , (allRows, colIdx) ->
            (v, rowIdxs, data, col, runColIdx) ->
                if typeof rowIdxs is "number"
                    """
                    <a href="#{_3X_.BASE_URL}/#{v}/overview" target="run-details">#{v}</a>
                    """
                else
                    v
        , (allRows, colIdx) ->
            (td, rowIdxs, data, col, runColIdx) ->
                td.style.fontSize = "80%"
        # aggregation/rendering for images
        fileURL = (row, col, runColIdx) =>
            "#{_3X_.BASE_URL}/#{row[runColIdx]}/#{row[col.dataIndex]}"
        new Aggregation "overlay", "image", Aggregation.FOR_NAME.count.func
        # TODO type alias for Aggregation
        Aggregation.registerForType "image/png",  "overlay", "count"
        Aggregation.registerForType "image/jpeg", "overlay", "count"
        Aggregation.registerForType "image/gif",  "overlay", "count"
        MAX_IMAGES = 20 # TODO Chrome is sluggish at rendering many translucent images
        BASE_OPACITY = 0.05 # minimum opacity
        VAR_OPACITY  = 0.50 # ratio to plus/minus the dividend opacity
        new DataRenderer "image"
        , (allRows, colIdx) ->
            (v, rowIdxs, data, col, runColIdx) ->
                rowIdxs = [rowIdxs] if (typeof rowIdxs) is "number"
                if rowIdxs?.length > 0
                    """
                    <span class="overlay-frame"><img class="overlay"
                    src="#{fileURL data.rows[rowIdxs[0]], col, runColIdx}"
                    ></span>
                    """
        , (allRows, colIdx) ->
            (td, rowIdxs, data, col, runColIdx) ->
                return if (typeof rowIdxs) is "number" or not rowIdxs?.length > 1
                j = 0
                $td = $(td)
                $td.find("img")
                .error(-> @.src = fileURL data.rows[rowIdxs[++j]], col, runColIdx)
                .load ->
                    $img = $(@)
                    width  = $img.width()
                    height = $img.height()
                    # setup canvas
                    $canvas = $("<canvas>")
                        .attr(width: $img.width(), height: $img.height())
                        .addClass("overlay")
                        .appendTo($img.parent())
                    $img.remove()
                    canvas = $canvas[0]
                    ctx = canvas.getContext("2d")
                    ctx.globalCompositeOperation = "darker"
                    # sample images
                    rows = (data.rows[rowIdx] for rowIdx in rowIdxs)
                    numOverlaid = Math.min(MAX_IMAGES, rows.length)
                    sampledRows =
                        if rows.length <= MAX_IMAGES then rows
                        # TODO can we do a better sampling?
                        else rows[i] for i in [0...rows.length] by Math.floor(rows.length / MAX_IMAGES)
                    # mix images on canvas
                    divOpacity = (1 - BASE_OPACITY) / numOverlaid
                    numLoaded = 0
                    for row,i in sampledRows
                        img = new Image
                        img.crossOrigin = "anonymous"
                        img.src = fileURL row, col, runColIdx
                        img.onload = ->
                            ctx.globalAlpha = BASE_OPACITY + divOpacity * (1.0 + VAR_OPACITY/2 * (numOverlaid/2 - i) / numOverlaid)
                            try ctx.drawImage @, 0,0, width,height
                            do replaceCanvas if ++numLoaded == numOverlaid
                        img.onerror = ->
                            do replaceCanvas if ++numLoaded == numOverlaid
                    # replace canvas with inline image
                    replaceCanvas = ->
                        return # XXX rendering inline image (data URL) is extremely slow on Safari
                        $("<img>")
                            .addClass("overlay-frame")
                            .attr(src: canvas.toDataURL())
                            .appendTo(td)
                            .load ->
                                $canvas.remove()
        DataRenderer.addAliases "image", "image/png", "image/jpeg", "image/gif" #, TODO ...


)
