# db_url = "#{window.location.protocol}//#{window.location.host}/calendar"
# db_url = "https://shimaore.net:6984/calendar"
db_url = "calendar"

{logger} = require './tools.coffee'

# TODO try with moment.timezone instead?
timezoneJS = require 'timezone-js'
zone_files = require './timezones.coffee'

do ->
  timezoneJS.timezone.zoneFileBasePath = 'tz'
  timezoneJS.timezone.transport = (opts) ->
    url = opts.url.replace /^\/?tz\//, ''
    if opts.async
      if typeof opts.success isnt 'function'
        return
      opts.error ?= logger
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

# moment = require '../bower_components/momentjs/moment.js'
moment = require 'moment'
# moment_format = 'YYYY-MM-DDTHH:mm:ssZ'
#
# Data inside the PouchDB records is stored as moment().format() data (i.e. ISO8601 with timezone).

fullcalendar = require '../bower_components/fullcalendar/fullcalendar.js'

make_fun = (f) -> "(#{f})"

$(document).ready -> moonshine ->

  db = new PouchDB db_url

  # The goal here is to generate one entry at least per week
  # for any event that might span that week.
  # This way when looking-up records we don't have to span the entire
  # database.
  # FIXME? This might be easier to do with spatial indexing?
  db.get '_design/calendar', (err,doc) ->
    p =
      _id: '_design/calendar'
      language: 'javascript'
      views:
        # This view uses a generic 'toJSON' (no timezone) format.
        locate:
          map: make_fun (doc) ->
            return unless doc.type? and doc.type is 'event'
            return unless doc.start?
            start = new Date doc.start
            emit start.toJSON(), null
            if doc.end?
              end = new Date doc.end
              while start < end
                start = new Date start.valueOf()+7*24*3600*1000
                emit start.toJSON(), null
              emit end.toJSON(), null

    p._rev = doc._rev if doc?
    db.put p

  ###
  db.get 'blob', (err,doc) ->
    p =
      _id: 'blob'
      id: 'blob' # parent id for fullCalendar
      start: moment('2013-10-01T09:50-02:00').format()
      end: moment('2013-10-01T10:50-02:00').format()
      title: 'Blob adop'
      allDay: false
    p._rev = doc._rev if doc?
    db.put p
  ###

  load_events = (start,end,next) ->
    query =
      startkey: moment(start).add(-1,'week').toJSON()
      endkey: moment(end).add(1,'week').toJSON()
      include_docs: true
    db.query 'calendar/locate', query, (err,response) ->
      if err
        logger err
        return

      # remove duplicate _ids
      uniq = {}
      for row in response.rows
        classes_for_event row.doc
        uniq[row.id] ?= row.doc
      next (v for k,v of uniq)
      return

  delta_save = (event,next) ->
    db.get event._id, (err,doc) ->
      if err
        logger err
        return next false

      doc.start = moment(event.start).format()
      if event.end?
        doc.end = moment(event.end).format()
      else
        delete doc.end
      doc.allDay = event.allDay

      db.put doc, (err,doc) ->
        if err or not doc.ok
          next false
        else
          next true

  field_save = (field,event,next) ->
    db.get event._id, (err,doc) ->
      if err
        logger err
        return next false

      if typeof field is 'string'
        doc[field] = event[field]
      else
        for f in field
          doc[f] = event[f]

      db.put doc, (err,doc) ->
        if err or not doc.ok
          next false
        else
          next true

  remove_event = (event,next) ->
    event._deleted = true
    field_save '_deleted', event, next

  drop_event = (event,dayDelta,minuteDelta,allDay,revert) ->
    delta_save event, (ok) ->
      if not ok then revert()

  resize_event = (event, dayDelta, minuteDelta, revert) ->
    delta_save event, (ok) ->
      if not ok then revert()

  classes_for_event = (event) ->
    classes = event.title?.match /#\w+/g
    if classes?
      event.className = classes.map (t) -> t.substr 1

  calendar = -> ($ '#calendar').fullCalendar arguments...

  event_click = (event) ->
    $(this).html '<input />'
    $(this).find('input').val(event.title).focus().blur ->
      title = $(this).val().trim()
      if title is ''
        remove_event event, (ok) ->
          if ok then calendar 'removeEvents', (e) ->
            return e._id is event._id
      else
        event.title = title
        classes_for_event event
        field_save 'title', event, (ok) ->
          if ok then calendar 'updateEvent', event

  select = (start,end,allDay) ->
    doc =
      type: 'event'
      start: moment(start).format()
      allDay: allDay
      title: ' '

    doc.end = moment(end).format() if end

    db.post doc, (err,response) ->
      if err or not response.ok
        logger err
        calendar 'refetchEvents'
        return
      doc._id = response.id
      doc._rev = response.rev
      event = doc
      calendar 'addEventSource', [event]

  show_loading = (isLoading) ->
    if isLoading
      ($ '#loading').show()
    else
      ($ '#loading').hide()

  @get '': ->

    day_click = (date,allDay) =>
      # calendar 'changeView', 'agendaWeek'
      calendar 'gotoDate', date

    calendar
      editable: true
      selectable: true
      selectHelper: true
      eventStartEditable: true
      eventDurationEditable: true
      lazyFetching: true
      ignoreTimezone: false

      header:
        left: 'title'
        center: 'agendaDay,agendaWeek,month'
        right: 'prevYear,prev,today,next,nextYear'
      timeFormat: 'HH:mm'
      allDayText: 'All Day'
      axisFormat: 'HH:mm'
      firstHour: 6
      firstDay: 1
      weekNumbers: true

      events: load_events
      eventDrop: drop_event
      eventResize: resize_event
      loading: show_loading
      dayClick: day_click
      eventClick: event_click
      select: select

    # Do not force a refresh on each event.
    pending_refresh = null
    refresh = ->
      calendar 'refetchEvents'
      pending_refresh = null

    on_change = ->
      replication_status 'Running'
      pending_refresh ?= setTimeout refresh, 500

    replication_status = (t) ->
      ($ '.replication-status').text t

    start_replication = (url) ->
      if url isnt ''
        do replicate_to = ->
          db.replicate.to url, continuous: true, (err) ->
            replication_status 'Failed, retrying in 10s...'
            setTimeout replicate_to, 10000

        do replicate_from = ->
          db.replicate.from url, continuous: true, onChange: on_change, (err) ->
            replication_status 'Failed, retrying in 10s...'
            setTimeout replicate_from, 10000

        replication_status 'Started'


    db.get 'replicate', (err,doc) ->
      if doc?.url?
        ($ '#replicate').find('.url').val doc.url
        start_replication doc.url

    ($ '#replicate').find('.url').change ->
      url = $(this).val().trim()
      db.get 'replicate', (err,doc) ->
        if doc?
          doc.url = url
          db.put doc
        else
          doc =
            _id: 'replicate'
            url: url
          db.put doc

        start_replication url

    logger 'Started'
