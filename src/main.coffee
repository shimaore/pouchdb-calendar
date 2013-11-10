# db_url = "#{window.location.protocol}//#{window.location.host}/calendar"
# db_url = "https://shimaore.net:6984/calendar"
db_url = "calendar"

{logger} = require './tools.coffee'

# TODO try with moment.timezone instead?
timezoneJS = require 'timezone-js'
zone_files = require './timezones.coffee'

{ColorFactory} = require 'node-colorfactory'

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

moment = require 'moment'
# moment_format = 'YYYY-MM-DDTHH:mm:ssZ'

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

  # Load events to be displayed on a calendar view.
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

  # Update a document from an event time components.
  update_delta = (doc,event) ->
    doc.start = moment(event.start).format()
    if event.end?
      doc.end = moment(event.end).format()
    else
      delete doc.end
    doc.allDay = event.allDay


  # Save the time components of an event object.
  delta_save = (event,next) ->
    db.get event._id, (err,doc) ->
      if err
        logger err
        return next false

      update_delta doc, event

      db.put doc, (err,doc) ->
        if err or not doc.ok
          logger err
          next false
        else
          next true

  # Save the time components and the title of an event object.
  delta_title_save = (event,next) ->
    db.get event._id, (err,doc) ->
      if err
        logger err
        return next false

      update_delta doc, event
      doc.title = event.title

      db.put doc, (err,doc) ->
        if err or not doc.ok
          logger err
          next false
        else
          next true

  # Save one or more fields of an event object.
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
          logger err
          next false
        else
          next true

  # Remove an event from the database.
  remove_event = (event,next) ->
    event._deleted = true
    field_save '_deleted', event, next

  # Handle an event being moved on the calendar.
  drop_event = (event,dayDelta,minuteDelta,allDay,revert) ->
    delta_save event, (ok) ->
      if not ok then revert()

  # Handle the end of an event being modified on the calendar.
  resize_event = (event, dayDelta, minuteDelta, revert) ->
    delta_save event, (ok) ->
      if not ok then revert()

  # Apply CSS classes to an event, based on hash-tags in its title.

  build_style = (name,v) ->
    style = []
    if v.bold
      style.push "font-weight: bold;"
    if v.color
      style.push "color: #{v.color};"
    if v.background
      style.push "background-color: #{v.background};"
    ($ "style#calendar-#{name}").remove()
    ($ '<style>').
      prop('id',"calendar-#{name}").
      prop('type','text/css').
      html(".calendar-#{name} { #{ style.join '' } }").
      appendTo 'head'
    console.log "Built style for #{name}"

  preferences = {}
  db.get 'preferences', (err,doc) ->
    if doc?
      preferences = doc
    else
      preferences =
        _id: 'preferences'
        classes: {}

    if preferences.classes?
      for k,v of preferences.classes
        build_style k,v

  save_preferences = (next) ->
    db.get 'preferences', (err,doc) ->
      preferences._rev = doc._rev if doc?._rev?
      db.put preferences, (err) ->
        if err?
          logger err
          return
        next?()

  new_class = (name) ->
    return if preferences.classes[name]?
    preferences.classes[name] =
      background: ColorFactory.randomHue(45,42)
    save_preferences ->
      build_style name, preferences.classes[name]

  classes_for_event = (event) ->
    classes = event.title?.match /#\w+/g
    if classes?
      event.className = classes.map (t) ->
        name = t.substr 1
        new_class name
        "calendar-#{name}"

  calendar = -> ($ '#calendar').fullCalendar arguments...

  # Handle click on an event.
  event_click = (event) ->

    update_event_if_ok = (ok) ->
      if ok then calendar 'updateEvent', event

    $(this).html '<input />'
    $(this).find('input').val(event.title).focus().blur ->
      title = $(this).val().trim()
      if title is ''
        remove_event event, (ok) ->
          if ok then calendar 'removeEvents', (e) ->
            return e._id is event._id
      else
        if m = title.match /^(\d\d):(\d\d) *- *(\d\d):(\d\d) *(.*)$/
          # Set start and end times
          start_hour = parseInt m[1]
          start_min = parseInt m[2]
          end_hour = parseInt m[3]
          end_min = parseInt m[4]
          event.start = moment(event.start).hour(start_hour).minute(start_min).format()
          event.end = moment(event.start).hour(end_hour).minute(end_min).format()
          event.allDay = false
          event.title = m[5]
          delta_title_save event, update_event_if_ok
        else if m = title.match /^(\d\d):(\d\d) *(.*)$/
          start_hour = parseInt m[1]
          start_min = parseInt m[2]
          if event.end?
            # Compute the delta
            old_start = moment(event.start)
            new_start = moment(old_start).hour(start_hour).minute(start_min)
            delta = new_start.diff old_start
            console.log "Delta is #{delta}"
            event.start = new_start.format()
            event.end = moment(event.end).add(delta).format()
            event.allDay = false
          else
            # Set start time
            event.start = moment(event.start).hour(m[1]).minute(m[2]).format()
            event.allDay = false
          event.title = m[3]
          delta_title_save event, update_event_if_ok
        else
          event.title = title
          classes_for_event event
          field_save 'title', event, update_event_if_ok

  # Handle event creation (via selection) on the calendar.
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

  # Show or hide the `loading` indicator.
  show_loading = (isLoading) ->
    if isLoading
      ($ '#loading').show()
    else
      ($ '#loading').hide()

  # Default processing
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
      contentHeight: 450
      defaultView: 'agendaWeek'
      firstHour: 8

      events: load_events
      eventDrop: drop_event
      eventResize: resize_event
      loading: show_loading
      dayClick: day_click
      eventClick: event_click
      select: select

    # Do not force a refresh on each replication change.
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

    # Load the replication URL and start replicating (at startup).
    db.get 'replicate', (err,doc) ->
      if doc?.url?
        ($ '#replicate').find('.url').val doc.url
        start_replication doc.url

    # If the replication URL is changed, save it and start replicating.
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
