/*globals Pouch: true, call: false, ajax: true */
/*globals require: false, console: false */

"use strict";

var Pouch = require("pouchdb");
var SharePouch = require("./SharePouch");

Pouch.plugin('hub', SharePouch);
