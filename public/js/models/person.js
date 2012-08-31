YUI.add('mm-model-person', function(Y) {
    var NS   = Y.namespace('MM.Model'),
        Sync = NS.Sync,

        Model;

    Model = Y.Base.create('person', Y.Model, [ Sync ], {
    }, {
        ATTRS : {
            'type'       : { },
            'location'   : { },
            'media'      : { valueFn : '_fetchMediaList' },
            'categories' : { valueFn : '_fetchCategoryList' }
        }
    });

    NS.Person = Model;

}, '0.1.0', {
    requires : [ 'model', 'mm-model-list-media', 'mm-model-list-category' ]
});
