package hxonline.net;

import haxe.Exception;
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

	/**
	 * 线程管理
	 */
	private static var _thrad:ThreadPool;

	private var _websocket:haxe.net.WebSocket;

	private var url:String;

	private var protocols:Array<String>;

	private var origin:String;

	private static var debug:Bool;

	public function new(url:String, protocols:Array<String> = null, origin:String = null, debug:Bool = false) {
		thradId = ++_id;
		this.url = url;
		this.protocols = protocols;
		this.origin = origin;
		LimeWebSocket.debug = debug;
		// 测试
		// LimeWebSocket.debug = true;
		if (_thrad == null) {
			// 创建一个独立线程
			_thrad = new ThreadPool();
			_thrad.doWork.add(threadPool_doWork);
			_thrad.onComplete.add(threadPool_doComplete);
		}
		queue(CREATE);
		processLoop();
	}

	/**
	 * 向线程发送指令
	 * @param type 
	 */
	private function queue(type:SocketApi, ?data:Dynamic):Void {
		trace("queue", type, thradId);
		var stateObj:LimeWebSocketThred = {
			socket: this,
			type: type,
			data: data
		};
		_thrad.queue(stateObj);
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
			_thrad.sendError();
			if (this.onerror != null)
				this.onerror(e);
		});
	}

	private function __onClose(?e:Dynamic):Void {
		MainLoop.runInMainThread(() -> {
			// _thrad.sendComplete();
			if (this.onclose != null)
				this.onclose(e);
		});
	}

	private function __onOpen():Void {
		MainLoop.runInMainThread(() -> {
			if (this.onopen != null)
				this.onopen();
			if (_hasOpenGoClose) {
				this.close();
			}
		});
	}

	public var readyState(get, never):ReadyState;

	function get_readyState():ReadyState {
		return _websocket != null ? _websocket.readyState : Connecting;
	}

	private var _hasOpenGoClose = false;

	public function close():Void {
		if (this.readyState == Open) {
			this.queue(CLOSE);
		} else {
			// 当发生Open时，进行关闭
			_hasOpenGoClose = true;
		}
	}

	public var onopen:Void->Void;

	public var onmessageBytes:Bytes->Void;

	public var onmessageString:String->Void;

	public var onclose:Dynamic->Void;

	public function sendString(data:String):Void {
		this.queue(SEND_STRING, data);
	}

	public function sendBytes(data:Bytes):Void {
		this.queue(SEND_BYTES, data);
	}

	public var onerror:Dynamic->Void;

	public function process():Void {
		// 使用processLoop代替
	}

	public function processLoop():Void {
		this.queue(PROCESS);
	}

	public static function threadPool_doWork(state:Dynamic):Void {
		var stateObj:LimeWebSocketThred = state;
		if (stateObj == null || stateObj.socket == null) {
			trace("[inval]");
			return;
		}
		var _websocket = stateObj.socket._websocket;
		if (_websocket != null) {
			if (_websocket.readyState == Closed) {
				if (debug)
					trace("[hxonline]阻止行为" + state.type, stateObj.socket.thradId);
				return;
			}
			if (debug) {
				trace("[hxonline]", state.type, stateObj.socket.thradId);
			}
		}
		switch (stateObj.type) {
			case CREATE:
				_websocket = haxe.net.WebSocket.create(stateObj.socket.url, stateObj.socket.protocols, stateObj.socket.origin, LimeWebSocket.debug);
				_websocket.onclose = stateObj.socket.__onClose;
				_websocket.onopen = stateObj.socket.__onOpen;
				_websocket.onerror = stateObj.socket.__onError;
				_websocket.onmessageBytes = stateObj.socket.__onMessageBytes;
				_websocket.onmessageString = stateObj.socket.__onMessageString;
				stateObj.socket._websocket = _websocket;
			case SEND_STRING:
				if (_websocket != null)
					_websocket.sendString(stateObj.data);
			case SEND_BYTES:
				if (_websocket != null)
					_websocket.sendBytes(stateObj.data);
			case PROCESS:
				if (_websocket == null)
					return;
				_websocket.process();
				MainLoop.runInMainThread(() -> {
					stateObj.socket.processLoop();
				});
			case CLOSE:
				if (_websocket != null)
					_websocket.close();
		}
	}

	public static function threadPool_doComplete(state:Dynamic):Void {
		if (debug) {
			var stateObj:LimeWebSocketThred = state;
			trace("[hxonline]Thread Closed,thradId = " + stateObj.socket.thradId);
		}
	}
}

typedef LimeWebSocketThred = {
	type:SocketApi,
	socket:LimeWebSocket,
	?data:Dynamic
};

enum abstract SocketApi(String) {
	var CREATE = "create";
	var SEND_STRING = "sendString";
	var SEND_BYTES = "sendBytes";
	var PROCESS = "process";
	var CLOSE = "close";
}
#end
