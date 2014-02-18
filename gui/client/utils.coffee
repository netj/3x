numeral = require "numeral"

# See: http://stackoverflow.com/questions/1470810/wrapping-long-text-in-css
# See: http://en.wikipedia.org/wiki/Soft_hyphen for &shy; or \u00AD
Array::joinTextsWithShy = (delim) ->
    ($("<div/>").text(v).html() for v in @).join "\u00AD#{delim}"

{\

log: (args...) -> console.log   args...; args[0]
error: (args...) -> console.error args...; args[0]

safeId: (str) -> str.replace(/[^A-Za-z0-9_-]/g, "-")

markdown: (s) -> s
    .replace(/`(.+?)`/g, "<code>$1</code>")
    .replace(/\*\*(.+?)\*\*/g, "<emph>$1</emph>")
    .replace(/\*(.+?)\*/g, "<emph>$1</emph>")



mapReduce: (map, red) -> (rows) ->
    mapped = {}
    for row in rows
        (mapped[map(row)] ?= []).push row
    reduced = {}
    for key,rowGroup of mapped
        reduced[key] = red(key, rowGroup)
    reduced

forEachCombination: do ->
    forEachCombination = (nestedList, f, acc = []) ->
        if nestedList?.length > 0
            [xs, rest...] = nestedList
            if xs?
                for x in xs
                    forEachCombination rest, f, (acc.concat [x])
            else
                forEachCombination rest, f, acc
        else
            f acc
mapCombination : (nestedList, f) ->
    mapped = []
    forEachCombination nestedList, (combination) -> mapped.push (f combination)
    mapped

choose : (n, items) ->
    indexes = [0...items.length]
    indexesChosen =
        for i in [1..n]
            indexes.splice _.random(0, indexes.length - 1), 1
    indexesChosen.map (i) -> items[i]

indexMap : (vs) -> m = {}; m[v] = i for v,i in vs; m

enumerate : (vs) -> vs.joinTextsWithShy ","

isNominal : (type) -> type in ["string", "nominal"]
isRatio   : (type) -> type in ["number","ratio"]

isAllNumeric : (vs) -> not vs.some (v) -> isNaN parseFloat v
tryConvertingToNumbers : (vs) ->
    if isAllNumeric vs
        vs.map (v) -> +v
    else
        vs

# See: http://numeraljs.com
humanReadableNumber : (num, fmt = "0,0") ->
    numeral(num).format(fmt)


}
