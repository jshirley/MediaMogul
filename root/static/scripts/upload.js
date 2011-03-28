YUI({
    gallery: 'gallery-2011.01.03-18-30'
}).use(
    "event-delegate", "io-base", "node","json-parse", "overlay",
    "gallery-overlay-extras", "anim",
    "datasource-get",
    "uploader", "gallery-progress-bar",
function(Y) {
    var uploader;
    var fileList    = [];
    var uploadIndex = 0;
    function setupUploader (event) {
        uploader.set("multiFiles", true);
        uploader.set("simLimit", 3);
        uploader.set("log", true);

        var fileFilters = new Array(
                { description:"Images", extensions:"*.jpg;*.png;*.gif"},
                { description:"Documents", extensions:"*.txt;*.rtf;*."}
        ); 
        // For now, lets not use any filters.
        //uploader.set("fileFilters", fileFilters); 
    }

    function fileSelect(event) {
        Y.log("File was selected, parsing...");
        var fileData = event.fileList;  
        var tbody = Y.one("#filenames tbody");
        tbody.all('tr').each( function(el) {
            if ( el.hasClass('uploaded') )
                return;
            el.remove();
        });
        fileList = [];
        for (var key in fileData) {
            var removeLink = "<a href=\"#" + key + "\" class=\"upload-action remove-file\">X</a>";
            var output = "<tr><th>"+removeLink+"</th><td>" + fileData[key].name + "</td><td>" + fileData[key].size + "</td><td><div id='div_" + uploadIndex + '_' + fileData[key].id + "'></div></td></tr>\n";
            tbody.append(output);

            var progressBar = new Y.ProgressBar({id:"pb_" + uploadIndex + '_' + fileData[key].id, layout : '<div class="{labelClass}"></div><div class="{sliderClass}"></div>'});
            progressBar.setLabelAt(0, progress_default_label);
            progressBar.render("#div_" + uploadIndex + '_' + fileData[key].id);
            progressBar.set("progress", 0);
            fileList.push( fileData[key].id );
        }
        if ( fileList.length > 0 )
            Y.one("#uploadLink").removeClass('disabled');
        else
            Y.one("#uploadLink").addClass('disabled');
    }

    function updateProgress (event) {
        Y.log('updateProgress');
        Y.log(event);
        var pb = Y.Widget.getByNode("#pb_" + uploadIndex + '_' + event.id);
        pb.set("progress", Math.round(100 * event.bytesLoaded / event.bytesTotal));
    }

    var uploaded = 0;
    function uploadComplete (event) {
        Y.log('uploadComplete');
        var pb = Y.Widget.getByNode("#pb_" + uploadIndex + '_' + event.id);
        pb.set("progress", 100);
        Y.one('#div_' + uploadIndex + '_' + event.id).ancestor('tr').addClass('uploaded');
        Y.log(event);
        if ( ++uploaded == fileList.length ) {
            uploader.clearFileList();
            fileList = [];
            Y.log("Every file has been updated!");
            uploadIndex++;
        }
    }

    function removeFile(event) {
        var node    = event.target.get('href');
        var file_id = node.substr(node.indexOf('#') + 1);
        var row = Y.one('#div_' + uploadIndex + '_' + file_id).ancestor('tr');
        if ( row && file_id ) {
            row.remove();
            uploader.removeFile(file_id);
            var newList = [];
            for ( var i = 0; i < fileList.length; i++ ) {
                if ( fileList[i] === file_id ) {/* Any special things here? */}
                else
                    newList.push(fileList[i]);
            }
            fileList = newList;
            if ( fileList.length < 1 )
                Y.one("#uploadLink").addClass('disabled');
        }
    }

    function uploadFile (event) {
        uploaded = 0;
        uploader.uploadAll(upload_destination);
    }

    function initUploader() {
        var overlayRegion = Y.one('#selectLink').get('region');

        Y.one("#uploaderOverlay").set("offsetWidth", overlayRegion.width);
        Y.one("#uploaderOverlay").set("offsetHeight", overlayRegion.height);
         
        uploader = new Y.Uploader({boundingBox:"#uploaderOverlay"});    
         
        uploader.on("uploaderReady", setupUploader);
        uploader.on("fileselect", fileSelect);
        uploader.on("uploadprogress", updateProgress);
        uploader.on("uploadcomplete", uploadComplete);
         
        Y.one("#uploadLink").on("click", uploadFile);
    }
    Y.delegate('click', removeFile, '#files', 'tr a.remove-file');
    initUploader();

});
