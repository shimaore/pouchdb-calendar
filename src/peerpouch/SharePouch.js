var PeerConnectionHandler = require("./PeerConnectionHandler");
var PeerPouch = require('./PeerPouch');

var SharePouch = function (hub) {
    // NOTE: this plugin's methods are intended for use only on a **hub** database

    // this chunk of code manages a combined _changes listener on hub for any share/signal(/etc.) watchers
    var watcherCount = 0,         // easier to refcount than re-count!
        watchersByType = Object.create(null),
        changesListener = null;
    function addWatcher(type, cb) {
        var watchers = watchersByType[type] || (watchersByType[type] = []);
        watchers.push(cb);
        watcherCount += 1;
        if (watcherCount > 0 && !changesListener) {         // start listening for changes (at current sequence)
            var cancelListen = false;
            changesListener = {
                cancel: function () { cancelListen = true; }
            };
            hub.info(function (e,d) {
                if (e) throw e;
                var opts = {
                    //filter: _t.ddoc_name+'/signalling',             // see https://github.com/daleharvey/pouchdb/issues/525
                    include_docs: true,
                    continuous:true,
                    since:d.update_seq
                };
                opts.onChange = function (d) {
                    var watchers = watchersByType[d.doc.type];
                    if (watchers) watchers.forEach(function (cb) { cb(d.doc); });
                };
                if (!cancelListen) changesListener = hub.changes(opts);
                else changesListener = null;
            });
        }
        return {cancel: function () { removeWatcher(type, cb); }};
    }
    function removeWatcher(type, cb) {
        var watchers = watchersByType[type],
            cbIdx = (watchers) ? watchers.indexOf(cb) : -1;
        if (~cbIdx) {
            watchers.splice(cbIdx, 1);
            watcherCount -= 1;
        }
        if (watcherCount < 1 && changesListener) {
            changesListener.cancel();
            changesListener = null;
        }
    }

    var sharesByRemoteId = Object.create(null),         // ._id of share doc
        sharesByLocalId = Object.create(null);            // .id() of database
    function share(db, opts, cb) {
        if (typeof opts === 'function') {
            cb = opts;
            opts = {};
        } else opts || (opts = {});

        var share = {
            _id: 'share-'+Pouch.uuid(),
            type: _t.share,
            name: opts.name || null,
            info: opts.info || null
        };
        hub.post(share, function (e,d) {
            if (!e) share._rev = d.rev;
            if (cb) cb(e,d);
        });

        var peerHandlers = Object.create(null);
        share._signalWatcher = addWatcher(_t.signal, function receiveSignal(signal) {
            if (signal.recipient !== share._id) return;

            var self = share._id, peer = signal.sender, info = signal.info,
                handler = peerHandlers[peer];
            if (!handler) {
                handler = peerHandlers[peer] = new PeerConnectionHandler({initiate:false, _self:self, _peer:peer});
                handler.onhavesignal = function sendSignal(evt) {
                    hub.post({
                        _id:'s-signal-'+Pouch.uuid(), type:_t.signal,
                        sender:self, recipient:peer,
                        data:evt.signal, info:share.info
                    }, function (e) { if (e) throw e; });
                };
                handler.onconnection = function () {
                    if (opts.onRemote) {
                        var evt = {info:info},
                            cancelled = false;
                        evt.preventDefault = function () {
                            cancelled = true;
                        };
                        opts.onRemote.call(handler._rtc, evt);            // TODO: this is [still] likely to change!
                        if (cancelled) return;       // TODO: close connection
                    }
                    PeerPouch.bootstrap(handler,db);
                };
            }
            handler.receiveSignal(signal.data);
            hub.post({_id:signal._id,_rev:signal._rev,_deleted:true}, function (e) { if (e) console.warn("Couldn't clean up signal", e); });
        });
        sharesByRemoteId[share._id] = sharesByLocalId[db.id()] = share;
    }
    function unshare(db, cb) {            // TODO: call this automatically from _delete hook whenever it sees a previously shared db?
        var share = sharesByLocalId[db.id()];
        if (!share) return cb && setTimeout(function () {
            cb(new Error("Database is not currently shared"));
        }, 0);
        hub.post({_id:share._id,_rev:share._rev,_deleted:true}, cb);
        share._signalWatcher.cancel();
        delete sharesByRemoteId[share._id];
        delete sharesByLocalId[db.id()];
    }

    function _localizeShare(doc) {
        var name = [hub.id(),doc._id].map(encodeURIComponent).join('/');
        console.log("name = "+name);
        if (doc._deleted) delete PeerPouch._shareInitializersByName[name];
        else PeerPouch._shareInitializersByName[name] = function (opts) {
            var client = 'peer-'+Pouch.uuid(), share = doc._id,
                handler = new PeerConnectionHandler({initiate:true, _self:client, _peer:share});
            handler.onhavesignal = function sendSignal(evt) {
                hub.post({
                    _id:'p-signal-'+Pouch.uuid(), type:_t.signal,
                    sender:client, recipient:share,
                    data:evt.signal, info:opts.info
                }, function (e) { if (e) throw e; });
            };
            addWatcher(_t.signal, function receiveSignal(signal) {
                if (signal.recipient !== client || signal.sender !== share) return;
                handler.receiveSignal(signal.data);
                hub.post({_id:signal._id,_rev:signal._rev,_deleted:true}, function (e) { if (e) console.warn("Couldn't clean up signal", e); });
            });
            return handler;     /* for .onreceivemessage and .sendMessage use */
        };
        doc.dbname = 'webrtc://'+name;
        return doc;
    }

    function _isLocal(doc) {
        return (doc._id in sharesByRemoteId);
    }

    function getShares(opts, cb) {
        if (typeof opts === 'function') {
            cb = opts;
            opts = {};
        }
        opts || (opts = {});
        //hub.query(_t.ddoc_name+'/shares', {include_docs:true}, function (e, d) {
        hub.allDocs({include_docs:true}, function (e,d) {
            if (e) cb(e);
            else cb(null, d.rows.filter(function (r) {
                return (r.doc.type === _t.share && !_isLocal(r.doc));
            }).map(function (r) { return _localizeShare(r.doc); }));
        });
        if (opts.onChange) {            // WARNING/TODO: listener may get changes before cb returns initial list!
            return addWatcher(_t.share, function (doc) { if (!_isLocal(doc)) opts.onChange(_localizeShare(doc)); });
        }
    }

    return {shareDatabase:share, unshareDatabase:unshare, getSharedDatabases:getShares};
}

SharePouch._delete = function () {}; // blindly called by Pouch.destroy
