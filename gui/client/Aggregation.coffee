define (require) -> (\

# different aggregation methods depending on data type or level of measurement
class Aggregation
    constructor: (@name, @type, @func, @transUnit = _.identity) ->
        Aggregation.FOR_NAME[@name] = @
    @FOR_NAME: {}
    @FOR_TYPE: {}
    @registerForType: (type, names...) ->
        _.extend (Aggregation.FOR_TYPE[type] ?= {}), (_.pick Aggregation.FOR_NAME, names...)
    do ->
        # aggregation for standard measurement types N/O/I/R
        withNumbersIn = (vs) -> v for v in vs.map parseFloat when not isNaN v
        new Aggregation "count",    "number", (vs) -> vs?.length
        new Aggregation "mode",     "string", (vs) ->
            hist = {}
            for v in vs
                hist[v] ?= 0
                hist[v] += 1
            maxc = _.max(hist)
            for v,c of hist when c == maxc
                return v
        new Aggregation "median",   "number", (vs) ->
            ordered = _.clone(vs).sort()
            ordered[Math.floor(vs.length / 2)]
        new Aggregation "min",      "number", (vs) -> ns = withNumbersIn vs; if ns.length then Math.min ns... else null
        new Aggregation "max",      "number", (vs) -> ns = withNumbersIn vs; if ns.length then Math.max ns... else null
        new Aggregation "mean",     "number", (vs) ->
            ns = withNumbersIn vs
            if ns.length > 0
                sum = 0
                count = 0
                for v in ns
                    sum += v
                    count++
                if count > 0 then (sum / count) else null
            else null
        new Aggregation "stdev",   "number", (vs) ->
            ns = withNumbersIn vs
            if ns.length > 0
                dsqsum = 0
                n = 0
                m = Aggregation.FOR_NAME.mean.func ns
                for v in ns
                    d = (v - m)
                    dsqsum += d*d
                    n++
                (Math.sqrt(dsqsum / n))
            else null
        Aggregation.registerForType "nominal"  , "count"  , "mode"  , "enumeration"
        Aggregation.registerForType "ordinal"  , "median" , "mode"  , "min"       , "max"  , "count" , "enumeration"
        Aggregation.registerForType "interval" , "mean"   , "stdev" , "median"    , "mode" , "min"   , "max"       , "enumeration"
        Aggregation.registerForType "ratio"    , "mean"   , "stdev" , "median"    , "mode" , "min"   , "max"       , "enumeration"

)
