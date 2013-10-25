PouchDB Calendar
================

[PC]ouchDB storage: based on http://arshaw.com/fullcalendar/docs/event_data/Event_Object/

* `_id`: 'event' + ':' + start + ':' + id
* `id`: parent id for repeat events; otherwise a uuid
* `title`
* `allDay`
* `start`: as ISO8601 (no timezone meaning "local time")
* `end`: as ISO8601 (no timezone meaning "local time")

Note: repeat events are stored as individual entries (created when the event is created) which all relate back to a master event. (Master event format is TBD -- basically they are some kind of generic date-related algorithm.)

Which events to display:
(always assuming start < end and event.start < event.end)
(also assuming we won't query lower than one day)

* events where event.end >= start (1) and
* events where event.start < end  (2)

    event ----------------------
    window           start^        end^
    event ------------------------------------
    window           start^        end^
    event                      ---------------
    window           start^        end^

So the order we are interested in is

start < event.end and
event.start < end

So: build a view with event.start and event.end as keys; and walk it from start to end; remove any event that doesn't match the criteria.
