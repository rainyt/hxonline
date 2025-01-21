package hxonline.net;

import lime.utils.ObjectPool;
import haxe.Exception;
import haxe.io.Bytes;
import lime.system.WorkOutput;
import haxe.MainLoop;
import lime.system.ThreadPool;
import haxe.net.WebSocket.ReadyState;

#if (lime > '8.2.0')
class LimeWebSocket2 {
	public static function create(url:String, protocols:Array<String> = null, origin:String = null, debug:Bool = false):WebSocket {
		var lime = new LimeWebSocket2(url, protocols, origin, debug);
		return lime;
	}

	/**
	 * 调试信息
	 */
	public static var debug:Bool = false;

	private var url:String;

	private var protocols:Array<String>;

	private var origin:String;

	private var _websocket:haxe.net.WebSocket;

	public var readyState(get, never):ReadyState;

	function get_readyState():ReadyState {
		return _websocket != null ? _websocket.readyState : Connecting;
	}

	/**
	 * 线程管理
	 */
	private static var __thrad:ThreadPool;

	public function new(url:String, protocols:Array<String> = null, origin:String = null, debug:Bool = false) {
		LimeWebSocket2.debug = debug;
		this.url = url;
		this.protocols = protocols;
		this.origin = origin;
		if (__thrad == null) {
			__thrad = new ThreadPool(0, 10, MULTI_THREADED);
			__thrad.onProgress.add(threadPool_doProgress);
			__thrad.onComplete.add(threadPool_doComplete);
		}
		var createInfo:LimeWebSocket2State = {
			type: OPEN,
			socket: this,
		}
		__thrad.run(onWebSocketWork, createInfo);
	}

	public static function onWebSocketWork(state:LimeWebSocket2State, workOut:WorkOutput):Void {
		var websocket = haxe.net.WebSocket.create(state.socket.url, state.socket.protocols, state.socket.origin, LimeWebSocket2.debug);
		state.socket._websocket = websocket;
		var isClosed = false;
		var isError = false;
		websocket.onclose = (?e) -> {
			isClosed = true;
			workOut.sendProgress({
				socket: state.socket,
				type: CLOSE
			});
		}
		websocket.onopen = () -> {
			workOut.sendProgress({
				socket: state.socket,
				type: OPEN
			});
		}
		websocket.onerror = (e) -> {
			isError = true;
			workOut.sendProgress({
				socket: state.socket,
				type: ERROR
			});
		}
		websocket.onmessageBytes = (data) -> {
			workOut.sendProgress({
				type: SEND_BYTES,
				socket: state.socket,
				data: data
			});
		}
		websocket.onmessageString = (data) -> {
			workOut.sendProgress({
				type: SEND_STRING,
				socket: state.socket,
				data: data
			});
		}
		try {
			while (websocket.readyState != Closed) {
				websocket.process();
			}
		} catch (e:Exception) {
			trace("[hxonline]catch error:", e.message, e.stack);
			if (!isClosed) {
				websocket.close();
				isClosed = true;
			}
		}
		workOut.sendComplete();
	}

	public var onopen:Void->Void;

	public var onmessageBytes:Bytes->Void;

	public var onmessageString:String->Void;

	public var onclose:Dynamic->Void;

	public function sendString(data:String):Void {
		// trace("sendString", data);
		__thrad.run(threadPool_sendData, {
			type: SEND_STRING,
			socket: this,
			data: data
		});
	}

	public function sendBytes(data:Bytes):Void {
		// trace("sendBytes", data);
		__thrad.run(threadPool_sendData, {
			type: SEND_BYTES,
			socket: this,
			data: data
		});
	}

	public var onerror:Dynamic->Void;

	public function process():Void {
		// 使用processLoop代替
	}

	public function close():Void {
		__thrad.run(threadPool_sendData, {
			type: CLOSE,
			socket: this
		});
	}

	public static function threadPool_sendData(state:LimeWebSocket2State, work:WorkOutput):Void {
		switch (state.type) {
			case SEND_STRING:
				if (state.socket._websocket != null && state.socket.readyState == Open) {
					state.socket._websocket.sendString(state.data);
				}
			case SEND_BYTES:
				if (state.socket._websocket != null && state.socket.readyState == Open) {
					state.socket._websocket.sendBytes(state.data);
				}
			case CLOSE:
				if (state.socket._websocket != null && state.socket.readyState == Open) {
					state.socket._websocket.close();
				}
			default:
		}
		work.sendComplete();
	}

	public static function threadPool_doProgress(state:LimeWebSocket2State):Void {
		switch (state.type) {
			case OPEN:
				trace("[hxonline]open");
				if (state.socket.onopen != null)
					state.socket.onopen();
			case SEND_STRING:
				if (state.socket.onmessageString != null)
					state.socket.onmessageString(state.data);
			case SEND_BYTES:
				if (state.socket.onmessageBytes != null)
					state.socket.onmessageBytes(state.data);
			case PROCESS:
			case CLOSE:
				trace("[hxonline]close");
				if (state.socket.onclose != null)
					state.socket.onclose(state.data);
			case ERROR:
				trace("[hxonline]error");
				if (state.socket.onerror != null)
					state.socket.onerror(state.data);
		}
	}

	public static function threadPool_doComplete(state:Dynamic):Void {
		// var data:LimeWebSocket2State = state;
		// trace("hxonline states:", state);
	}
}

typedef LimeWebSocket2State = {
	type:SocketApi,
	socket:LimeWebSocket2,
	?data:Dynamic
};

enum abstract SocketApi(String) {
	var OPEN = "OPEN";
	var SEND_STRING = "sendString";
	var SEND_BYTES = "sendBytes";
	var PROCESS = "process";
	var CLOSE = "close";
	var ERROR = "error";
}
#end
