var JSONEditor,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty;

JSONEditor = (function() {
  var key, value;

  JSONEditor.defaults = function() {
    return {
      themes: {},
      templates: {},
      iconlibs: {},
      editors: {},
      languages: {},
      resolvers: [],
      custom_validators: []
    };
  };

  function JSONEditor(element, options) {
    this.element = element;
    this.checkReady = __bind(this.checkReady, this);

    this.disable = __bind(this.disable, this);

    this.enable = __bind(this.enable, this);

    this.isEnabled = __bind(this.isEnabled, this);

    this.notifyWatchers = __bind(this.notifyWatchers, this);

    this.unwatch = __bind(this.unwatch, this);

    this.watch = __bind(this.watch, this);

    this.getEditor = __bind(this.getEditor, this);

    this.unregisterEditor = __bind(this.unregisterEditor, this);

    this.registerEditor = __bind(this.registerEditor, this);

    this._data = __bind(this._data, this);

    this.compileTemplate = __bind(this.compileTemplate, this);

    this.onChange = __bind(this.onChange, this);

    this.createEditor = __bind(this.createEditor, this);

    this.getEditorClass = __bind(this.getEditorClass, this);

    this.setOption = __bind(this.setOption, this);

    this.trigger = __bind(this.trigger, this);

    this.off = __bind(this.off, this);

    this.on = __bind(this.on, this);

    this.destroy = __bind(this.destroy, this);

    this.validate = __bind(this.validate, this);

    this.setValue = __bind(this.setValue, this);

    this.getValue = __bind(this.getValue, this);

    this.init = __bind(this.init, this);

    this.options = _.extend(JSONEditor.defaults.options, options);
    this.init();
  }

  JSONEditor.prototype.init = function() {
    var icon_class, theme_class,
      _this = this;
    this.ready = false;
    theme_class = JSONEditor.defaults.themes[this.options.theme || JSONEditor.defaults.theme];
    if (!(theme_class != null)) {
      throw "Unknown theme " + (this.options.theme || JSONEditor.defaults.theme);
    }
    this.schema = this.options.schema;
    this.theme = new theme_class();
    this.template = this.options.template;
    this.refs = this.options.refs || {};
    this.uuid = 0;
    this.__data = {};
    icon_class = JSONEditor.defaults.iconlibs[this.options.iconlib || JSONEditor.defaults.iconlib];
    if (icon_class != null) {
      this.iconlib = new icon_class();
    }
    this.root_container = this.theme.getContainer();
    this.element.appendChild(this.root_container);
    this.translate = this.options.translate || JSONEditor.defaults.translate;
    return DefinitionHelper.loadExternalRefs(this.refs, this.schema, function() {
      var editor_class;
      DefinitionHelper.getDefinitions(_this.schema);
      _this.validator = new JSONEditor.Validator(self);
      editor_class = _this.getEditorClass(_this.schema);
      _this.root = _this.createEditor(editor_class, {
        jsoneditor: self,
        schema: _this.schema,
        required: true,
        container: _this.root_container
      });
      _this.root.preBuild();
      _this.root.build();
      _this.root.postBuild();
      if (_this.options.startval != null) {
        _this.root.setValue(_this.options.startval);
      }
      _this.validation_results = _this.validator.validate(_this.root.getValue());
      _this.root.showValidationErrors(_this.validation_results);
      _this.ready = true;
      return window.requestAnimationFrame(function() {
        if (!_this.ready) {
          return;
        }
        _this.validation_results = _this.validator.validate(_this.root.getValue());
        _this.root.showValidationErrors(_this.validation_results);
        _this.trigger('ready');
        return _this.trigger('change');
      });
    });
  };

  JSONEditor.prototype.getValue = function() {
    this.checkReady("getting the value");
    return this.root.getValue();
  };

  JSONEditor.prototype.setValue = function(value) {
    this.checkReady("setting the value");
    this.root.setValue(value);
    return this;
  };

  JSONEditor.prototype.validate = function(value) {
    this.checkReady("validating");
    if (arguments.length === 1) {
      return this.validator.validate(value);
    } else {
      return this.validation_results;
    }
  };

  JSONEditor.prototype.destroy = function() {
    if (this.destroyed) {
      return;
    }
    if (!this.ready) {

    }
  };

  JSONEditor.element.innerHTML = '';

  JSONEditor.root.destroy();

  for (key in JSONEditor) {
    if (!__hasProp.call(JSONEditor, key)) continue;
    value = JSONEditor[key];
    JSONEditor[key] = void 0;
  }

  JSONEditor.prototype.on = function(evt, callback) {
    this.callbacks = this.callbacks || {};
    this.callbacks[evt] = this.callbacks[evt] || [];
    this.callbacks[evt].push(callback);
    return this;
  };

  JSONEditor.prototype.off = function(evt, callback) {
    var c, i, newcallbacks, _i, _len, _ref;
    if ((evt != null) && (callback != null)) {
      this.callbacks = this.callbacks || {};
      this.callbacks[evt] = this.callbacks[evt] || [];
      newcallbacks = [];
      _ref = this.callbacks[evt];
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        c = _ref[i];
        if (c[i] === callback) {
          continue;
        }
        newcallbacks.push(c[i]);
      }
      this.callbacks[evt] = newcallbacks;
    } else if (evt != null) {
      this.callbacks = this.callbacks || {};
      this.callbacks[evt] = [];
    } else {
      this.callbacks = {};
    }
    return this;
  };

  JSONEditor.prototype.trigger = function(evt) {
    var c, _i, _len, _ref;
    if ((this.callbacks != null) && (this.callbacks[evt] != null)) {
      _ref = this.callbacks[evt];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        c = _ref[_i];
        c();
      }
    }
    return this;
  };

  JSONEditor.prototype.setOption = function(option, value) {
    if (option === "show_errors") {
      this.options.show_errors = value;
      this.onChange();
    } else {
      throw "Option " + option + " must be set during instantiation and cannot be changed later";
    }
    return this;
  };

  JSONEditor.prototype.getEditorClass = function(schema) {
    var _this = this;
    schema = this.expandSchema(schema);
    $each(JSONEditor.defaults.resolvers, function(i, resolver) {
      var classname, tmp;
      tmp = resolver(schema);
      if (tmp != null) {
        if (JSONEditor.defaults.editors[tmp] != null) {
          classname = tmp;
          return false;
        }
      }
    });
    if (!(typeof classname !== "undefined" && classname !== null)) {
      throw "Unknown editor for schema " + JSON.stringify(schema);
    }
    if (!(JSONEditor.defaults.editors[classname] != null)) {
      throw "Unknown editor " + classname;
    }
    return JSONEditor.defaults.editors[classname];
  };

  JSONEditor.prototype.createEditor = function(editor_class, options) {
    options = $extend({}, editor_class.options || {}, options);
    return new editor_class(options);
  };

  JSONEditor.prototype.onChange = function() {
    var _this = this;
    if (!this.ready) {
      return;
    }
    if (this.firing_change) {
      return;
    }
    this.firing_change = true;
    return window.requestAnimationFrame(function() {
      _this.firing_change = false;
      if (!_this.ready) {
        return;
      }
      _this.validation_results = _this.validator.validate(_this.root.getValue());
      if (_this.options.show_errors !== "never") {
        _this.root.showValidationErrors(_this.validation_results);
      } else {
        _this.root.showValidationErrors([]);
      }
      return _this.trigger('change');
    });
  };

  JSONEditor.prototype.compileTemplate = function(template, name) {
    var engine;
    name = name || JSONEditor.defaults.template;
    if (typeof name === 'string') {
      if (!(JSONEditor.defaults.templates[name] != null)) {
        throw "Unknown template engine " + name;
      }
      engine = JSONEditor.defaults.templates[name]();
      if (!engine) {
        throw "Template engine " + name + " missing required library.";
      }
    } else {
      engine = name;
    }
    if (!(engine != null)) {
      throw "No template engine set";
    }
    if (!(engine.compile != null)) {
      throw "Invalid template engine set";
    }
    return engine.compile(template);
  };

  JSONEditor.prototype._data = function(el, key, value) {
    var uuid;
    if (arguments.length === 3) {
      if (el.hasAttribute('data-jsoneditor-#{key}') != null) {
        uuid = el.getAttribute('data-jsoneditor-#{key}');
      } else {
        uuid = this.uuid + 1;
        el.setAttribute('data-jsoneditor-#{key}', uuid);
      }
      return this.__data[uuid] = value;
    } else {
      if (!(el.hasAttribute("data-jsoneditor-" + key) != null)) {
        return null;
      }
      return this.__data[el.getAttribute('data-jsoneditor-#{key}')];
    }
  };

  JSONEditor.prototype.registerEditor = function(editor) {
    this.editors = this.editors || {};
    this.editors[editor.path] = editor;
    return this;
  };

  JSONEditor.prototype.unregisterEditor = function(editor) {
    this.editors = this.editors || {};
    this.editors[editor.path] = null;
    return this;
  };

  JSONEditor.prototype.getEditor = function(path) {
    if (!(this.editors != null)) {
      return;
    }
    return this.editors[path];
  };

  JSONEditor.prototype.watch = function(path, callback) {
    this.watchlist = this.watchlist || {};
    this.watchlist[path] = this.watchlist[path] || [];
    this.watchlist[path].push(callback);
    return this;
  };

  JSONEditor.prototype.unwatch = function(path, callback) {
    var i, newlist, w, _i, _len, _ref;
    if (!(this.watchlist != null) || !(this.watchlist[path] != null)) {
      return this;
    }
    if (!(callback != null)) {
      this.watchlist[path] = null;
      return this;
    }
    newlist = [];
    _ref = this.watchlist[path];
    for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
      w = _ref[i];
      if (w[i] === callback) {
        continue;
      } else {
        newlist.push(w);
      }
    }
    this.watchlist[path] = newlist.length != null ? newlist : null;
    return this;
  };

  JSONEditor.prototype.notifyWatchers = function(path) {
    var i, w, _i, _len, _ref, _results;
    if (!(this.watchlist != null) || !(this.watchlist[path] != null)) {
      return this;
    }
    _ref = this.watchlist[path];
    _results = [];
    for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
      w = _ref[i];
      _results.push(w[i]());
    }
    return _results;
  };

  JSONEditor.prototype.isEnabled = function() {
    var _ref;
    return (_ref = this.root) != null ? _ref.isEnabled() : void 0;
  };

  JSONEditor.prototype.enable = function() {
    return this.root.enable();
  };

  JSONEditor.prototype.disable = function() {
    return this.root.disable();
  };

  JSONEditor.prototype.checkReady = function(msg) {
    if (!this.ready) {
      throw "JSON Editor not ready yet.  Listen for 'ready' event before getting the " + msg;
    }
  };

  return JSONEditor;

})();
