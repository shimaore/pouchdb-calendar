function RPCHandler(tube) {
    this.onbootstrap = null;        // caller MAY provide this

    this._exposed_fns = Object.create(null);
    this.serialize = function (obj) {
        var messages = [];
        messages.push(JSON.stringify(obj, function (k,v) {
            if (typeof v === 'function') {
                var id = Math.random().toFixed(20).slice(2);
                this._exposed_fns[id] = v;
                return {__remote_fn:id};
            } else if (Object.prototype.toString.call(v) === '[object IDBTransaction]') {
                // HACK: pouch.idb.js likes to bounce a ctx object around but if we null it out it recreates
                // c.f. https://github.com/daleharvey/pouchdb/commit/e7f66a02509bd2a9bd12369c87e6238fadc13232
                return;

                // TODO: the WebSQL adapter also does this but does NOT create a new transaction if it's missing :-(
                // https://github.com/daleharvey/pouchdb/blob/80514c7d655453213f9ca7113f327424969536c4/src/adapters/pouch.websql.js#L646
                // so we'll have to either get that fixed upstream or add remote object references (but how to garbage collect? what if local uses?!)
            } else if (_isBlob(v)) {
                var n = messages.indexOf(v) + 1;
                if (!n) n = messages.push(v);
                return {__blob:n};
            } else return v;
        }.bind(this)));
        return messages;
    };

    var blobsForNextCall = [];                  // each binary object is sent before the function call message
    this.deserialize = function (data) {
        if (typeof data === 'string') {
            return JSON.parse(data, function (k,v) {
                if (v && v.__remote_fn) return function () {
                    this._callRemote(v.__remote_fn, arguments);
                }.bind(this);
                else if (v && v.__blob) {
                    var b = blobsForNextCall[v.__blob-1];
                    if (!_isBlob(b)) b = new Blob([b]);       // `b` may actually be an ArrayBuffer
                    return b;
                }
                else return v;
            }.bind(this));
            blobsForNextCall.length = 0;
        } else blobsForNextCall.push(data);
    };

    function _isBlob(obj) {
        var type = Object.prototype.toString.call(obj);
        return (type === '[object Blob]' || type === '[object File]');
    }

    this._callRemote = function (fn, args) {
        // console.log("Serializing RPC", fn, args);
        var messages = this.serialize({
            fn: fn,
            args: Array.prototype.slice.call(args)
        });
        if (window.mozRTCPeerConnection) messages.forEach(function (msg) { tube.send(msg); });
        else processNext();
        // WORKAROUND: Chrome (as of M32) cannot send a Blob, only an ArrayBuffer. So we send each once converted…
        function processNext() {
            var msg = messages.shift();
            if (!msg) return;
            if (_isBlob(msg)) {
                var r = new FileReader();
                r.readAsArrayBuffer(msg);
                r.onload = function () {
                    tube.send(r.result);
                    processNext();
                }
            } else {
                tube.send(msg);
                processNext();
            }
        }
    };

    this._exposed_fns['__BOOTSTRAP__'] = function () {
        if (this.onbootstrap) this.onbootstrap.apply(this, arguments);
    }.bind(this);


    tube.onmessage = function (evt) {
        var call = this.deserialize(evt.data);
        if (!call) return;      //

        var fn = this._exposed_fns[call.fn];
        if (!fn) {
            console.warn("RPC call to unknown local function", call);
            return;
        }

        // leak only callbacks which are marked for keeping (most are one-shot)
        if (!fn._keep_exposed) delete this._exposed_fns[call.fn];

        try {
            // console.log("Calling RPC", fn, call.args);
            fn.apply(null, call.args);
        } catch (e) {           // we do not signal exceptions remotely
            console.warn("Local RPC invocation unexpectedly threw: "+e, e);
        }
    }.bind(this);
}

RPCHandler.prototype.bootstrap = function () {
    this._callRemote('__BOOTSTRAP__', arguments);
};

if( module && module.exports ) {
  module.exports = RPCHandler;
}
