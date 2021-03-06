PouchDB Calendar
================

A syncable, in-browser calendar, using [PouchDB](https://github.com/daleharvey/pouchdb) and [FullCalendar](http://arshaw.com/fullcalendar/).

Use
===

The [online demo](http://shimaore.github.io/pouchdb-calendar/test/) maintains a working version.

To add an event, click on a day in the month view, or select a time-span in the day or week view. Click on the new (empty) event to add content. Similarly, click on an existing event to modify its content. Use drag-and-drop to modify the start and end times of an event, or to to convert an event from full-day to time-based and conversely. You might also modify the start time (in HH:MM format) by typing the new time at the beginning of the event label; use HH:MM-HH:MM to change the start and end times.
To remove an event, click on the event and clear its content; the event will be deleted.
Events classes are created by using the `#name` hash-tag syntax. Each event classes is mapped to attributes such as color.

To replicate your local (in-browser) calendar database, first create the destination database on your CouchDB server, then enter its URL in the `Remote CouchDB` box at the bottom of the page. Two-way synchronization will start and will restart automatically when you access the page again.
Your CouchDB server needs to have CORS enabled. Look into the `test/couchdb.ini` file on how to do that.
If you are using the `start-couchdb.sh` script in the `test` folder to start a per-user, local CouchDB instance, use `http://127.0.0.1:25984/calendar` as the URL.

Build
=====

You will need Node.js; the build is otherwise self-contained (`npm` will install the tools required).

    git clone https://github.com/shimaore/pouchdb-calendar.git
    cd pouchdb-calendar && npm install

To test, run

    www-browser pouchdb-calendar/test/index.html

To test with a local CouchDB database, install CouchDB then run

    (cd test && ./start-couchdb.sh) &

The database will be created in `test/.db/`.
