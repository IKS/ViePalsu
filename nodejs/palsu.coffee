express = require 'express'
io = require 'socket.io'
VIE = require '../js/vie.js'
require './vie-redis.coffee'
fs = require 'fs'
jQuery = require 'jquery'
jsdom = require 'jsdom'

server = express.createServer()
server.configure -> 
    # Our CSS files need the LessCSS compiler
    server.use express.compiler
        src: process.cwd()
        enable: ['less']
    # Serve static files from /styles and /js
    server.use '/styles', express.static "#{process.cwd()}/styles"
    server.use '/js', express.static "#{process.cwd()}//js"

# Serve the list of meetings for /
server.get '/', (request, response) ->
    return fs.readFile "#{process.cwd()}/templates/index.html", "utf-8", (err, data) ->
        document = jsdom.jsdom data
        window = document.createWindow()
        jQ = jQuery.create window
        # Find RDFa entities and load them
        VIE.RDFaEntities.getInstances jQ "*"
        # Get the Calendar object
        calendar = VIE.EntityManager.getBySubject '/meetings'

        # Query for events that have the calendar as component
        events = calendar.get 'cal:has_component'
        events.predicate = "cal:component"
        events.object = calendar.id
        return events.fetch
            success: (eventCollection) ->
                VIE.cleanup()
                return response.send window.document.innerHTML

server.get '/meeting/:uuid', (request, response) ->
    return fs.readFile "#{process.cwd()}/templates/meeting.html", "utf-8", (err, data) ->
        document = jsdom.jsdom data
        window = document.createWindow()
        jQ = jQuery.create window
        
        # Write the Meeting identifier into the DOM
        jQ('[typeof="cal\\:Vevent"]').attr('about', request.params.uuid);
        
        # Find RDFa entities and load them
        VIE.RDFaEntities.getInstances jQ "*"
        
        # Get the Meeting object
        calendar = VIE.EntityManager.getBySubject request.params.uuid
        calendar.fetch
            success: (event) ->
                console.log event.attributes
                # Query for posts for this event
                posts = event.get 'sioc:container_of'
                posts.predicate = "sioc:has_container"
                posts.object = event.id
                return posts.fetch
                    success: (postCollection) ->
                        VIE.cleanup()
                        return response.send window.document.innerHTML
                        
            error: (event, error) ->
                VIE.cleanup()
                return response.send error

server.listen(8002)

# ## Handling sockets
socket = io.listen server

# Handle a new connected client
socket.on 'connection', (client) ->
    # TODO: Send new data
    meeting = VIE.EntityManager.getByJSONLD
        "@": "<#meeting>"
        a: "<mgd:event>"
    meeting.fetch
        success: (item) ->
            client.send item.toJSONLD()
            
    meetingComments = new VIE.RDFEntityCollection
    meetingComments.predicate = "sioc:has_container"
    meetingComments.object = "#meeting-comments"
    meetingComments.comparator = (item) ->
        itemDate = new Date item.get "dc:created"
        itemIndex = 0
        meetingComments.pluck("dc:created").forEach (date, index) ->
            if itemDate.getTime() > new Date(date).getTime()
                itemIndex = index + 1
        return itemIndex
    meetingComments.bind "add", (item) ->
        client.send item.toJSONLD()
    meetingComments.fetch()

    client.on 'message', (data) ->
        if typeof data isnt 'object'
            # If we get a regular string from the user there is no need to pass it on
            return

        # Generate a RDF Entity instance for the JSON-LD we got from the client
        modelInstance = VIE.EntityManager.getByJSONLD(data)
        modelInstance.save()

        # Send the item back to everybody else
        for clientId, clientObject of socket.clients
            if clientObject isnt client
                console.log "Forwarding data to #{clientId}"
                clientObject.send data
