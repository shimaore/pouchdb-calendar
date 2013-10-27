#!/bin/sh
mkdir -p .db
couchdb -n -a /etc/couchdb/default.ini -a couchdb.ini
