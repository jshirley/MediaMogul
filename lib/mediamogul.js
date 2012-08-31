/* jslint stupid: true, regexp: true, nomen: true */

/**
Copyright (c) 2012 Jay Shirley. All rights reserved.
Code licensed under the BSD license:
  http://opensource.org/licenses/bsd-license.php

**/

var config = require('config');

exports.run = function(options) {
    if ( options.server ) {
        var server = require('./server'),
            port   = options.port || config.port;

        server.listen( port, function() {
            console.log('Control your media at http://localhost:' + port);
        });
        return;
    }
};
