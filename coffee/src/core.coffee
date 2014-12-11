class JSONEditor extends EditorDefaults

	@defaults: () ->
		themes: {}
		templates: {}
		iconlibs: {}
		editors: {}
		languages: {}
		resolvers: []
		custom_validators: []

	constructor: (@element,options)->
		@options =  _.extend(JSONEditor.defaults.options, options)
		@init()

	init: () =>
		@ready = false
		theme_class = JSONEditor.defaults.themes[@options.theme or JSONEditor.defaults.theme]
		if not theme_class? then throw "Unknown theme " + (@options.theme or JSONEditor.defaults.theme)
		@schema = @options.schema
		@theme = new theme_class()
		@template = @.options.template
		@refs = @options.refs or {}
		@uuid = 0
		@__data = {}

		icon_class = JSONEditor.defaults.iconlibs[@options.iconlib or JSONEditor.defaults.iconlib]
		if icon_class? then @iconlib = new icon_class()

		@root_container = @theme.getContainer()
		@element.appendChild(@root_container)

		@translate = @options.translate or JSONEditor.defaults.translate

		DefinitionHelper.loadExternalRefs(@refs,@schema, () =>
			DefinitionHelper.getDefinitions(@schema)
			@validator = new JSONEditor.Validator(self)
			editor_class = @getEditorClass(@schema)
			@root = @createEditor(editor_class, {
				jsoneditor: self
				schema: @schema
				required: true
				container: @root_container
			})

			@root.preBuild()
			@root.build()
			@root.postBuild()

			if @options.startval? then @root.setValue(@options.startval)
			@validation_results = @validator.validate(@root.getValue())
			@root.showValidationErrors(@validation_results)
			@ready = true

			window.requestAnimationFrame(() =>
				if not @ready then return
				@validation_results = @validator.validate(@root.getValue())
				@root.showValidationErrors(@validation_results)
				@trigger('ready')
				@trigger('change')
			)
		)

	getValue: () =>
		@checkReady("getting the value")
		@root.getValue()

	setValue: (value) =>
		@checkReady("setting the value")
		@root.setValue(value)
		@

	validate: (value) =>
		@checkReady("validating")
		if arguments.length is 1 then @validator.validate(value)
		else @validation_results

	destroy: () =>
	    if @destroyed then return
	    if not @ready then return
			@element.innerHTML = '' # ??
			@root.destroy()
			for own key,value of @
				@[key] = undefined

		on: (evt, callback) =>
	    @callbacks = @callbacks or {}
	    @callbacks[evt] = @callbacks[evt] or []
	    @callbacks[evt].push(callback)
	    @

	off: (evt, callback) =>
		if evt? and callback?
			@callbacks = @callbacks or {}
			@callbacks[evt] = @callbacks[evt] or []
			newcallbacks = []
			for c, i in @callbacks[evt]
				if c[i] is callback then continue
				newcallbacks.push(c[i])
			@callbacks[evt] = newcallbacks
		else if evt?
			@callbacks = @callbacks or {}
			@callbacks[evt] = []
		else
			@callbacks = {}
		@


	trigger: (evt) =>
		if @callbacks? and @callbacks[evt]?
			c() for c in @callbacks[evt]
		@

	setOption: (option, value) =>
		if option is "show_errors"
			@options.show_errors = value
			@onChange()
		else 
			throw "Option "+option+" must be set during instantiation and cannot be changed later"
		@

	getEditorClass: (schema) =>
		schema = @expandSchema(schema)
		$each(JSONEditor.defaults.resolvers, (i,resolver) =>
			tmp = resolver(schema)
			if tmp?
				if JSONEditor.defaults.editors[tmp]?
					classname = tmp
					false
		)
		if not classname? then throw "Unknown editor for schema "+JSON.stringify(schema)
		if not JSONEditor.defaults.editors[classname]? then throw "Unknown editor "+classname
		JSONEditor.defaults.editors[classname]

	createEditor: (editor_class, options) =>
		options = $extend({},editor_class.options or {},options)
		new editor_class(options)

	onChange: () =>
		if not @ready then return
		if @firing_change then return
		@firing_change = true

		window.requestAnimationFrame(() =>
			@firing_change = false
			if not @ready then return
			@validation_results = @validator.validate(@root.getValue())

			if @options.show_errors isnt "never"
				@root.showValidationErrors(@validation_results)
			else
				@root.showValidationErrors([])
			@trigger('change')
		)

	compileTemplate: (template, name) =>
		name = name or JSONEditor.defaults.template
		if typeof name is 'string'
			if not JSONEditor.defaults.templates[name]? then throw "Unknown template engine #{name}"
			engine = JSONEditor.defaults.templates[name]()
			if not engine then throw "Template engine #{name} missing required library."
		else 
			engine = name
		if not engine? then throw "No template engine set"
		if not engine.compile? then throw "Invalid template engine set"
		engine.compile(template)

	_data: (el,key,value) =>
		if arguments.length is 3
			if el.hasAttribute('data-jsoneditor-#{key}')?
				uuid = el.getAttribute('data-jsoneditor-#{key}')
			else 
				uuid = @uuid + 1
				el.setAttribute('data-jsoneditor-#{key}',uuid)
			@__data[uuid] = value
		else
			if not el.hasAttribute("data-jsoneditor-#{key}")? then return null
			@__data[el.getAttribute('data-jsoneditor-#{key}')]

	registerEditor: (editor) =>
		@editors = @editors or {}
		@editors[editor.path] = editor
		@

	unregisterEditor: (editor) =>
		@editors = @editors or {}
		@editors[editor.path] = null
		@

	getEditor: (path) =>
    if not @editors? then return
    @editors[path]

	watch: (path,callback) =>
		@watchlist = @watchlist or {}
		@watchlist[path] = @watchlist[path] or []
		@watchlist[path].push(callback)
		@

	unwatch: (path,callback) =>
		if not @watchlist? or not @watchlist[path]? then return @
		if not callback?
			@watchlist[path] = null
			return @
		newlist = []
		for w,i in @watchlist[path]
			if w[i] is callback then continue else newlist.push(w)
		@watchlist[path] = if newlist.length? then newlist else null
		@

	notifyWatchers: (path) =>
    if not @watchlist? or not @watchlist[path]? then return @
    w[i]() for w,i in @watchlist[path]

	isEnabled: () => @root?.isEnabled()

	enable: () => @root.enable()

	disable: () => @root.disable()

	checkReady: (msg) =>
		if not @ready then throw "JSON Editor not ready yet.  Listen for 'ready' event before getting the #{msg}"






