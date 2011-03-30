YUI().use("event-delegate", "datasource", "datasource-io", "datatable-datasource", "datatable-sort", "recordset-sort", function(Y) {
    function localize(name) {
        if ( typeof localized_types !== 'undefined' && localized_types[name] )
            name = localized_types[name];
        return name;
    }

    setupRemoteDataTableSort(Y);

    var tabs_rendered = false;
    var facets        = Y.one('#facets');
    var tab_facets    = Y.one('#tabs')

    var linkColumn = function(o) {
        return "<a href=\"" + o.data.actions.Edit + "\">" + o.value + "</a>";
    }
    var formatActions = function(o, b) {
        var str = "";
        for ( i in o.value ) {
            str += "<a class=\"action\" href=\"" + o.value[i] + "\">" + i + "</a>";
        }

        return str;
    };
    if ( typeof cols === 'undefined' ) {
        cols = [
            { key: "name", field: "name", label: "Name", sortable: true, formatter: linkColumn },
            { key: "type", field: "media_type", label: "Type", sortable: true },
            { key: "actions", field: "actions", label: "Actions", sortable: false,
                formatter: formatActions
            }
        ];
    } else {
        cols.push({
            key: "actions", field: "actions", label: "Actions", sortable: false,
            formatter: formatActions
        });
    }
    
    var state = { query: "", filters: {} };
    var ds = new Y.DataSource.IO({
        source: asset_source
    });

    ds.plug(Y.Plugin.DataSourceJSONSchema, {
        schema: {
            metaFields: {
                "pager":   "pager",
                "facets":  "facets",
                "filters": "filters",
                "query":   "query",
                "sort":    "sort.lastSortedBy",
                "sortDir": "sort.direction",
            },
            resultListLocator: "results",
        }
    });

    var dt = 
        new Y.DataTable.Base({
            columnset: cols
        })
        .plug(Y.Plugin.RemoteDataTableSort)
        .plug(
            Y.Plugin.DataTableDataSource,
            { datasource: ds, initialRequest: search_query || "" } )
    ;

    ds.after('response',
        function(o) {
            var meta      = o.response.meta;
            state.query   = meta.query;
            state.filters = meta.filters;
            dt.set('lastQuery', meta);

            if ( dt.get('rendered') ) {
                // We want to do anything here?
            } else {
                dt.get('recordset').plug(Y.Plugin.RecordsetSort);
                dt.render('#datatable');
            }
            if ( facets ) {
                var facet_data = meta.facets;
                if ( facet_data ){
                    updateFacets(facet_data);
                }
            }

            if ( tab_facets ) {
                if ( tabs_rendered )
                    updateSelectedTab(tab_facets, meta.filters);
                else {
                    var facet_data = meta.facets;
                    if ( facet_data )
                        updateTabs(tab_facets, facet_data);
                }
            }
            if ( typeof post_request_filters !== 'undefined' &&
                 post_request_filters
            ) {
                state.filters = post_request_filters;
                post_request_filters = null;
                sendQuery();
            }
            dt.sort._updatePaginator(); // WTF!? This isn't firing automatically
        }
    );

    // Just refresh the page
    ds.after('error',
        function(o) {
            var loc = document.location.toString();
            if ( loc.indexOf('?') > 0 && loc.indexOf('redirect=1') > 0 ) {
                var path = loc.substr(8);
                //document.location = loc.substr(0,  path.indexOf('/') + 9 );
            } else {
                document.location = loc.indexOf('?') > 0 ?
                    loc + '&redirect=1' : loc + '?redirect=1'
            }
        });

    Y.delegate('click',
        function(e) {
            e.halt();
            var href = e.target.get('href');
            var query = href.substr(href.indexOf('?') + 1);
            if ( query.indexOf('&') >= 0 )
                query = query.substr( query.indexOf('&') );
            var s = query.split('=');
            Y.log(query);
            var facet = s[0];
            var value = s[1];
/*
            e.target.ancestor('ul').all('li').removeClass('selected');
            e.target.ancestor('li').addClass('selected');
*/
            if ( facet && value )
                addFacet(facet, value);
            else
                removeFacet(facet, value);
            sendQuery();
        }, '#asset_view', '#tabs a');

    function sendQuery() {
        var parts = [];
        parts.push('q=' + encodeURIComponent(state.query));
        for ( var i in state.filters ) {
            if ( i && state.filters[i] ) // XX WTF? Where's this coming from?
                parts.push(i + '=' + state.filters[i]);
        }
        Y.log("Sending request: " + parts.join('&'));
        dt.datasource.load({ request: parts.join('&') });
    }

    function addFacet(facet, value) {
        state.filters[facet] = value;
        sendQuery();
    }

    function removeFacet(facet, value) {
        delete state.filters[facet];
        sendQuery();
    }

    Y.delegate('click',
        function(e) {
            e.halt();
            var loc = e.target.get('href');
            loc = loc.substr( loc.indexOf('#') + 1);
            if ( loc && loc.indexOf('=') ) {
                var bits = loc.split('=');
                addFacet(bits[0], bits[1]);
            }
        },
        facets, 'a.facet-link'
    );

    Y.delegate('click',
        function(e) {
            var facet = e.target.get('name');
            var value = e.target.get('value');
            if ( e.target.get('checked') )
                addFacet(facet, value);
            else
                removeFacet(facet);
        },
        document.body, 'input[type=checkbox].facet-toggle'
    );

    Y.delegate('click',
        function(e) {
            e.halt();
            var loc = e.target.get('href');
            loc = loc.substr( loc.indexOf('#') + 1);
            if ( loc && loc.indexOf('=') ) {
                var bits = loc.split('=');
                removeFacet(bits[0], bits[1]);
            }
        },
        facets, 'a.remove-facet'
    );

    function updateFacets(facet_data) {
        var filter_str = [];
        var filter_list = [];
        for ( var f in state.filters ) {
            var filter_name = f;
            // We don't show any filters with a '-' prefix, those are internal
            if ( !filter_name.match(/^-/) ) {
                var filter_value = state.filters[f];
                if ( filter_name && filter_value ) {
                    filter_name = filter_name.replace('_literal', '');
                    filter_value = filter_value.replace(/^"|"$/g, '');
                    filter_str.push('<li>' + localize(filter_name) + ': <a href="#' + f + '=' + encodeURIComponent(state.filters[f]) + '" class="remove-facet">' + localize(filter_value) + '</a>');
                    filter_list.push({ name: filter_name, value: filter_value });
                }
            }
        } 
        var str = '';
        if ( filter_str.length )
            str = '<ul class="filters">' + filter_str.join('') + '</ul>';

        str += '<dl>';
        for ( var i in facet_data ) {
            var f = facet_data[i];
            if ( f.length >= 2 ) {
                var name = localize(i);
                str += '<dt>' + name + '</dt>';
                for ( var j = 0; j < f.length; j+=2 ) {
                    str += '<dd><a href="#' + i + '=' + encodeURIComponent(f[j]) + '" class="facet-link">' +
                        localize(f[j]) + '</a> (' + f[j+1] + ')</dd>';
                }
            }
        }
        str += '</dl>';
        facets.set('innerHTML', str);
    }

    function updateSelectedTab(node, data) {
        //Y.log(data);
        if ( typeof tab_facets_on === 'undefined' )
            return;

        var selected = data[tab_facets_on];
        if ( !selected )
            selected = 'All';
        selected = localize(selected.replace(/^"|"$/g, ""));
        Y.log("Selected tab: " + selected);
        node.all('li > a').each( function(el) {
            if ( el.get('innerHTML') === selected )
                el.get('parentNode').addClass('selected');
            else
                el.get('parentNode').removeClass('selected');
        });
    }
    function updateTabs(node, data) {
        if ( typeof tab_facets_on === 'undefined' )
            return;
        if ( tabs_rendered )
            return;
        var facet_data = data[tab_facets_on]
        if ( !facet_data )
            return;
        var filter_list = [];
        var url = Y.substitute(tab_facet_uri, { name: '' });
        var tab_markup = '<ul>';
            tab_markup += '<li class="tab0 selected"><a href="'+url+'">All</a></li>';
        var tab_index = 1;
        for ( var i = 0; i < facet_data.length; i++ ) {
            var name  = facet_data[i++];
            var count = facet_data[i];
            name = name.replace(/</g, '&lt;');
            name = name.replace(/>/g, '&gt;');
            name = name.replace(/"/g, '&quot;');
            name = name.replace(/&/g, '&amp;');

            var url = Y.substitute(tab_facet_uri, { name: encodeURIComponent(name) })
            name = localize(name);
            tab_markup += '<li class="tab' + (tab_index++) + '"><a href="' + url + '">' + name + '</a></li>';
        }
        tab_markup += '</ul>';
        node.set('innerHTML', tab_markup);
        tabs_rendered = true;
    }
});
