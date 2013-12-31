define (require) -> (\

$ = require "jquery"
_ = require "underscore"

{
    log
    error
} = require "cs!utils"

# TODO find a cleaner way to do this, i.e., leveraging jQuery, Backbone
class CompositeElement
    @INSTANCES: []
    @displayDeferredInstances: ->
        for e in CompositeElement.INSTANCES
            do e.displayIfDeferred

    constructor: (@baseElement) ->
        CompositeElement.INSTANCES.push @
        @on      = $.proxy @baseElement.on     , @baseElement
        @off     = $.proxy @baseElement.off    , @baseElement
        @one     = $.proxy @baseElement.one    , @baseElement
        @trigger = $.proxy @baseElement.trigger, @baseElement

    display: (args...) =>
        # NOTE by checking @deferredDisplay, we can tell if this element had to be rendered or not
        @deferredDisplay ?= $.Deferred()
        @deferredDisplayArgs = args if args.length > 0
        if @baseElement.is(":visible")
            # TODO if @isRendering then reserve a quick rerendering after the current @render finishes?
            unless @isRendering
                @isRendering = yes
                _.defer =>
                    log "#{@baseElement.prop("id")}: renderBegan"
                    @trigger "renderBegan"
                    _.delay =>
                        @render (@deferredDisplayArgs ? [])...
                        _.defer =>
                            @deferredDisplay.resolve()
                            @trigger "renderEnded"
                            @isRendering = no
                            @deferredDisplay = @deferredDisplayArgs = null
                            log "#{@baseElement.prop("id")}: renderEnded"
                    , 1
        else
            log "#{@baseElement.prop("id")}: rendering deferred..."
        @deferredDisplay.promise()
    displayIfDeferred: => do @display if @deferredDisplay?
    render: =>
        error "CompositeElement::render() not implemented"

)
