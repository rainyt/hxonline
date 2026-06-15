package hxonline.net;

import sys.thread.Thread;
import lime.utils.ObjectPool;
import haxe.Exception;
import haxe.io.Bytes;
import lime.system.WorkOutput;
import haxe.MainLoop;
import lime.system.ThreadPool;
import haxe.net.WebSocket.ReadyState;

#if (lime > '8.2.0')
class LimeWebSocket3 {
	public static function create(url:String, protocols:Array<String> = null, origin:String = null, debug:Bool = false):WebSocket {
		var lime = new LimeWebSocket3(url, protocols, origin, debug);
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

	public function new(url:String, protocols:Array<String> = null, origin:String = null, debug:Bool = false) {
		LimeWebSocket3.debug = debug;
		this.url = url;
		this.protocols = protocols;
		this.origin = origin;
		Thread.create(function() {
			var websocket = haxe.net.WebSocket.create(url, protocols, origin, debug);
			this._websocket = websocket;
			var isClosed = false;
			var isError = false;
			websocket.onclose = (?e) -> {
				isClosed = true;
				sendProgress({
					socket: this,
					type: CLOSE
				});
			}
			websocket.onopen = () -> {
				sendProgress({
					socket: this,
					type: OPEN
				});
			}
			websocket.onerror = (e) -> {
				isError = true;
				sendProgress({
					socket: this,
					type: ERROR
				});
			}
			websocket.onmessageBytes = (data) -> {
				sendProgress({
					type: SEND_BYTES,
					socket: this,
					data: data
				});
			}
			websocket.onmessageString = (data) -> {
				sendProgress({
					type: SEND_STRING,
					socket: this,
					data: data
				});
			}
			try {
				while (websocket.readyState != Closed) {
					if (game.worlds.GameWorld.currentWorld != null && game.worlds.GameWorld.currentWorld.nowTime > 5) {
						trace("send sendData stop");
						continue;
					}
					websocket.process();
				}
			} catch (e:Exception) {
				trace("[hxonline]catch error:", e.message, e.stack);
				if (!isClosed) {
					websocket.close();
					isClosed = true;
				}
			}
		});
	}

	private function sendProgress(state:LimeWebSocket3State):Void {
		MainLoop.runInMainThread(() -> {
			switch (state.type) {
				case OPEN:
					trace("[hxonline]open");
					if (this.onopen != null) this.onopen();
				case SEND_STRING:
					trace("[hxonline]onmessageString", state.data);
					if (this.onmessageString != null) this.onmessageString(state.data);
				case SEND_BYTES:
					trace("[hxonline]onmessageBytes");
					if (this.onmessageBytes != null) this.onmessageBytes(state.data);
				case PROCESS:
				case CLOSE:
					trace("[hxonline]close");
					if (this.onclose != null) this.onclose(state.data);
				case ERROR:
					trace("[hxonline]error");
					if (this.onerror != null) this.onerror(state.data);
			}
		});
	}

	public var onopen:Void->Void;

	public var onmessageBytes:Bytes->Void;

	public var onmessageString:String->Void;

	public var onclose:Dynamic->Void;

	public function sendString(data:String):Void {
		// trace("sendString", data);
		sendData({
			type: SEND_STRING,
			socket: this,
			data: data
		});
	}

	public function sendBytes(data:Bytes):Void {
		// trace("sendBytes", data);
		sendData({
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
		sendData({
			type: CLOSE,
			socket: this
		});
	}

	public function sendData(state:LimeWebSocket3State):Void {
		Thread.createWithEventLoop(() -> {
			switch (state.type) {
				case SEND_STRING:
					if (this._websocket != null && this.readyState == Open) {
						this._websocket.sendString(state.data);
					}
				case SEND_BYTES:
					if (_websocket != null && this.readyState == Open) {
						this._websocket.sendBytes(state.data);
					}
				case CLOSE:
					if (_websocket != null && this.readyState == Open) {
						this._websocket.close();
					}
				default:
			}
		});
	}
}

typedef LimeWebSocket3State = {
	type:SocketApi,
	socket:LimeWebSocket3,
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
