# db_url = "#{window.location.protocol}//#{window.location.host}/calendar"
# db_url = "https://shimaore.net:6984/calendar"
db_url = "calendar"

timezoneJS = require 'timezone-js'
zone_files = require './timezones.coffee'
{logger} = require './tools.coffee'
$ = require 'jquery-browserify'
moonshine = require 'moonshine-browserify'
# moonshine = require '../bower_components/moonshine/dist/moonshine.js'

$(document).ready -> moonshine ->

  timezoneJS.timezone.zoneFileBasePath = ''
  timezoneJS.timezone.transport = (opts) ->
    if opts.async
      if typeof opts.success isnt 'function'
        return
      opts.error ?= console.error
      opts.success zone_files[opts.url]
      # opts.error(err) not used
    return zone_files[opts.url]

  timezoneJS.timezone.init()

  db = new PouchDB db_url

  db.put
    _id: '_design/calendar'
    language: 'javascript'
    views:
      locate:
        map: (doc) ->
          emit doc.start, null
          emit doc.end, null

  db.put
    _id: 'blob'
    id: 'blob'
    start: new timezoneJS.Date('2013-10-01T09:50').toISOString()
    end: new timezoneJS.Date('2013-10-01T10:50').toISOString()
    title: 'Blob adop'

  $('#calendar').fullCalendar
    editable: true
    startEditable: true
    durationEditable: true
    lazyFetching: true
    ignoreTimezone: false

    events: (start,end,next) ->
      logger "start:#{start},end:#{end}"
      query =
        #startkey: timezoneJS.Date(start)
        #endkey: timezoneJS.Date(end)
        include_docs: true
      db.allDocs query, (err,response) ->
        if err
          console.error err
          return
        logger JSON.stringify response
        next response.rows.map (row) -> row.doc

    eventDrop: (event,delta) ->
      alert event.title + 'was moved ' + delta + 'days'

    loading: (isLoading) ->
      if isLoading
        ($ '#loading').show()
      else
        ($ '#loading').hide()
