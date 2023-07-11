package hxonline.net;

import haxe.MainLoop;
import haxe.io.Bytes;
import haxe.net.WebSocket.ReadyState;
import lime.system.ThreadPool;

#if lime
/**
 * 带线程支持的WebSocket
 */
class LimeWebSocket {
	public static function create(url:String, protocols:Array<String> = null, origin:String = null, debug:Bool = false):WebSocket {
		var lime = new LimeWebSocket(url, protocols, origin, debug);
		return lime;
	}

	private static var _id:Int = 0;

	public var thradId:Int = 0;

	private var _thrad:ThreadPool = new ThreadPool();

	private var _websocket:haxe.net.WebSocket;

	private var url:String;

	private var protocols:Array<String>;

	private var origin:String;

	private var debug:Bool;

	public function new(url:String, protocols:Array<String> = null, origin:String = null, debug:Bool = false) {
		thradId = ++_id;
		this.url = url;
		this.protocols = protocols;
		this.origin = origin;
		this.debug = debug;
		_thrad.doWork.add(threadPool_doWork);
		_thrad.onComplete.add(threadPool_doComplete);
		_thrad.queue({type: "create"});
		processLoop();
	}

	private function __onMessageString(data:String):Void {
		MainLoop.runInMainThread(() -> {
			if (this.onmessageString != null)
				this.onmessageString(data);
		});
	}

	private function __onMessageBytes(bytes:Bytes):Void {
		MainLoop.runInMainThread(() -> {
			if (this.onmessageBytes != null)
				this.onmessageBytes(bytes);
		});
	}

	private function __onError(?e:Dynamic):Void {
		MainLoop.runInMainThread(() -> {
			if (this.onerror != null)
				this.onerror(e);
		});
	}

	private function __onClose(?e:Dynamic):Void {
		MainLoop.runInMainThread(() -> {
			if (this.onclose != null)
				this.onclose(e);
		});
	}

	private function __onOpen():Void {
		MainLoop.runInMainThread(() -> {
			if (this.onopen != null)
				this.onopen();
		});
	}

	public var readyState(get, never):ReadyState;

	function get_readyState():ReadyState {
		return _websocket != null ? _websocket.readyState : Connecting;
	}

	public function close():Void {
		trace("close!", thradId);
		_thrad.queue({type: "close"});
	}

	public var onopen:Void->Void;

	public var onmessageBytes:Bytes->Void;

	public var onmessageString:String->Void;

	public var onclose:Dynamic->Void;

	public function sendString(data:String):Void {
		_thrad.queue({
			type: "sendString",
			data: data
		});
	}

	public function sendBytes(data:Bytes):Void {
		_thrad.queue({
			type: "sendBytes",
			data: data
		});
	}

	public var onerror:Dynamic->Void;

	public function process():Void {
		// _thrad.queue({type: "process"});
	}

	public function processLoop():Void {
		_thrad.queue({type: "process"});
	}

	public function threadPool_doWork(state:Dynamic):Void {
		switch (state.type) {
			case "create":
				_websocket = haxe.net.WebSocket.create(url, protocols, origin, debug);
				_websocket.onclose = __onClose;
				_websocket.onopen = __onOpen;
				_websocket.onerror = __onError;
				_websocket.onmessageBytes = __onMessageBytes;
				_websocket.onmessageString = __onMessageString;
			case "sendString":
				if (_websocket != null)
					_websocket.sendString(state.data);
			case "sendBytes":
				if (_websocket != null)
					_websocket.sendBytes(state.data);
			case "process":
				if (_websocket != null)
					_websocket.process();
				if (_websocket.readyState == Closed)
					return;
				MainLoop.runInMainThread(() -> {
					processLoop();
				});
			case "close":
				if (_websocket != null)
					_websocket.close();
				_thrad.sendComplete();
		}
	}

	public function threadPool_doComplete(state:Dynamic):Void {
		//
		trace("线程结束");
	}
}
#end
