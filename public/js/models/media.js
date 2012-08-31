YUI.add('mm-model-media', function(Y) {
    var NS   = Y.namespace('MM.Model'),
        Sync = NS.Sync,

        Model;

    Model = Y.Base.create('media', Y.Model, [ Sync ], {

    }, {
        ATTRS : {
            'key'      : { },
            'type'     : { },
            'location' : { },
            'category' : { },
            'template' : { },
            'caption'  : { }
        }
    });

    NS.Media = Model;

}, '0.1.0', {
    requires : [ 'model' ]
});
