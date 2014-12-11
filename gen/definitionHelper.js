var DefinitionHelper;

DefinitionHelper = (function() {

  function DefinitionHelper() {}

  DefinitionHelper.getDefinitions = function(refs, schema, path) {
    var d, k, _ref, _results;
    path = path || '#/definitions/';
    if (schema.definitions != null) {
      _ref = schema.definitions;
      _results = [];
      for (k in _ref) {
        d = _ref[k];
        refs[path + k] = d;
        if (d.definitions != null) {
          _results.push(DefinitionHelper.getDefinitions(d, path + k + '/definitions/'));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    }
  };

  DefinitionHelper.getExternalRefs = function(refs, schema) {
    var mergeRefs, rs, sk, sv, v, _i, _len;
    rs = {};
    mergeRefs = function(newrefs) {
      var k, v, _i, _len, _results;
      _results = [];
      for (v = _i = 0, _len = newrefs.length; _i < _len; v = ++_i) {
        k = newrefs[v];
        _results.push(rs[k] = true);
      }
      return _results;
    };
    if ((schema.$ref != null) && schema.$ref.substr(0, 1) !== "#" && !(refs[schema.$ref] != null)) {
      rs[schema.$ref] = true;
    }
    for (sk in schema) {
      sv = schema[sk];
      if ((sv != null) && typeof sv === "object" && Array.isArray(sv)) {
        for (_i = 0, _len = sv.length; _i < _len; _i++) {
          v = sv[_i];
          if (typeof v === "object") {
            mergeRefs(DefinitionHelper.getExternalRefs(refs, v));
          }
        }
      } else if ((sv != null) && typeof sv === "object") {
        mergeRefs(DefinitionHelper.getExternalRefs(refs, sv));
      }
    }
    return rs;
  };

  DefinitionHelper.loadExternalRefs = function(refs, schema, callback) {
    var callbackFired, done, rs, waiting;
    rs = DefinitionHelper.getExternalRefs(refs, schema);
    done = 0;
    waiting = 0;
    callbackFired = false;
    $each(rs, function(url) {
      var r;
      if (refs[url] != null) {
        return;
      }
      if (!(self.options.ajax != null)) {
        throw "Must set ajax option to true to load external ref " + url;
      }
      refs[url] = 'loading';
      waiting = waiting + 1;
      r = new XMLHttpRequest();
      r.open("GET", url, true);
      return r.onreadystatechange = function() {
        var response;
        if (r.readyState !== 4) {
          return;
        }
        if (r.status === 200) {
          try {
            response = JSON.parse(r.responseText);
          } catch (e) {
            window.console.log(e);
            throw "Failed to parse external ref " + url;
          }
          if (!(response != null) || typeof response !== "object") {
            throw "External ref does not contain a valid schema - " + url;
          }
          refs[url] = response;
          return DefinitionHelper.loadExternalRefs(refs, response, function() {
            done = done + 1;
            if (done >= waiting && !callbackFired) {
              callbackFired = true;
              return callback();
            }
          });
        } else {
          window.console.log(r);
          throw "Failed to fetch ref via ajax- " + url;
        }
      };
    });
    if (!waiting) {
      return callback();
    }
  };

  DefinitionHelper.expandRefs = function(refs, schema) {
    var ref;
    schema = $extend({}, schema);
    while (schema.$ref != null) {
      ref = schema.$ref;
      delete schema.$ref;
      schema = DefinitionHelper.extendSchemas(schema, refs[ref]);
    }
    return schema;
  };

  DefinitionHelper.expandSchema = function(schema) {
    var ao, ex, extended, oo, tmp, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2;
    extended = $extend({}, schema);
    if (typeof schema.type === 'object') {
      if (Array.isArray(schema.type)) {
        $each(schema.type, function(key, value) {
          if (typeof value === 'object') {
            return schema.type[key] = DefinitionHelper.expandSchema(value);
          }
        });
      }
    } else {
      schema.type = DefinitionHelper.expandSchema(schema.type);
    }
    if (typeof schema.disallow === 'object') {
      if (Array.isArray(schema.disallow)) {
        $each(schema.disallow, function(key, value) {
          if (typeof value === 'object') {
            return schema.disallow[key] = DefinitionHelper.expandSchema(value);
          }
        });
      }
    } else {
      schema.disallow = DefinitionHelper.expandSchema(schema.disallow);
    }
    if (schema.anyOf != null) {
      $each(schema.anyOf, function(key, value) {
        return schema.anyOf[key] = DefinitionHelper.expandSchema(value);
      });
    }
    if (schema.dependencies != null) {
      $each(schema.dependencies, function(key, value) {
        if (typeof value === "object" && !Array.isArray(value)) {
          return schema.dependencies[key] = DefinitionHelper.expandSchema(value);
        }
      });
    }
    if (schema.not != null) {
      schema.not = DefinitionHelper.expandSchema(schema.not);
    }
    if (schema.allOf != null) {
      _ref = schema.allOf;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        ao = _ref[_i];
        extended = DefinitionHelper.extendSchemas(extended, DefinitionHelper.expandSchema(ao));
      }
      delete extended.allOf;
    }
    if (schema["extends"] != null) {
      if (!Array.isArray(schema["extends"])) {
        extended = DefinitionHelper.extendSchemas(extended, DefinitionHelper.expandSchema(schema["extends"]));
      } else {
        _ref1 = schema["extends"];
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          ex = _ref1[_j];
          extended = DefinitionHelper.extendSchemas(extended, this.expandSchema(ex));
        }
      }
      delete extended["extends"];
    }
    if (schema.oneOf != null) {
      tmp = $extend({}, extended);
      delete tmp.oneOf;
      _ref2 = schema.oneOf;
      for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
        oo = _ref2[_k];
        extended.oneOf[i] = DefinitionHelper.extendSchemas(DefinitionHelper.expandSchema(oo), tmp);
      }
    }
    return DefinitionHelper.expandRefs(extended);
  };

  DefinitionHelper.extendSchemas = function(obj1, obj2) {
    var extended;
    obj1 = $extend({}, obj1);
    obj2 = $extend({}, obj2);
    extended = {};
    $each(obj1, function(prop, val) {
      if (typeof obj2[prop] !== "undefined") {
        if (prop === 'required' && typeof val === "object" && Array.isArray(val)) {
          return extended.required = val.concat(obj2[prop]).reduce(function(p, c) {
            if (p.indexOf(c) < 0) {
              p.push(c);
            }
            return p;
          }, []);
        } else if (prop === 'type' && (typeof val === "string" || Array.isArray(val))) {
          if (typeof val === "string") {
            val = [val];
          }
          if (typeof obj2.type === "string") {
            obj2.type = [obj2.type];
          }
          extended.type = val.filter(function(n) {
            return obj2.type.indexOf(n) !== -1;
          });
          if (extended.type.length === 1 && typeof extended.type[0] === "string") {
            return extended.type = extended.type[0];
          }
        } else if (typeof val === "object" && Array.isArray(val)) {
          return extended[prop] = val.filter(function(n) {
            return obj2[prop].indexOf(n) !== -1;
          });
        } else if (typeof val === "object" && val !== null) {
          return extended[prop] = DefinitionHelper.extendSchemas(val, obj2[prop]);
        } else {
          return extended[prop] = val;
        }
      } else {
        return extended[prop] = val;
      }
    });
    $each(obj2, function(prop, val) {
      if (typeof obj1[prop] === "undefined") {
        return extended[prop] = val;
      }
    });
    return extended;
  };

  return DefinitionHelper;

})();
