class EditorDefaults

	@defaults:
		# Set the default theme
		theme : 'html'
		# Set the default template engine
		template : 'default'
		# Default options when initializing JSON Editor
		options : {}
		# String translate function
		translate : (key, variables) ->
			lang = EditorDefaults.defaults.languages[EditorDefaults.defaults.language]
			if not lang then throw "Unknown language #{EditorDefaults.defaults.language}"
			
			string = lang[key] or EditorDefaults.defaults.languages[EditorDefaults.defaults.default_language][key]
			
			if not string? then throw "Unknown translate string #{key}"
			
			if variables?
				for v in variables
					string = string.replace(new RegExp('\\{\\{'+i+'}}','g'),v)
			string
		# Translation strings and default languages
		default_language : 'en'
		language : EditorDefaults.defaults.default_language
		languages:
			en :
				#
				# When a property is not set
				#
				error_notset: "Property must be set",
				#
				# When a string must not be empty
				#
				error_notempty: "Value required",
				#
				# When a value is not one of the enumerated values
				#
				error_enum: "Value must be one of the enumerated values",
				#
				# When a value doesn't validate any schema of a 'anyOf' combination
				#
				error_anyOf: "Value must validate against at least one of the provided schemas",
				#
				# When a value doesn't validate
				# @variables This key takes one variable: The number of schemas the value does not validate
				#
				error_oneOf: 'Value must validate against exactly one of the provided schemas. It currently validates against {{0}} of the schemas.',
				#
				# When a value does not validate a 'not' schema
				#
				error_not: "Value must not validate against the provided schema",
				#
				# When a value does not match any of the provided types
				#
				error_type_union: "Value must be one of the provided types",
				#
				# When a value does not match the given type
				# @variables This key takes one variable: The type the value should be of
				#
				error_type: "Value must be of type {{0}}",
				#
				#  When the value validates one of the disallowed types
				#
				error_disallow_union: "Value must not be one of the provided disallowed types",
				#
				#  When the value validates a disallowed type
				# @variables This key takes one variable: The type the value should not be of
				#
				error_disallow: "Value must not be of type {{0}}",
				#
				# When a value is not a multiple of or divisible by a given number
				# @variables This key takes one variable: The number mentioned above
				#
				error_multipleOf: "Value must be a multiple of {{0}}",
				#
				# When a value is greater than it's supposed to be (exclusive)
				# @variables This key takes one variable: The maximum
				#
				error_maximum_excl: "Value must be less than {{0}}",
				#
				# When a value is greater than it's supposed to be (inclusive
				# @variables This key takes one variable: The maximum
				#
				error_maximum_incl: "Value must at most {{0}}",
				#
				# When a value is lesser than it's supposed to be (exclusive)
				# @variables This key takes one variable: The minimum
				#
				error_minimum_excl: "Value must be greater than {{0}}",
				#
				# When a value is lesser than it's supposed to be (inclusive)
				# @variables This key takes one variable: The minimum
				#
				error_minimum_incl: "Value must be at least {{0}}",
				#
				# When a value have too many characters
				# @variables This key takes one variable: The maximum character count
				#
				error_maxLength: "Value must be at most {{0}} characters long",
				#
				# When a value does not have enough characters
				# @variables This key takes one variable: The minimum character count
				#
				error_minLength: "Value must be at least {{0}} characters long",
				#
				# When a value does not match a given pattern
				#
				error_pattern: "Value must match the provided pattern",
				#
				# When an array has additional items whereas it is not supposed to
				#
				error_additionalItems: "No additional items allowed in this array",
				#
				# When there are to many items in an array
				# @variables This key takes one variable: The maximum item count
				#
				error_maxItems: "Value must have at most {{0}} items",
				#
				# When there are not enough items in an array
				# @variables This key takes one variable: The minimum item count
				#
				error_minItems: "Value must have at least {{0}} items",
				#
				# When an array is supposed to have unique items but has duplicates
				#
				error_uniqueItems: "Array must have unique items",
				#
				# When there are too many properties in an object
				# @variables This key takes one variable: The maximum property count
				#
				error_maxProperties: "Object must have at most {{0}} properties",
				#
				# When there are not enough properties in an object
				# @variables This key takes one variable: The minimum property count
				#
				error_minProperties: "Object must have at least {{0}} properties",
				#
				# When a required property is not defined
				# @variables This key takes one variable: The name of the missing property
				#
				error_required: "Object is missing the required property '{{0}}'",
				#
				# When there is an additional property is set whereas there should be none
				# @variables This key takes one variable: The name of the additional property
				#
				error_additional_properties: "No additional properties allowed, but property {{0}} is set",
				#
				# When a dependency is not resolved
				# @variables This key takes one variable: The name of the missing property for the dependency
				#
				error_dependency: "Must have property {{0}}"


	# Miscellaneous Plugin Settings
	plugins :
		ace:
			theme: ''
		epiceditor: {}
		sceditor: {}
		select2: {}


		# Default per-editor options
		for e in EditorDefaults.defaults.editors
			e.options = EditorDefaults.defaults.editors.options or {}

		# Set the default resolvers
		# Use "multiple" as a fall back for everything
		resolvers.unshift((schema) ->
			if typeof schema.type isnt "string" then "multiple"
		)
		# If the type is set and it's a basic type, use the primitive editor
		resolvers.unshift((schema) ->
			# If the schema is a simple type
			if typeof schema.type is "string" then schema.type
		)
		# Use the select editor for all boolean values
		resolvers.unshift((schema) ->
			if schema.type is 'boolean'then "select"
		)
		# Use the multiple editor for schemas where the `type` is set to "any"
		resolvers.unshift((schema) ->
			# If the schema can be of any type
			if schema.type is "any" then "multiple"
		)
		# Editor for base64 encoded files
		resolvers.unshift((schema) ->
			# If the schema can be of any type
			if schema.type is "string" and schema.media? and schema.media.binaryEncoding is "base64"
				"base64"
		)
		# Editor for uploading files
		resolvers.unshift((schema) ->
			if schema.type is "string" and schema.format is "url" and schema.options? and schema.options.upload is true
				if window.FileReader? then "upload"
		)
		# Use the table editor for arrays with the format set to `table`
		resolvers.unshift((schema) ->
			# Type `array` with format set to `table`
			if schema.type is "array" and schema.format is "table" then "table"
		)
		# Use the `select` editor for dynamic enumSource enums
		resolvers.unshift((schema) ->
			if schema.enumSource? then "select"
		)
		# Use the `enum` or `select` editors for schemas with enumerated properties
		resolvers.unshift((schema) ->
			if schema.enum?
				if schema.type is "array" or schema.type is "object"
					"enum"
				else if schema.type is "number" or schema.type is "integer" or schema.type is "string"
					"select"
		)
		# Use the 'multiselect' editor for arrays of enumerated strings/numbers/integers
		resolvers.unshift((schema) ->
			if schema.type is "array" and schema.items? and not(Array.isArray(schema.items)) and schema.uniqueItems? and schema.items.enum? and ['string','number','integer'].indexOf(schema.items.type) >= 0
				'multiselect'
		)
		# Use the multiple editor for schemas with `oneOf` set
		resolvers.unshift((schema) ->
			# If this schema uses `oneOf`
			if schema.oneOf? then "multiple"
		)
