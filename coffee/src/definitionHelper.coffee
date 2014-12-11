class DefinitionHelper

	@getDefinitions: (refs,schema,path) ->
		path = path or '#/definitions/'
		if schema.definitions?
			for k,d of schema.definitions
				refs[path+k] = d
				if d.definitions? then DefinitionHelper.getDefinitions(d,path+k+'/definitions/')

	@getExternalRefs: (refs,schema) ->
		rs = {}
		mergeRefs = (newrefs) ->
			for k,v in newrefs
				rs[k] = true
		if schema.$ref? and schema.$ref.substr(0,1) isnt "#" and not refs[schema.$ref]?
			rs[schema.$ref] = true

		for sk, sv of schema
			if sv? and typeof sv is "object" and Array.isArray(sv)
				for v in sv
					if typeof v is "object"
						mergeRefs(DefinitionHelper.getExternalRefs(refs,v))
			else if sv? and typeof sv is "object"
				mergeRefs(DefinitionHelper.getExternalRefs(refs,sv))
		rs

	@loadExternalRefs: (refs,schema,callback) ->
		rs = DefinitionHelper.getExternalRefs(refs,schema)
		done = 0
		waiting = 0
		callbackFired = false
		$each(rs,(url) ->
			if refs[url]? then return
			if not self.options.ajax? then throw "Must set ajax option to true to load external ref #{url}"
			refs[url] = 'loading'
			waiting = waiting + 1
			r = new XMLHttpRequest()
			r.open("GET", url, true)
			r.onreadystatechange = () ->
				if r.readyState isnt 4 then return
				if r.status is 200
					try
						response = JSON.parse(r.responseText)
					catch e
						window.console.log(e)
						throw "Failed to parse external ref #{url}"
					if not response? or typeof response isnt "object" then throw "External ref does not contain a valid schema - #{url}"
					refs[url] = response
					DefinitionHelper.loadExternalRefs(refs,response,() ->
						done = done + 1
						if done >= waiting and not callbackFired
							callbackFired = true
							callback()
					)
				else
					window.console.log(r)
					throw "Failed to fetch ref via ajax- #{url}"
		)
		if not waiting then callback()

	@expandRefs: (refs,schema) ->
		schema = $extend({},schema)
		while schema.$ref?
			ref = schema.$ref
			delete schema.$ref
			schema = DefinitionHelper.extendSchemas(schema,refs[ref])
		schema

	@expandSchema: (schema) ->
		extended = $extend({},schema)
		# Version 3 `type`
		if typeof schema.type is 'object'
			# Array of types
			if Array.isArray(schema.type)
				$each(schema.type, (key,value) ->
					#Schema
					if typeof value is 'object'
						schema.type[key] = DefinitionHelper.expandSchema(value)
				)
		# Schema
		else
			schema.type = DefinitionHelper.expandSchema(schema.type)

		# Version 3 `disallow`
		if typeof schema.disallow is 'object'
			# Array of types
			if Array.isArray(schema.disallow)
				$each(schema.disallow, (key,value) ->
					# Schema
					if typeof value is 'object'
						schema.disallow[key] = DefinitionHelper.expandSchema(value)
				)
			# Schema
		else
			schema.disallow = DefinitionHelper.expandSchema(schema.disallow)

		# Version 4 `anyOf`
		if schema.anyOf?
			$each(schema.anyOf, (key,value) ->
				schema.anyOf[key] = DefinitionHelper.expandSchema(value)
			)
		# Version 4 `dependencies` (schema dependencies)
		if schema.dependencies?
			$each(schema.dependencies,(key,value) ->
				if typeof value is "object" and not Array.isArray(value)
					schema.dependencies[key] = DefinitionHelper.expandSchema(value)
			)

		# Version 4 `not`
		if schema.not?
			schema.not = DefinitionHelper.expandSchema(schema.not)

		# allOf schemas should be merged into the parent
		if schema.allOf?
			for ao in schema.allOf
				extended = DefinitionHelper.extendSchemas(extended,DefinitionHelper.expandSchema(ao))
			delete extended.allOf

		# extends schemas should be merged into parent
		if schema.extends?
			# If extends is a schema
			if not Array.isArray(schema.extends)
				extended = DefinitionHelper.extendSchemas(extended,DefinitionHelper.expandSchema(schema.extends))
			# If extends is an array of schemas
			else
				for ex in schema.extends
					extended = DefinitionHelper.extendSchemas(extended,this.expandSchema(ex))
			delete extended.extends;
 
		# parent should be merged into oneOf schemas
		if schema.oneOf?
			tmp = $extend({},extended)
			delete tmp.oneOf
			for oo in schema.oneOf
				extended.oneOf[i] = DefinitionHelper.extendSchemas(DefinitionHelper.expandSchema(oo),tmp)
		DefinitionHelper.expandRefs(extended)

	@extendSchemas: (obj1,obj2) ->
		obj1 = $extend({},obj1)
		obj2 = $extend({},obj2)
		extended = {}
		$each(obj1, (prop,val) ->
			# If this key is also defined in obj2, merge them
			if typeof obj2[prop] isnt "undefined"
				# Required arrays should be unioned together
				if prop is'required' and typeof val is "object" and Array.isArray(val)
					#Union arrays and unique
					extended.required = val.concat(obj2[prop]).reduce((p, c) ->
						if p.indexOf(c) < 0 then p.push(c)
						p
					, [])
				# Type should be intersected and is either an array or string
				else if prop is 'type' and (typeof val is "string" or Array.isArray(val))
					# Make sure we're dealing with arrays
					if typeof val is "string" then val = [val]
					if typeof obj2.type is "string" then obj2.type = [obj2.type]
					extended.type = val.filter((n) ->
						obj2.type.indexOf(n) isnt -1
					)
					if extended.type.length is 1 and typeof extended.type[0] is "string"
						extended.type = extended.type[0]
				# All other arrays should be intersected (enum, etc.)
				else if typeof val is "object" and Array.isArray(val)
					extended[prop] = val.filter((n) ->
						obj2[prop].indexOf(n) isnt -1
					)
				# Objects should be recursively merged
				else if typeof val is "object"and val isnt null
					extended[prop] = DefinitionHelper.extendSchemas(val,obj2[prop])
				# Otherwise, use the first value
				else
					extended[prop] = val
			# Otherwise, just use the one in obj1
			else
				extended[prop] = val
		)
		#Properties in obj2 that aren't in obj1
		$each(obj2, (prop,val) ->
			if typeof obj1[prop] is "undefined" then extended[prop] = val
		)
		extended
