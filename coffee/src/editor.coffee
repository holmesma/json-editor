class AbstractEditor

	@defaults: () ->

	constructor: (@element,options)->
		@options =  _.extend(AbstractEditor.defaults.options, options)
		@init() #???

	onChildEditorChange: (editor) => @onChange(true)

	notify: () => @jsoneditor.notifyWatchers(@path)

	change: () =>
		if @parent?
			@parent.onChildEditorChange(@)
		else 
			@jsoneditor.onChange()

	onChange: () =>
		@notify()
		if @watch_listener? then @watch_listener()
		if bubble? then @change()

	register: () =>
		@jsoneditor.registerEditor(@)
		@onChange()

	unregister: () => if @jsoneditor? then @jsoneditor.unregisterEditor(@)

	getNumColumns: () => 12

	init: (options) =>
		@jsoneditor = options.jsoneditor
		
		@theme = @jsoneditor.theme
		@template_engine = @jsoneditor.template
		@iconlib = @jsoneditor.iconlib
		
		@original_schema = options.schema
		@schema = @jsoneditor.expandSchema(@original_schema)
		
		@options = $extend({}, (@options ? {}), (options.schema.options ? {}), options)
		
		if not options.path? and not @schema.id? then @schema.id = "root"
		@path = options.path ? 'root'
		@formname = options.formname ? @path.replace(/\.([^.]+)/g,'[$1]')
		if @jsoneditor.options.form_name_root? @formname = @formname.replace(/^root\[/,@jsoneditor.options.form_name_root+'[');
		@key = @path.split('.').pop()
		@parent = options.parent
		
		@link_watchers = []
		
		if options.container? then @setContainer(options.container)

	setContainer: (container) =>
		@container = container
		if @schema.id? then @container.setAttribute('data-schemaid',@schema.id)
		if @schema.type? and typeof @schema.type is "string" then @container.setAttribute('data-schematype',@schema.type)
		@container.setAttribute('data-schemapath',@path)

	preBuild: () =>

	build: () =>

	postBuild: () =>
		@setupWatchListeners()
		@addLinks()
		@setValue(@getDefault(), true)
		@updateHeaderText()
		@register()
		@onWatchedFieldChange()

	setupWatchListeners: () =>
		@watched = {}
		if @schema.vars? then @schema.watch = @schema.vars
		@watched_values = {}
		@watch_listener = () =>
			if @refreshWatchedFieldValues() then @onWatchedFieldChange()
		@register()
		if @schema.hasOwnProperty('watch') #???
			for (path in @schema.watch)
				path = @schema.watch[name]
				if Array.isArray(path)
					path_parts = [path[0]].concat(path[1].split('.'))
				else
					path_parts = path.split('.')
					if not @theme.closest(@container,'[data-schemaid="'+path_parts[0]+'"]')) then path_parts.unshift('#')
				first = path_parts.shift()
				if first is '#' then first = @jsoneditor.schema.id ? 'root' # ? or or
				# Find the root node for this template variable
				root = @theme.closest(@container,"[data-schemaid='#{first}']")
				if not root? then throw "Could not find ancestor node with id #{first}"
				# Keep track of the root node and path for use when rendering the template
				adjusted_path = root.getAttribute('data-schemapath') + '.' + path_parts.join('.')
				@jsoneditor.watch(adjusted_path,@watch_listener)
				@watched[name] = adjusted_path
		# Dynamic header
		if @schema.headerTemplate?
			@header_template = @jsoneditor.compileTemplate(@schema.headerTemplate, @template_engine);

	addLinks: () =>
		if not @no_link_holder?
			@link_holder = @theme.getLinksHolder()
			@container.appendChild(@link_holder)
			if @schema.links?
				for link in @schema.links
					@addLink(@getLink(link))

	getButton: (text, icon, title) =>
		btnClass = 'json-editor-btn-#{icon}'
		icon = @getIcon(icon)
		if not icon? and title?
			text = title
			title = null
		btn = @theme.getButton(text, icon, title)
		btn.className += ' ' + btnClass + ' '
		btn

	setButtonText: (button, text, icon, title) =>
		icon = @getIcon(icon)
		if not icon? and title?
			text = title
			title = null
		@theme.setButtonText(button, text, icon, title)

	getIcon: (icon) => if not @iconlib? then null else @iconlib.getIcon(icon)

	getLink: (data) =>
		mime = data.mediaType ? 'application/javascript'
		type = mime.split('/')[0]
		href = @jsoneditor.compileTemplate(data.href,@template_engine)
		if type is 'image'
			holder = @theme.getBlockLinkHolder()
			link = document.createElement('a')
			link.setAttribute('target','_blank')
			image = document.createElement('img')
			@theme.createImageLink(holder,link,image)
			# When a watched field changes, update the url  
			@link_watchers.push((vars) =>
				url = href(vars)
				link.setAttribute('href',url)
				link.setAttribute('title',data.rel ? url)
				image.setAttribute('src',url)
			)
		# Audio/Video links
		else if ['audio','video'].indexOf(type) >=0
			holder = @theme.getBlockLinkHolder()
			link = @theme.getBlockLink()
			link.setAttribute('target','_blank')
			media = document.createElement(type)
			media.setAttribute('controls','controls')
			@theme.createMediaLink(holder,link,media)
			@link_watchers.push((vars) =>
				url = href(vars)
				link.setAttribute('href',url)
				link.textContent = data.rel ? url
				media.setAttribute('src',url)
			)
		# Text links
		else 
			holder = @theme.getBlockLink()
			holder.setAttribute('target','_blank')
			holder.textContent = data.rel
			@link_watchers.push((vars) =>
				url = href(vars)
				holder.setAttribute('href',url)
				holder.textContent = data.rel ? url
			)
		 holder

	refreshWatchedFieldValues: () =>
		if @watched_values?
			watched = {}
			changed = false
			if @watched?
				for own name,w in @watched
					editor = @jsoneditor.getEditor(w)
					val = if editor? then editor.getValue() else null
					if @watched_values[name] isnt val then changed = true
					watched[name] = val
			watched.self = @getValue() # ??? self?
			if @watched_values.self isnt watched.self then changed = true
			@watched_values = watched
		changed

	getWatchedFieldValues: () => @watched_values

	updateHeaderText: () =>
		if @header? then @header.textContent = @getHeaderText()

	getHeaderText: (titleOnly) =>
		if @header_text?
			@header_text
		else if titleOnly?
			@schema.title
		else
			@getTitle()

	onWatchedFieldChange: () =>
		if @header_template?
			vars = $extend(@getWatchedFieldValues(),{
				key: @key
				i: @key
				i0: (@key*1)
				i1: (@key*1+1)
				title: @getTitle()
			})
			headerText = @header_template(vars)
			if headerText isnt @header_text
				@header_text = headerText;
				@updateHeaderText();
				@notify();
				# @fireChangeHeaderEvent();

		if @link_watchers.length? #??? length?
			vars = @getWatchedFieldValues()
			w(vars) for w in @link_watchers

	setValue: (@value) =>

	getValue: () => @value

	refreshValue: () =>

	getChildEditors: () => false

	destroy: () =>
		@unregister(@)
		$each(@watched,(name,adjustedPath) =>
			@jsoneditor.unwatch(adjustedPath,@watch_listener)
		)
		if @container?.parentNode then @container.parentNode.removeChild(@container)
		for own key,value of @
			@[key] = undefined

	getDefault: () =>
		if @schema.default?
			@schema.default
		else if @schema.enum? 
			@schema.enum[0]
		else
			type = @schema.type ? @schema.oneOf
			if type?
				if Array.isArray(type) then type = type[0]
				if typeof type is "object" then type = type.type
				if Array.isArray(type) then type = type[0]
			if typeof type is "string"
				switch expr
					when "number" then 0.0
					when "boolean" then false
					when "integer" then 0
					when "string" then false
					when "object" then {}
					when "array" then []
					else null
			else
				null

	getTitle: () => @schema.title ? @key

	enable: () =>  @disabled = false

	disable: () => @disabled = true

	isEnabled: () => not @disabled

	getDisplayText: (arr) =>
		disp = []
		used = {}
		attrCount = (txt) ->
			if txt?
				used[txt] = used[txt] ? 0
				used[txt] = used[txt] + 1
		# Determine how many times each attribute name is used.
		# This helps us pick the most distinct display text for the schemas.
		$each(arr,(i,el) =>
			attrCount(el.title)
			attrCount(el.description)
			attrCount(el.format)
			attrCount(el.type)
		)
		#Determine display text for each element of the array
		$each(arr,(i,el) =>
			# If it's a simple string
			name =
			if typeof el is "string" then el
			else if el.title and used[el.title]<=1) then el.title
			else if el.format and used[el.format]<=1)then el.format
			else if el.type and used[el.type]<=1) then el.type
			else if el.description and used[el.description]<=1) then el.descripton
			else if el.title then el.title
			else if el.format then el.format
			else if el.type then el.type
			else if el.description then el.description
			else if JSON.stringify(el).length < 50 then JSON.stringify(el)
			else "type"
			disp.push(name)
		)
		# Replace identical display text with "text 1", "text 2", etc.
		inc = {}
		$each(disp,(i,name) =>
			inc[name] = inc[name] ? 0
			inc[name] = inc[name] = 1
			if used[name] > 1 then disp[i] = name + " " + inc[name]
		)

	getOption: (key) =>
		try
			throw "getOption is deprecated";
		catch e
			console.error(e)

	showValidationErrors: (errors) =>
 
