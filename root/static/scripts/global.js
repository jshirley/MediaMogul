YUI().use("overlay", "substitute", "event-delegate","node", function(Y) {

    Y.delegate('click',function(e) {
        e.halt();

        var source = e.target;
        var href   = source.get('href');
        var target = Y.one( href.substring(href.indexOf('#')) );
        Y.log(href + ' ==> ' + target);
        if ( !target )
            return;
        if ( target.get('tagName') === 'INPUT' )
            target = target.get('parentNode');
        var widget_node = target.one('div.yui3-widget');
        var overlay;
        if ( widget_node ) {
            overlay = Y.Widget.getByNode(widget_node);
        }
        if ( !overlay ) {
            var width = target.getComputedStyle('width');
            overlay = new Y.Overlay({
                bodyContent: source.get('innerHTML'),
                zIndex: 100,
                width:  width,
                visible: false,
                align: {
                    node: target,
                    points: [ Y.WidgetPositionAlign.TC, Y.WidgetPositionAlign.BC ]
                },
                plugins : [
                    { fn: Y.Plugin.OverlayKeepaligned },
                    { fn: Y.Plugin.OverlayAutohide, cfg: {
                        focusedOutside: true
                    }}
                ]
            });
            overlay.render(target);
        }
        overlay.show();
    }, document.body, 'a.helptext');

    Y.delegate('click', function(e) {
        var target   = e.target;
        var href     = target.get('href');
            href     = href.substr( href.indexOf('#') );
        var template = Y.one(href + '-template');
        if ( !template )
            return;
        e.halt();

        var container = target.ancestor('div.repeatable');
        var content   = template.get('innerHTML');
        var list      = container.get('parentNode').all('input[type=text]');

        content = Y.substitute(content, { index: list.size() });
        container.get('parentNode').append(content);
    }, document.body, 'div.repeatable a.repeatable-add');

    Y.one(document.documentElement).removeClass('yui3-loading');
});


