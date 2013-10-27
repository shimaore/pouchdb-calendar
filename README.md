PouchDB Calendar
================

A syncable, in-browser, calendar, using [PouchDB](https://github.com/daleharvey/pouchdb).

Use
===

Build
=====

You will need Node.js; the build is otherwise self-contained (`npm` will install the tools required).

    git clone https://github.com/shimaore/pouchdb-calendar.git
    npm install

To test, run
or simply go to the [Demo](http://shimaore.github.io/pouchdb-calendar/test/).

    www-browser pouchdb-calendar/test/index.html
To replicate, first create the destination database on your CouchDB server, then enter its URL in the `Remote CouchDB` box at the bottom of the page. Two-way synchronization will start.
