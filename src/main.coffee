# db_url = "#{window.location.protocol}//#{window.location.host}/calendar"
# db_url = "https://shimaore.net:6984/calendar"
db_url = "calendar"

{logger} = require './tools.coffee'

timezoneJS = require 'timezone-js'
zone_files = require './timezones.coffee'

do ->
  timezoneJS.timezone.zoneFileBasePath = 'tz'
  timezoneJS.timezone.transport = (opts) ->
    url = opts.url.replace /^\/?tz\//, ''
    if opts.async
      if typeof opts.success isnt 'function'
        return
      opts.error ?= console.error
      opts.success zone_files[url]
      # opts.error(err) not used
    else
      return zone_files[url]

  timezoneJS.timezone.init()

$ = jQuery = require 'jquery-browserify'
moonshine = require 'moonshine-browserify'
pouchdb = require './pouchdb-nightly'

jquery_ui_core = require '../bower_components/jquery-ui/ui/jquery.ui.core.js'
jquery_ui_widget = require '../bower_components/jquery-ui/ui/jquery.ui.widget.js'
jquery_ui_mouse = require '../bower_components/jquery-ui/ui/jquery.ui.mouse.js'
jquery_ui_draggable = require '../bower_components/jquery-ui/ui/jquery.ui.draggable.js'
jquery_ui_resizable = require '../bower_components/jquery-ui/ui/jquery.ui.resizable.js'

fullcalendar = require '../bower_components/fullcalendar/fullcalendar.js'

second = 1000
hour = 3600*second
day = 24*hour
week = 7*day

make_fun = (f) -> "(#{f})"

$(document).ready -> moonshine ->

  db = new PouchDB db_url

  # The goal here is to generate one entry at least per week
  # for any event that might span that week.
  # This way when looking-up records we don't have to span the entire
  # database.
  # FIXME? This might be easier to do with geo tools.
  db.get '_design/calendar', (err,doc) ->
    p =
      _id: '_design/calendar'
      language: 'javascript'
      views:
        locate:
          map: make_fun (doc) ->
            return unless doc.start? and doc.end?
            week = 7*24*3600*1000
            start = new Date(doc.start).valueOf()
            end = new Date(doc.end).valueOf()
            while start < end
              emit start, null
              start += week
            emit end, null
    p._rev = doc._rev if doc?
    db.put p

  db.get 'blob', (err,doc) ->
    p =
      _id: 'blob'
      id: 'blob' # parent id for fullCalendar
      start: new timezoneJS.Date('2013-10-01T09:50').toISOString()
      end: new timezoneJS.Date('2013-10-01T10:50').toISOString()
      title: 'Blob adop'
      allDay: false
    p._rev = doc._rev if doc?
    db.put p

  load_events = (start,end,next) ->
    query =
      startkey: new timezoneJS.Date(start).valueOf()-week
      endkey: new timezoneJS.Date(end).valueOf()+week
      include_docs: true
    console.log query
    db.query 'calendar/locate', query, (err,response) ->
      if err
        console.error err
        return

      # remove duplicate _ids
      uniq = {}
      for row in response.rows
        uniq[row.id] ?= row.doc
      next (v for k,v of uniq)
      return

  drop_event = (event,delta) ->
    console.log event
    console.log event.title + ' was moved ' + delta + 'days'

  show_loading = (isLoading) ->
    if isLoading
      ($ '#loading').show()
    else
      ($ '#loading').hide()

  @get '': ->
    $('#calendar').fullCalendar
      editable: true
      startEditable: true
      durationEditable: true
      lazyFetching: true
      ignoreTimezone: false

      timeFormat: 'H(:mm)'

      events: load_events
      eventDrop: drop_event
      loading: show_loading

   console.log 'Started'
