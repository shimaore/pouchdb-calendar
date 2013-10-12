FIXME autodetected database

    # db_url = "#{window.location.protocol}//#{window.location.host}/calendar"
    db_url = "https://shimaore.net:6984/calendar"

    timezoneJS.timezone.zoneFileBasePath = './bower_components/tzdata2013g.tar.gz'
    timezoneJS.timezone.init()

    $(document).ready ->
      alert 'Yeah'

      db = new PouchDB db_url

      $('#calendar').fullCalendar
        editable: true
        startEditable: true
        durationEditable: true
        lazyFetching: true
        ignoreTimezone: false

        events: (start,end,next) ->
          query =
            startkey: start.
            endkey: end
            include_docs: true
          db.allDocs query, (err,response) ->
            if err
              console.error err
              return
            next response.map (row) -> row.doc

        eventDrop: (event,delta) ->
          alert event.title + 'was moved ' + delta + 'days'

        loading: (isLoading) ->
          if isLoading
            ($ '#loading').show()
          else
            ($ '#loading').hide()

[PC]ouchDB storage: based on http://arshaw.com/fullcalendar/docs/event_data/Event_Object/

* `_id`: 'event' + ':' + start + ':' + id
* `id`: parent id for repeat events; otherwise a uuid
* `title`
* `allDay`
* `start`: as ISO8601 (no timezone meaning "local time")
* `end`: as ISO8601 (no timezone meaning "local time")

Note: repeat events are stored as individual entries (created when the event is created) which all relate back to a master event. (Master event format is TBD -- basically they are some kind of generic date-related algorithm.)
