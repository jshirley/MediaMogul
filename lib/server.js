var config  = require('config'),
    http    = require('http'),

    connect = require('connect'),
    express = require('express'),

    combo   = require('combohandler'),

    path    = require('path'),
    pubDir  = path.join(__dirname, '../', config.pubDir),
    static  = express.static(pubDir),

    //static  = require('./client/lib/middleware/static'),
    //combo   = require('./client/lib/middleware/combohandler'),

    YUI     = require('yui').YUI,


    Y       = YUI(config.yui.node),

    //modelLoader = require('./client/lib/middleware/loader'),
    //requireAuth = require('./client/lib/middleware/auth'),

    app = express();

/**
TODO: Find out what the proper way of doing URL transfoms is.

I don't want to have to abide by $name/$name-$filter.js for my custom
modules.
**/
Y.Loader.prototype._url = function(path, name, base) {
    if ( path.match(/^mm-/) ) {
        path = path.replace(/^mm-(view|model)-.+\//, '$1/');
        path = path.replace(/\/mm-(view|model)-/, '/');
        path = path.replace('-min.js', '.js');
    }
    return this._filter((base || this.base || '') + path, name);
};

Y.use('parallel', 'handlebars', 'json', 'model-sync-rest');

Y.namespace('MM.Model').Sync = Y.ModelSync.REST;

app.configure('development', function() {
    app.use(express.errorHandler({
        dumpExceptions: true,
        showStack     : true
    }));
});

app.configure(function() {
    app.set('strict routing', true);

    app.engine('handlebars', require('./handlebars')(Y) );
    app.set('view engine', 'handlebars');

    /*
    app.set('view options',
        Y.merge(require('./config/common'), { config: global.config })
    );
    */

    //app.use( require('./client/lib/middleware/proxy') );
    app.use( express.cookieParser() );
    Y.log('Static dir is: ' + path.join(__dirname, '../', config.pubDir));
    app.use( '/static', static );
    app.use( express.favicon() );
    app.use( express.bodyParser() );
    app.use( app.router );
});

app.get('/combo',
    combo.combine({ rootPath : pubDir + '/js' }),
    function(req, res) {
        if ( connect.utils.conditionalGET(req) ) {
            if ( !connect.utils.modified(req,res) ) {
                return connect.utils.notModified( res );
            }
        }

        res.send(res.body, 200);
    }
);

// Precompile templates, and serve them up in a rendered template rollup file
app.get('/templates.js', function(req, res, next) {
    var precompiled = require('./templates')(Y).getPrecompiled(),
        templates = [];

    Y.Object.each( precompiled, function(template, name) {
        templates.push({
            name     : name,
            template : template
        });
    });

    res.set('Content-Type', 'application/javascript');

    res.render('templates', {
        templates : templates
    }, function(err, view) {
        if ( err ) {
            console.log('Error rendering templates:');
            console.log(err);
            return next();
        }

        var minifiy, templates;

        if ( app.enabled('minify templates') ) {
            minify    = require('uglify-js');
            templates = minify(view);
        } else {
            templates = view;
        }

        res.send(templates, { 'Content-Type' : 'application/javascript' }, 200 );
    });
});

app.get('/', function(req, res) {
    res.render('index');
});

/*
app.get('/embed/:key/:profile');
app.get('/media/:key/:profile/*');
*/

module.exports = app;
