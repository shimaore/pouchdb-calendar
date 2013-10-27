PouchDB Calendar
================

A syncable, in-browser calendar, using [PouchDB](https://github.com/daleharvey/pouchdb) and [FullCalendar](http://arshaw.com/fullcalendar/).

Use
===

The [online demo](http://shimaore.github.io/pouchdb-calendar/test/) maintains a working version.

To add an event, click on a day, or select a time-span in the day or week view. Click on the new (empty) event to give it some content. Similarly, click on an existing event to modify its content. Use drag-and-drop to modify the start and end times of an event, or to to convert an event from full-day to time-based and conversely.
To remove an event, click on the event and remove its content; the event will be deleted.

To replicate your local (in-browser) calendar database, first create the destination database on your CouchDB server, then enter its URL in the `Remote CouchDB` box at the bottom of the page. Two-way synchronization will start and will restart automatically when you access the page again.

Build
=====

You will need Node.js; the build is otherwise self-contained (`npm` will install the tools required).

    git clone https://github.com/shimaore/pouchdb-calendar.git
    npm install

To test, run

    www-browser pouchdb-calendar/test/index.html
