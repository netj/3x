$ = require "jquery"
require "jsrender"
require "jquery.ui.selectable"

utils = require "utils"

CompositeElement = require "CompositeElement"

# TODO rename to MenuDropdownView
class MenuDropdown extends CompositeElement
    constructor: (@baseElement, @menuName) ->
        super @baseElement

        @baseElement.addClass("menu-dropdown")

        @menuLabelItemsPrefix    = "="
        @menuLabelItemsDelimiter = ","
        @menuLabelItemsPostfix   = ""

        @_menuDropdownSkeleton = $("""
            <script type="text/x-jsrender">
              <li id="#{@menuName}-{{>id}}" class="#{@menuName} dropdown">
                <a class="dropdown-toggle" role="button" href="#"
                  data-toggle="dropdown" data-target="##{@menuName}-{{>id}}"
                  ><span class="caret"></span><i class="icon menu-checkbox"></i><span
                      class="menu-label">{{>name}}</span><span class="menu-label-items"></span>&nbsp;</a>
                <ul class="dropdown-menu" role="menu">
                  {{for items}}
                  <li><a href="#" class="menu-dropdown-item">{{>#data}}</a></li>
                  {{/for}}
                  <li class="divider"></li>
                  <li><a href="#" class="menu-dropdown-toggle-all">All</a></li>
                </ul>
              </li>
            </script>
            """)

        @lastMenuItemsSelected = (localStorage["menuDropdownSelectedItems_#{@menuName}"] ?= "{}")
        @menuItemsSelected = try JSON.parse @lastMenuItemsSelected
        @lastMenusInactive = (localStorage["menuDropdownInactiveMenus_#{@menuName}"] ?= "{}")
        @menusInactive = try JSON.parse @lastMenusInactive

    persist: =>
        localStorage["menuDropdownSelectedItems_#{@menuName}"] = JSON.stringify @menuItemsSelected
        localStorage["menuDropdownInactiveMenus_#{@menuName}"] = JSON.stringify @menusInactive

    clearSelection: =>
        @baseElement.find(".dropdown").each (i, dropdown) =>
            @updateDisplay $(dropdown)
                .addClass("active")
                .find(".menu-dropdown-item").removeClass("ui-selected").end()
        do @persist
        do @triggerIfChanged


    clearMenu: =>
        @baseElement.find("*").remove()

    addMenu: (name, items) =>
        id = utils.safeId(name)
        @baseElement.append(@_menuDropdownSkeleton.render({name, id, items}))
        menuAnchor = @baseElement.find("##{@menuName}-#{id}")
        menu = menuAnchor.find(".dropdown-menu")
        isAllItemActive = do (menu) -> () ->
            menu.find(".menu-dropdown-item")
                .toArray().every (a) -> $(a).hasClass("ui-selected")
        handleSelectionSession = do (isAllItemActive) ->
            ($this, menuAnchor, e, ui) =>
                menuAnchor.find(".menu-dropdown-toggle-all")
                    .toggleClass("ui-selected", isAllItemActive())
        menu.find(".menu-dropdown-toggle-all")
            .toggleClass("ui-selected", isAllItemActive())
            .click(@menuItemActionHandler ($this, menuAnchor) ->
                $this.toggleClass("ui-selected")
                menuAnchor.find(".menu-dropdown-item")
                    .toggleClass("ui-selected", $this.hasClass("ui-selected"))
            )
        menu.find(".menu-dropdown-item")
            .each((i,menuitem) =>
                $this = $(menuitem)
                item = $this.text()
                $this.toggleClass("ui-selected",
                    item in (@menuItemsSelected[name] ? []))
            )
            .on("click", @menuItemActionHandler ($this, rest...) =>
                unless @isSelectableInProgress
                    $this.toggleClass("ui-selected")
                    handleSelectionSession $this, rest...
            )
        menu.selectable(
                filter: ".menu-dropdown-item"
                cancel: ".menu-dropdown-toggle-all"
            )
            .on("selectablestart", (e, ui) =>
                @isSelectableInProgress = yes
            )
            .on("selectableselecting", (e, ui) =>
                ui.selecting.focus()
            )
            # persist and reflect menuAnchor after selection stops
            .on("selectablestop", @menuItemActionHandler (args...) =>
                @isSelectableInProgress = no
                handleSelectionSession args...
            )
        menuAnchor.toggleClass("active", not @menusInactive[name]?)
            .find(".menu-checkbox")
                .click(do (menuAnchor) => (e) =>
                    e.stopPropagation()
                    e.preventDefault()
                    menuAnchor.toggleClass("active")
                    @updateDisplay menuAnchor
                    do @persist
                    do @triggerIfChanged
                )
        menuAnchor

    menuItemActionHandler: (handle) =>
        m = @
        (e, args...) ->
            e.stopPropagation()
            e.preventDefault()
            $this = $(this)
            menuAnchor = $this.closest(".dropdown")
            try
                ret = handle($this, menuAnchor, e, args...)
                m.updateDisplay menuAnchor
                do m.persist
                do m.triggerChangedAfterMenuBlurs
                ret

    @ICON_CLASS_VISIBLE: "icon-check"
    @ICON_CLASS_HIDDEN:  "icon-check-empty"

    updateDisplay: (menuAnchor) =>
        name = menuAnchor.find(".menu-label")?.text()
        values = menuAnchor.find(".menu-dropdown-item.ui-selected").map( -> $(this).text()).get()
        hasValues = values?.length > 0
        isInactive = not menuAnchor.hasClass("active")
        @menuItemsSelected[name] =
            if hasValues
                values
        @menusInactive[name] =
            if isInactive
                true
        menuAnchor.find(".menu-label-items")
            ?.html(if hasValues then "#{@menuLabelItemsPrefix}#{
                values.joinTextsWithShy @menuLabelItemsDelimiter}#{
                    @menuLabelItemsPostfix}" else "")
        menuAnchor.find(".menu-checkbox")
            .removeClass("#{MenuDropdown.ICON_CLASS_VISIBLE} #{
                MenuDropdown.ICON_CLASS_HIDDEN}")
            .toggleClass(MenuDropdown.ICON_CLASS_VISIBLE, not isInactive)
            .toggleClass(MenuDropdown.ICON_CLASS_HIDDEN ,     isInactive)

    triggerChangedAfterMenuBlurs: =>
        # avoid multiple checks scheduled
        return if @_triggerChangedAfterMenuBlursTimeout?
        @_triggerChangedAfterMenuBlursTimeout = setInterval =>
            # wait until no menu stays open
            return if @baseElement.find(".dropdown.open").length > 0
            @_triggerChangedAfterMenuBlursTimeout = clearInterval @_triggerChangedAfterMenuBlursTimeout
            # and detect change to trigger events
            do @triggerIfChanged
        , 100

    triggerIfChanged: =>
        thisMenuItemsSelected = JSON.stringify @menuItemsSelected
        if @lastMenuItemsSelected != thisMenuItemsSelected
            @lastMenuItemsSelected = thisMenuItemsSelected
            _.defer => @trigger "activeMenuItemsChanged"
        thisMenusInactive = JSON.stringify @menusInactive
        if @lastMenusInactive != thisMenusInactive
            @lastMenusInactive = thisMenusInactive
            _.defer => @trigger "activeMenusChanged"

