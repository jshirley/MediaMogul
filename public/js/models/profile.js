YUI.add('mm-model-profile', function(Y) {
    var NS   = Y.namespace('MM.Model'),
        Sync = NS.Sync,

        Model;

    Model = Y.Base.create('profile', Y.Model, [ Sync ], {
    }, {
        ATTRS : {
            'key'        : { },
            'template'   : { },
            'stash'      : { value : { } }
        }
    });

    NS.Profile = Model;

}, '0.1.0', {
    requires : [ 'model' ]
});
