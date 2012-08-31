var fs        = require('fs');

module.exports = function(Y) {
    var templates = require('./templates')(Y);
/*
    return function( name, data ) {
        Y.log('Rendering...?');
        var raw      = templates.getRaw(),
            template = raw[name];

        if ( template ) {
            template = Y.Handlebars.compile(template);
            return template(data, { partials : raw });
        }
        return 'No template ' + name + ' found!';
    };

*/
    return function( filename, options, callback ) {
        fs.readFile( filename, 'utf8', function(err, str) {
            if ( err ) return fn(err);
            var template = Y.Handlebars.compile(str);
            callback( null, template(options, { partials : templates.getRaw() } ));
        } );
    };
};
