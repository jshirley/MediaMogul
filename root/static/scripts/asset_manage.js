YUI({
    gallery: 'gallery-2011.03.11-23-49'
}).use('gallery-xarno-clipboard', function(Y) {
    var cb = new Y.Xarno.Clipboard({
        swfPath : '/static/flash/XarnoClipboard.swf',
        clipTarget: Y.one('#hidden_embed_code')
    });
    
    Y.one('body').delegate('mouseover', function(e){
        cb.moveTo(e.currentTarget);
        cb.copy(cb.get('clipTarget'));
/*
        cb.moveTo(target);
        if ( target.get('tagName') === "A" ) {
            var href = target.get('href');
            href = href.substr(href.indexOf('#'));
            target = Y.one(href);
            Y.log("set target:");
            Y.log(target);
        }
        cb.copy(target);
*/
    }, '.clipboard-copy');
                         
});
