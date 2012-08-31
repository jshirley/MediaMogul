YUI.add('mm-model-list-media', function(Y) {
    var NS   = Y.namespace('MM.Model'),
        Sync = NS.Sync,

        Model;

    Model = Y.Base.create('mediaList', Y.Model, [ Sync ], {
        model : NS.Media
    }, {
        ATTRS : {
        }
    });

    NS.MediaList = Model;

}, '0.1.0', {
    requires : [ 'model-list', 'mm-model-media' ]
});
