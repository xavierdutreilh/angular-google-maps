###
!
The MIT License

Copyright (c) 2010-2013 Google, Inc. http://angularjs.org

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

angular-google-maps
https://github.com/nlaplante/angular-google-maps

@authors
Nicolas Laplante - https://plus.google.com/108189012221374960701
Nicholas McCready - https://twitter.com/nmccready
Nick Baugh - https://github.com/niftylettuce
###

#jshint indent:4

#globals directives,google
angular.module("google-maps").directive "googleMap", ["$log", "$timeout", ($log, $timeout) ->
    "use strict"

    # Utility functions
    #Check if a value is true
    isTrue = (val) ->
        angular.isDefined(val) and val isnt null and val is true or val is "1" or val is "y" or val is "true"

    directives.api.utils.Logger.logger = $log

    DEFAULTS =
        mapTypeId: google.maps.MapTypeId.ROADMAP

    return {
        self: @
        restrict: "ECMA"
        transclude: true
        replace: false
        #priority: 100,
        template: "<div class=\"angular-google-map\"><div class=\"angular-google-map-container\"></div><div ng-transclude style=\"display: none\"></div></div>"

        scope:
            center: "=center" # required
            zoom: "=zoom" # required
            dragging: "=dragging" # optional
            refresh: "&refresh" # optional
            windows: "=windows" # optional  TODO is this still needed looks like dead code
            options: "=options" # optional
            events: "=events" # optional
            styles: "=styles" # optional
            bounds: "=bounds"

        controller: ["$scope", ($scope) ->
            #@return the map instance
            getMap: ->
                $scope.map
        ]

        ###
        @param scope
        @param element
        @param attrs
        ###
        link: (scope, element, attrs) ->
            # Center property must be specified and provide lat &
            # lng properties
            if not angular.isDefined(scope.center) or (not angular.isDefined(scope.center.latitude) or not angular.isDefined(scope.center.longitude))
                $log.error "angular-google-maps: could not find a valid center property"
                return
            unless angular.isDefined(scope.zoom)
                $log.error "angular-google-maps: map zoom property not set"
                return
            el = angular.element(element)
            el.addClass "angular-google-map"

            # Parse options
            opts =
                options: {}
            opts.options = scope.options  if attrs.options
            opts.styles = scope.styles  if attrs.styles
            if attrs.type
                type = attrs.type.toUpperCase()
                if google.maps.MapTypeId.hasOwnProperty(type)
                    opts.mapTypeId = google.maps.MapTypeId[attrs.type.toUpperCase()]
                else
                    $log.error "angular-google-maps: invalid map type \"" + attrs.type + "\""

            # Create the map
            _m = new google.maps.Map(el.find("div")[1], angular.extend({}, DEFAULTS, opts,
                center: new google.maps.LatLng(scope.center.latitude, scope.center.longitude)
                draggable: isTrue(attrs.draggable)
                zoom: scope.zoom
                bounds: scope.bounds
            ))
            dragging = false
            google.maps.event.addListener _m, "dragstart", ->
                dragging = true
                $timeout ->
                    scope.$apply (s) ->
                        s.dragging = dragging if s.dragging?


            google.maps.event.addListener _m, "dragend", ->
                dragging = false
                $timeout ->
                    scope.$apply (s) ->
                        s.dragging = dragging if s.dragging?


            google.maps.event.addListener _m, "drag", ->
                c = _m.center
                $timeout ->
                    scope.$apply (s) ->
                        s.center.latitude = c.lat()
                        s.center.longitude = c.lng()


            google.maps.event.addListener _m, "zoom_changed", ->
                if scope.zoom isnt _m.zoom
                    $timeout ->
                        scope.$apply (s) ->
                            s.zoom = _m.zoom


            settingCenterFromScope = false
            google.maps.event.addListener _m, "center_changed", ->
                c = _m.center
                return  if settingCenterFromScope #if the scope notified this change then there is no reason to update scope otherwise infinite loop
                $timeout ->
                    scope.$apply (s) ->
                        unless _m.dragging
                            s.center.latitude = c.lat()  if s.center.latitude isnt c.lat()
                            s.center.longitude = c.lng()  if s.center.longitude isnt c.lng()


            google.maps.event.addListener _m, "idle", ->
                b = _m.getBounds()
                ne = b.getNorthEast()
                sw = b.getSouthWest()
                $timeout ->
                    scope.$apply (s) ->
                        if s.bounds isnt null and s.bounds isnt `undefined` and s.bounds isnt undefined
                            s.bounds.northeast =
                                latitude: ne.lat()
                                longitude: ne.lng()

                            s.bounds.southwest =
                                latitude: sw.lat()
                                longitude: sw.lng()


            if angular.isDefined(scope.events) and scope.events isnt null and angular.isObject(scope.events)
                getEventHandler = (eventName) ->
                    ->
                        scope.events[eventName].apply scope, [_m, eventName, arguments]

                for eventName of scope.events
                    google.maps.event.addListener _m, eventName, getEventHandler(eventName)  if scope.events.hasOwnProperty(eventName) and angular.isFunction(scope.events[eventName])

            # Put the map into the scope
            scope.map = _m
            google.maps.event.trigger _m, "resize"

            # Check if we need to refresh the map
            unless angular.isUndefined(scope.refresh())
                scope.$watch "refresh()", (newValue, oldValue) ->
                    if newValue and not oldValue

                        #  _m.draw();
                        coords = new google.maps.LatLng(newValue.latitude, newValue.longitude)
                        if isTrue(attrs.pan)
                            _m.panTo coords
                        else
                            _m.setCenter coords


            # Update map when center coordinates change
            scope.$watch "center", ((newValue, oldValue) ->
                return  if newValue is oldValue
                settingCenterFromScope = true
                unless dragging
                    coords = new google.maps.LatLng(newValue.latitude, newValue.longitude)
                    if isTrue(attrs.pan)
                        _m.panTo coords
                    else
                        _m.setCenter coords

                #_m.draw();
                settingCenterFromScope = false
            ), true
            scope.$watch "zoom", (newValue, oldValue) ->
                return  if newValue is oldValue
                _m.setZoom newValue


            #_m.draw();
            scope.$watch "bounds", (newValue, oldValue) ->
                return  if newValue is oldValue
                ne = new google.maps.LatLng(newValue.northeast.latitude, newValue.northeast.longitude)
                sw = new google.maps.LatLng(newValue.southwest.latitude, newValue.southwest.longitude)
                bounds = new google.maps.LatLngBounds(sw, ne)
                _m.fitBounds bounds
    }

]