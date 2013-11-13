var Pouch = require('pouchdb');
var RPCHandler = require("./RPCHandler");

Pouch.Errors.FORBIDDEN = {status:403, error:'forbidden', reason:"The request was refused"};
var PeerPouch = function(opts, handler, callback) {

    var api = {};       // initialized later, but Pouch makes us return this before it's ready

    handler.onconnection = function () {

        var rpc = new RPCHandler(handler._tube());
        rpc.onbootstrap = function (d) {      // share will bootstrap
            var rpcAPI = d.api;

            // simply hook up each [proxied] remote method as our own local implementation
            Object.keys(rpcAPI).forEach(function (k) { api[k]= rpcAPI[k]; });

            // one override to provide a synchronous `.cancel()` helper locally
            api._changes = function (opts) {
                if (opts.onChange) opts.onChange._keep_exposed = true;      // otherwise the RPC mechanism tosses after one use
                var cancelRemotely = null,
                    cancelledLocally = false;
                rpcAPI._changes(opts, function (rpcCancel) {
                    if (cancelledLocally) rpcCancel();
                    else cancelRemotely = rpcCancel;
                });
                return {cancel:function () {
                    if (cancelRemotely) cancelRemotely();
                    else cancelledLocally = true;
                    if (opts.onChange) delete opts.onChange._keep_exposed;  // allow for slight chance of cleanup [if called again]
                }};
            };

            api._id = function () {
                // TODO: does this need to be "mangled" to distinguish it from the real copy?
                //       [it seems unnecessary: a replication with "api" is a replication with "rpcAPI"]
                return rpcAPI._id;
            };

            // now our api object is *actually* ready for use
            if (callback) callback(null, api);
        };
    };

    return api;
};

PeerPouch.bootstrap = function(handler,db) {
  var rpc = new RPCHandler(handler._tube());
  rpc.bootstrap({
    api: PeerPouch._wrappedAPI(db)
  });
}

PeerPouch._wrappedAPI = function (db) {
    /*
        This object will be sent over to the remote peer. So, all methods on it must be:
        - async-only (all "communication" must be via callback, not exceptions or return values)
        - secure (peer could provide untoward arguments)
    */
    var rpcAPI = {};


    /*
        This lists the core "customApi" methods that are expected by pouch.adapter.js
    */
    var methods = ['bulkDocs', '_getRevisionTree', '_doCompaction', '_get', '_getAttachment', '_allDocs', '_changes', '_close', '_info', '_id'];

    // most methods can just be proxied directly
    methods.forEach(function (k) {
        rpcAPI[k] = db[k];
        if (rpcAPI[k]) rpcAPI[k]._keep_exposed = true;
    });

    // one override, to pass the `.cancel()` helper via callback to the synchronous override on the other side
    rpcAPI._changes = function (opts, rpcCB) {
        var retval = db._changes(opts);
        rpcCB(retval.cancel);
    }
    rpcAPI._changes._keep_exposed = true;

    // just send the local result
    rpcAPI._id = db.id();

    return rpcAPI;
};

// Don't bother letting peers nuke each others' databases
PeerPouch.destroy = function(name, callback) {
    if (callback) setTimeout(function () { callback(Pouch.Errors.FORBIDDEN); }, 0);
};

// Can we breathe in this environment?
PeerPouch.valid = function() {
    // TODO: check for WebRTC+DataConnection support
    return true;
};

PeerPouch._types = {
    presence: 'com.stemstorage.peerpouch.presence',
    signal: 'com.stemstorage.peerpouch.signal',
    share: 'com.stemstorage.peerpouch.share'
}

// Register for our scheme
Pouch.adapter('webrtc', PeerPouch);

// Debug
Pouch.dbgPeerPouch = PeerPouch;

// Implements the API for dealing with a PouchDB peer's database over WebRTC
PeerPouch._shareInitializersByName = Object.create(null); 
PeerPouch._init = function(opts, callback) {
    var _init = PeerPouch._shareInitializersByName[opts.name];
    if (!_init) throw Error("Unknown PeerPouch share dbname");      // TODO: use callback instead?

    var handler = _init(opts);
    return PeerPouch(opts,handler,callback);
}

if(module && module.exports) {
  module.exports = PeerPouch;
}
