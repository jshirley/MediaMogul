var fs     = require('fs'),
    path   = require('path'),
    file   = require('file'),
    config = require('config'),

    cache  = { layouts : { } },

    useCache = config.templates.cache;

module.exports = function(Y) {
    Y.Handlebars.registerHelper('withLayout', function(context, options) {
        var template = cache.layouts[context];
        if ( !template ) {
            template = getRaw()[context];
            if ( template ) {
                template = cache.layouts[context] = Y.Handlebars.compile( template );
            }
        }
        if ( typeof template !== 'function' ) {
            Y.log('Unable to fetch template for layout ' + context + ', make sure it exists?');
            return '';
        }

        return template({ body : options.fn(this) });
    });

    function getRaw() {
        if (cache.raw) {
            return Y.merge(cache.raw);
        }

        var raw         = {},
            templateDir = config.templates.dir,
            files       = fs.existsSync(templateDir) && fs.readdirSync(templateDir, 'utf8');

        if (files && files.length) {
            files.forEach(function (file) {
                var ext = path.extname(file);
                if ( ext === '.handlebars' || ext === '.html' ) {
                    var name     = file.replace(/.handlebars$/, '').replace(/.html$/, ''),
                        template = fs.readFileSync(path.join(templateDir, file), 'utf8');

                    raw[name] = template;
                }
            });
        }

        if ( useCache ) {
            cache.raw = Y.merge(raw);
        }

        return raw;
    }

    exports.getRaw = getRaw;

    function getPrecompiled() {
        if ( cache.precompiled ) {
            return Y.merge( cache.precompiled );
        }

        var precompiled = {};

        Y.Object.each( getRaw(), function( template, name ) {
            precompiled[name] = Y.Handlebars.precompile( template );
        });

        if ( useCache ) {
            cache.precompiled = Y.merge(precompiled);
        }

        return precompiled;
    }

    exports.getPrecompiled = getPrecompiled;

    return exports;
};
