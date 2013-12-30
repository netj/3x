define (require) -> (\

# different rendering methods depending on data type
class DataRenderer
    # HTML generator, or DOM manipulator, or both can be used
    @_ID:   (v,   rowIdxs, data, col, runColIdx) -> v
    @_NOOP: ($td, rowIdxs, data, col, runColIdx) -> null
    @ID:    (allRows, colIdx) -> DataRenderer._ID
    @NOOP:  (allRows, colIdx) -> DataRenderer._NOOP
    @FOR_TYPE: {}
    constructor: (@type, @html = DataRenderer.ID, @dom = null) ->
        DataRenderer.FOR_TYPE[@type] = @
    @DEFAULT_RENDERER: new DataRenderer ""
    @TYPE_ALIASES: {}
    @addAliases: (ty, tys...) -> DataRenderer.TYPE_ALIASES[t] = ty for t in tys
    @forType: (type) ->
        # resolve type aliases
        type = DataRenderer.TYPE_ALIASES[type] ? type
        DataRenderer.FOR_TYPE[type] ? DataRenderer.DEFAULT_RENDERER
    @htmlGeneratorForTypeAndData: (type, rows, colIdx) -> DataRenderer.forType(type).html?(rows, colIdx)
    @domManipulatorForTypeAndData: (type, rows, colIdx) -> DataRenderer.forType(type).dom?(rows, colIdx)
do ->
    new DataRenderer "string"
    DataRenderer.addAliases "string", "nominal"
    new DataRenderer "number", (allRows, colIdx) ->
        #when "number", "ordinal", "interval", "ratio"
        # go through all the values of allRows at colIdx and determine precision
        sumIntegral   = 0; maxIntegral   = 0; minIntegral   = 0
        sumFractional = 0; maxFractional = 0; minFractional = 0
        count = 0
        for row in allRows when row[colIdx]?
            v = "#{row[colIdx].value}."
            f = v.length - 1 - v.indexOf(".")
            #i = v.length - 1 - f
            #minIntegral    = Math.min minIntegral, i
            #maxIntegral    = Math.max maxIntegral, i
            #sumIntegral   += i
            #maxFractional  = Math.max maxFractional, f
            #minFractional  = Math.min maxFractional, f
            sumFractional += f
            count++
        prec = Math.ceil(sumFractional / count)
        do (prec) -> (v) ->
            parseFloat(v).toFixed(prec) if v? and v != ""
    DataRenderer.addAliases "number", "ratio", "interval", "ordinal"
    # TODO ordinals could be or not be numbers, how about trying to detect them first?
DataRenderer

)
