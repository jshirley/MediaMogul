YUI.add('mm-model-category', function(Y) {
    var NS   = Y.namespace('MM.Model'),
        Sync = NS.Sync,

        Model;

    Model = Y.Base.create('category', Y.Model, [ Sync ], {
        _fetchMediaList : function() {
            var list = new NS.MediaList();
            list.addFilter('category', this.get('id'));

            return list;
        }
    }, {
        ATTRS : {
            'type'     : { },
            'location' : { },
            'template' : { },
            'media'    : { valueFn : '_fetchMediaList' }
        }
    });

    NS.Category = Model;

}, '0.1.0', {
    requires : [ 'model', 'mm-model-list-media' ]
});
