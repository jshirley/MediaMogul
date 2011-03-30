function setupRemoteDataTableSort(Y) {
/**
 * Plugs DataTable with sorting functionality.
 *
 * @module datatable
 * @submodule datatable-sort
 */

/**
 * Adds column sorting to DataTable.
 * @class DataTableSort
 * @extends Plugin.Base
 */
var YgetClassName = Y.ClassNameManager.getClassName,
    Ycreate   = Y.Node.create,
    DATATABLE = "datatable",
    COLUMN    = "column",
    ASC       = "asc",
    DESC      = "desc",

    PAGE_STATUS    = '<p>Page {current} of {total}</p>',
    FIRST_LABEL    = 'First',
    PREV_LABEL     = 'Previous',
    NEXT_LABEL     = 'Next',
    LAST_LABEL     = 'Last',
    ACTIVE_LINK    = '<a href="#page={page}">{label}</a>',
    INACTIVE_LINK  = '{label}',
    LIST_ITEM      = '<li>{item}</li>',
    PAGE_ITEM      = '<a href="#page={page}">{label}</a>',
    PAGE_ITEM_ACTIVE = '{label}',
    PAGE_ITEM_LIST = '<ol>{list}</ol>',

    TEMPLATE_PAGINATION = '<tfoot><tr><td colspan="{colspan}"><div id="pager" class="paginator-container"></div></td></tr></tfoot>',

    //TODO: Don't use hrefs - use tab/arrow/enter
    TEMPLATE = '<a class="{link_class}" title="{link_title}" href="{link_href}">{value}</a>';


function RemoteDataTableSort() {
    RemoteDataTableSort.superclass.constructor.apply(this, arguments);
}

/////////////////////////////////////////////////////////////////////////////
//
// STATIC PROPERTIES
//
/////////////////////////////////////////////////////////////////////////////
Y.mix(RemoteDataTableSort, {
    /**
     * The namespace for the plugin. This will be the property on the host which
     * references the plugin instance.
     *
     * @property NS
     * @type String
     * @static
     * @final
     * @value "sort"
     */
    NS: "sort",

    /**
     * Class name.
     *
     * @property NAME
     * @type String
     * @static
     * @final
     * @value "dataTableSort"
     */
    NAME: "dataTableSort",

/////////////////////////////////////////////////////////////////////////////
//
// ATTRIBUTES
//
/////////////////////////////////////////////////////////////////////////////
    ATTRS: {
        paginationNode: { value: null },
        /**
        * @attribute trigger
        * @description Defines the trigger that causes a column to be sorted:
        * {event, selector}, where "event" is an event type and "selector" is
        * is a node query selector.
        * @type Object
        * @default {event:"click", selector:"th"}
        * @writeOnce "initOnly"
        */
        trigger: {
            value: {event:"click", selector:"th"},
            writeOnce: "initOnly"
        },
        
        /**
        * @attribute lastSortedBy
        * @description Describes last known sort state: {key,dir}, where
        * "key" is column key and "dir" is either "asc" or "desc".
        * @type Object
        */
        lastSortedBy: {
            setter: "_setLastSortedBy",
            lazyAdd: false
        },
 
        /**
        * @attribute lastQuery 
        * @description Descrbes the lastQuery.
        * @type Object
        */
        lastQuery: {
            setter: "_setLastQuery",
            lazyAdd: false
        },
       
        /**
        * @attribute template
        * @description Tokenized markup template for TH sort element.
        * @type String
        * @default '<a class="{link_class}" title="{link_title}" href="{link_href}">{value}</a>'
        */
        template: {
            value: TEMPLATE
        },

        pagination_status: { value: PAGE_STATUS },
        pagination_template: { value: TEMPLATE_PAGINATION },
        pagination_first_label: { value: FIRST_LABEL },
        pagination_prev_label: { value: PREV_LABEL },
        pagination_next_label: { value: NEXT_LABEL },
        pagination_last_label: { value: LAST_LABEL },
        pagination_active_link: { value: ACTIVE_LINK },
        pagination_inactive_link: { value: INACTIVE_LINK },
        pagination_list_item: { value: LIST_ITEM },
        pagination_page_item: { value: PAGE_ITEM },
        pagination_page_item_active: { value: PAGE_ITEM_ACTIVE },
        pagination_page_item_list: { value: PAGE_ITEM_LIST }
    }
});

/////////////////////////////////////////////////////////////////////////////
//
// PROTOTYPE
//
/////////////////////////////////////////////////////////////////////////////
Y.extend(RemoteDataTableSort, Y.Plugin.Base, {

    /////////////////////////////////////////////////////////////////////////////
    //
    // METHODS
    //
    /////////////////////////////////////////////////////////////////////////////
    /**
    * Initializer.
    *
    * @method initializer
    * @param config {Object} Config object.
    * @private
    */
    initializer: function(config) {
        var dt = this.get("host"),
            trigger = this.get("trigger");
        //Y.log(" ---> initializer(config): " + dt); 
        dt.get("recordset").plug(Y.Plugin.RecordsetSort, {dt: dt});
        dt.get("recordset").sort.addTarget(dt);
        
        // Wrap link around TH value
        this.doBefore("_createTheadThNode", this._beforeCreateTheadThNode);
        
        // Add class
        this.doBefore("_attachTheadThNode", this._beforeAttachTheadThNode);
        this.doBefore("_attachTbodyTdNode", this._beforeAttachTbodyTdNode);
        
        this.doAfter("_addTbodyNode", this._afterAttachTbodyNode);

        // Attach trigger handlers
        dt.delegate(trigger.event, Y.bind(this._onEventSortColumn,this), trigger.selector);

        dt.delegate(trigger.event, Y.bind(this._onPaginatorClick,this), '.paginator-container');

        // Attach UI hooks
        dt.after("recordsetSort:sort", function() {
            this._uiSetRecordset(this.get("recordset"));
        });
        this.on("lastSortedByChange", function(e) {
            this._uiSetLastSortedBy(e.prevVal, e.newVal, dt);
        });

        //TODO
        //dt.after("recordset:mutation", function() {//reset lastSortedBy});
        
        //TODO
        //add Column sortFn ATTR
        
        // Update UI after the fact (render-then-plug case)
        if(dt.get("rendered")) {
            dt._uiSetColumnset(dt.get("columnset"));
            this._uiSetLastSortedBy(null, this.get("lastSortedBy"), dt);
        }

    },

    /**
    * @method _setLastSortedBy
    * @description Normalizes lastSortedBy
    * @param val {String | Object} {key, dir} or "key"
    * @returns {key, dir, notdir}
    * @private
    */
    _setLastSortedBy: function(val) {
        if(Y.Lang.isString(val)) {
            return {key:val, dir:"asc", notdir:"desc"};
        }
        else if (val && val.key) {
            if(val.dir === "desc") {
                return {key:val.key, dir:"desc", notdir:"asc"};
            }
            else {
                return {key:val.key, dir:"asc", notdir:"desc"};
            }
        }
        else {
            return null;
        }
    },

    /**
     * Updates sort UI.
     *
     * @method _uiSetLastSortedBy
     * @param val {Object} New lastSortedBy object {key,dir}.
     * @param dt {Y.DataTable.Base} Host.
     * @protected
     */
    _uiSetLastSortedBy: function(prevVal, newVal, dt) {
        var prevKey = prevVal && prevVal.key,
            prevDir = prevVal && prevVal.dir,
            newKey = newVal && newVal.key,
            newDir = newVal && newVal.dir,
            cs = dt.get("columnset"),
            prevColumn = cs.keyHash[prevKey],
            newColumn = cs.keyHash[newKey],
            tbodyNode = dt._tbodyNode,
            prevRowList, newRowList;

        // Clear previous UI
        if(prevColumn) {
            prevColumn.thNode.removeClass(YgetClassName(DATATABLE, prevDir));
            prevRowList = tbodyNode.all("."+YgetClassName(COLUMN, prevColumn.get("id")));
            prevRowList.removeClass(YgetClassName(DATATABLE, prevDir));
        }

        // Add new sort UI
        if(newColumn) {
            newColumn.thNode.addClass(YgetClassName(DATATABLE, newDir));
            newRowList = tbodyNode.all("."+YgetClassName(COLUMN, newColumn.get("id")));
            newRowList.addClass(YgetClassName(DATATABLE, newDir));
        }
    },

    /**
    * Before header cell element is created, inserts link markup around {value}.
    *
    * @method _beforeCreateTheadThNode
    * @param o {Object} {value, column, tr}.
    * @protected
    */
    _beforeCreateTheadThNode: function(o) {
        if(o.column.get("sortable")) {
            o.value = Y.substitute(this.get("template"), {
                link_class: o.link_class || "",
                link_title: "title",
                link_href: "#",
                value: o.value
            });
        }
    },

    /**
    * Before header cell element is attached, sets applicable class names.
    *
    * @method _beforeAttachTheadThNode
    * @param o {Object} {value, column, tr}.
    * @protected
    */
    _beforeAttachTheadThNode: function(o) {
        var lastSortedBy = this.get("lastSortedBy"),
            key = lastSortedBy && lastSortedBy.key,
            dir = lastSortedBy && lastSortedBy.dir,
            notdir = lastSortedBy && lastSortedBy.notdir;

        // This Column is sortable
        if(o.column.get("sortable")) {
            o.th.addClass(YgetClassName(DATATABLE, "sortable"));
        }
        // This Column is currently sorted
        if(key && (key === o.column.get("key"))) {
            o.th.replaceClass(YgetClassName(DATATABLE, notdir), YgetClassName(DATATABLE, dir));
        }
    },

    /**
    * Before header cell element is attached, sets applicable class names.
    *
    * @method _before_beforeAttachTbodyTdNode
    * @param o {Object} {record, column, tr, headers, classnames, value}.
    * @protected
    */
    _beforeAttachTbodyTdNode: function(o) {
        var lastSortedBy = this.get("lastSortedBy"),
            key = lastSortedBy && lastSortedBy.key,
            dir = lastSortedBy && lastSortedBy.dir,
            notdir = lastSortedBy && lastSortedBy.notdir;

        // This Column is sortable
        if(o.column.get("sortable")) {
            o.td.addClass(YgetClassName(DATATABLE, "sortable"));
        }
        // This Column is currently sorted
        if(key && (key === o.column.get("key"))) {
            o.td.replaceClass(YgetClassName(DATATABLE, notdir), YgetClassName(DATATABLE, dir));
        }
    },

    _afterAttachTbodyNode: function(o) {
        if ( this._tfooterNode )
            return;
        var colspan         = this.get('host').get('columnset').keys.length;
        var template        = this.get('pagination_template');
        this._tfooterNode   = o.appendChild(Ycreate(Y.substitute(template, { colspan: colspan })));
        this._paginatorNode = this._tfooterNode.one('div.paginator-container');

        var query = this.get('host').get('lastQuery');
        if ( query ) {
            this._updatePaginator();
        }
        this.get('host').datasource.after('response', Y.bind(this._updatePaginator, this));
    },

    /**
    * In response to the "trigger" event, sorts the underlying Recordset and
    * updates the lastSortedBy attribute.
    *
    * @method _onEventSortColumn
    * @param o {Object} {value, column, tr}.
    * @protected
    */
    _onEventSortColumn: function(e) {
        e.halt();
        //TODO: normalize e.currentTarget to TH
        var dt = this.get("host"),
            datasource = dt.get('datasource'),
            column = dt.get("columnset").idHash[e.currentTarget.get("id")],
            key = column.get("key"),
            field = column.get("field"),
            lastSortedBy = this.get("lastSortedBy"),
            dir = (lastSortedBy &&
                lastSortedBy.key === key &&
                lastSortedBy.dir === ASC) ? DESC : ASC,
            sorter = column.get("sortFn"),
            datasource = dt.datasource
            ;
        if(column.get("sortable")) {
            var state = dt.get('lastQuery');
            var lq = state.query || '*:*';
            var query = "q=" + encodeURIComponent(lq) +
                "&meta.sortDir=" + dir + "&meta.sort=" + key;
            var filters = [];
            for ( var f in state.filters ) {
                // XX Something is stuffing null data into filters.
                if ( f && state.filters[f] ) {
                    var name = f.replace('_literal', '');
                    filters.push(name + '=' + encodeURIComponent(state.filters[f]));
                }
            }
            if ( filters.length ) {
                query += '&' + filters.join('&');
            }
            
            datasource.load({ request: query });
            //dt.get("recordset").sort.sort(field, dir === DESC, sorter);
            this.set("lastSortedBy", {key: key, dir: dir});
        }
    },
    _updatePaginator: function() {
        if ( !this._paginatorNode ) return;

        var state = this.get('host').get('lastQuery');
        var current   = parseInt(state.pager.current_page),
            last      = parseInt(state.pager.last_page),
            last_item = parseInt(state.pager.last_item),
            index     = 1;
        var output = '';
        output += Y.substitute(this.get('pagination_status'), { current: current, total: last });

        var item_buffer = [];
        if ( current > 1 ) {
            item_buffer.push( Y.substitute(this.get('pagination_list_item'), { item: Y.substitute(this.get('pagination_active_link'), { page: 1, label: this.get('pagination_first_label') }) }) );
            item_buffer.push( Y.substitute(this.get('pagination_list_item'), { item: Y.substitute(this.get('pagination_active_link'), { page: parseInt(current) - 1, label: this.get('pagination_prev_label') }) }) );
        } else {
            item_buffer.push( Y.substitute(this.get('pagination_list_item'), { item: Y.substitute(this.get('pagination_inactive_link'), { page: 1, label: this.get('pagination_first_label') }) }) );
            item_buffer.push( Y.substitute(this.get('pagination_list_item'), { item: Y.substitute(this.get('pagination_inactive_link'), { page: parseInt(current) - 1, label: this.get('pagination_prev_label') }) }) );
        }
        while ( item_buffer.length < 10 && index <= last ) {
            if ( index === current ) {
                item_buffer.push( Y.substitute(this.get('pagination_list_item'), { item: Y.substitute(this.get('pagination_page_item_active'), { page: index, label: index }) }) );
            } else {
                item_buffer.push( Y.substitute(this.get('pagination_list_item'), { item: Y.substitute(this.get('pagination_page_item'), { page: index, label: index }) }) );
            }
            index++;
        }
        if ( current < last ) {
            item_buffer.push( Y.substitute(this.get('pagination_list_item'), { item: Y.substitute(this.get('pagination_active_link'), { page: parseInt(current) + 1, label: this.get('pagination_next_label') }) }) );
            item_buffer.push( Y.substitute(this.get('pagination_list_item'), { item: Y.substitute(this.get('pagination_active_link'), { page: last, label: this.get('pagination_last_label') }) }) );
        } else {
            item_buffer.push( Y.substitute(this.get('pagination_list_item'), { item: Y.substitute(this.get('pagination_inactive_link'), { page: parseInt(current) + 1, label: this.get('pagination_next_label') }) }) );
            item_buffer.push( Y.substitute(this.get('pagination_list_item'), { item: Y.substitute(this.get('pagination_inactive_link'), { page: last, label: this.get('pagination_last_label') }) }) );
        }

        if ( item_buffer.length ) {
            output += Y.substitute(
                this.get('pagination_page_item_list'),
                { list: item_buffer.join("\n") }
            );
        }

        //Y.log(output);
        this._paginatorNode.set('innerHTML', output);
    },

    _onPaginatorClick: function(e) {
        e.halt();
        var href = e.target.get('href');
        var hash = href.substr(href.indexOf('#')+1);
        var page = hash.substr(hash.indexOf('page=') + 5);

        var state = this.get('host').get('lastQuery');
        state.page = parseInt(page);
        this._sendRequest(state);
    },

    _sendRequest: function(state) {
        var parts = [];
        parts.push('q=' + encodeURIComponent(state.query));
        for ( var i in state.filters )
            parts.push(i + '=' + state.filters[i]);
        if ( state.page )
            parts.push('page=' + parseInt(state.page));
        if ( state.sort ) {
            parts.push('meta.sortDir=' + state.sort.direction);
            parts.push('meta.sort=' + state.sort.lastSortedBy);
        }
        this.get('host').datasource.load({ request: parts.join('&') });
    }
});

Y.namespace("Plugin").RemoteDataTableSort = RemoteDataTableSort;

};
