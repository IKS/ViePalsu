// We need Aloha Editor
GENTICS_Aloha_base = '/deps/aloha-editor/src';
document.write('<script type="text/javascript" src="' + GENTICS_Aloha_base + '/dep/jquery-1.5.1.js"></script>');
document.write('<script type="text/javascript" src="' + GENTICS_Aloha_base + '/aloha.js" id="aloha-script-include" data-plugins="format"></script>');
document.write('<link href="' + GENTICS_Aloha_base + '/aloha.css" id="aloha-style-include" rel="stylesheet">');

/*
GENTICS_Aloha_base = 'http://aloha-editor.org/aloha-0.9.3/aloha/';
document.write('<script type="text/javascript" src="' + GENTICS_Aloha_base + 'aloha.js"></script>');
document.write('<script type="text/javascript" src="' + GENTICS_Aloha_base + 'plugins/com.gentics.aloha.plugins.Format/plugin.js"></script>');
document.write('<script type="text/javascript" src="' + GENTICS_Aloha_base + 'plugins/com.gentics.aloha.plugins.HighlightEditables/plugin.js"></script>');
*/

// We need VIE
document.write('<script type="text/javascript" src="/js/underscore-min.js"></script>');
document.write('<script type="text/javascript" src="/js/backbone-min.js"></script>');
document.write('<script type="text/javascript" src="/js/vie.js"></script>');
document.write('<script type="text/javascript" src="/js/vie-aloha.js"></script>');

// And we need Socket.IO
document.write('<script type="text/javascript" src="/socket.io/socket.io.js"></script>');

jQuery(document).ready(function() {

    var socket = new io.Socket(), log = $('#chat-history > *');
    socket.connect();
    socket.on('message', function(data){
        if (typeof data !== 'object') {
            // Textual data
            console.log("Got", data);
            return;
        }
        
        var entity = VIE.EntityManager.getByJSONLD(data);
        var container = entity.get('sioc:has_container');
        if (container) {
            container.each(function(containerInstance) {
                if (containerInstance.get('sioc:container_of').indexOf(entity) === -1) {
                    containerInstance.get('sioc:container_of').add(entity, {fromServer: true});
                }
            });
        }
    });

    // Implement our own Backbone.sync method
    Backbone.sync = function(method, model, options) {
			var json = model.toJSONLD();
			socket.send(json);

			// auto scroll if we're within 50 pixels of the bottom
			if ( log.scrollTop() + 50 >= log[0].scrollHeight - log.height()) {
				window.setTimeout(function() {
					log.scrollTop(log[0].scrollHeight);
				}, 10);
			}
    };

    // Make all RDFa entities editable
    jQuery('[typeof][about]').each(function() {
        jQuery(this).vieSemanticAloha();
    });

    // Subscribe to the editable deactivated signal to update Backbone model
    jQuery.each(VIE.EntityManager.allEntities, function() {
        var modelInstance = this;
        jQuery.each(modelInstance.editables, function() {
            var editableInstance = this;
            // editableDeactivated or smartContentChanged
            GENTICS.Aloha.EventRegistry.subscribe(editableInstance, 'editableDeactivated', function() {
                if (VIE.AlohaEditable.refreshFromEditables(modelInstance)) {
                    // There were changes, save
                    modelInstance.save();
                }
            });
        });
    });
});
