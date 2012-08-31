YUI.add('mm-model-template', function(Y) {
    var NS   = Y.namespace('MM.Model'),
        Sync = NS.Sync,

        Model;

    Model = Y.Base.create('template', Y.Model, [ Sync ], {
        renderer : null,

        render : function() { }
    }, {
        ATTRS : {
            'type'       : { value : 'handlebars' },
            'key'        : { },
            'stash'      : { value : { } }
        }
    });

    NS.Template = Model;

}, '0.1.0', {
    requires : [ 'model' ]
});
