package socket;

import socket.data.ClientCallData;
import haxe.io.Bytes;
#if js
import js.html.MessageEvent;
#end
import haxe.Json;

enum abstract OpCode(Int) from Int to Int {
	var Error = -1; // 统一错误
	var Message = 0; // 普通消息
	var CreateRoom = 1; // 创建房间
	var JoinRoom = 2; // 加入房间
	var ChangedRoom = 3; // 房间信息变更
	var GetRoomData = 4; // 获取房间信息
	var StartFrameSync = 5; // 开启帧同步
	var StopFrameSync = 6; // 停止帧同步
	var UploadFrame = 7; // 上传帧同步数据
	var Login = 8; // 登陆用户
	var FData = 9; // 帧数据
	var RoomMessage = 10; // 发送房间消息
	var JoinRoomClient = 11; // 加入房间的客户端信息
	var ExitRoomClient = 12; // 退出房间的客户端信息
	var OutOnlineRoomClient = 13; // 在房间中离线的客户端信息，请注意，只有开启了帧同步的情况下收到
	var ExitRoom = 14; // 退出房间
	var MatchUser = 15; // 匹配用户
	var UpdateUserData = 16; // 更新用户数据
	var GetRoomOldMessage = 17; // 获取房间的历史消息
	var UpdateRoomCustomData = 18; // 更新房间的自定义数据
	var UpdateRoomOption = 19; // 更新房间的参数，如人数、密码
	var KickOut = 20; // 将玩家踢出房间
	var SelfKickOut = 21; // 自已被踢出房间
	var GetFrameAt = 22; // 获取指定帧范围的帧事件
	var SetRoomState = 23; // 设置房间状态数据
	var RoomStateUpdate = 24; // 房间状态更新
	var SetClientState = 25; // 设置用户状态
	var ClientStateUpdate = 26; // 用户状态发生变化
}

enum DataMode {
	BYTES;
	TEXT;
}

typedef RoomOption = {
	maxCounts:Int,
	password:String
}

/**
 * 客户端
 */
class Client {
	private static var _instance:Client;

	/**
	 * 获得一个Client单例
	 * @return Client
	 */
	public static function getInstance():Client {
		if (_instance == null) {
			_instance = new Client();
		}
		return _instance;
	}

	/**
	 * 注册的UID
	 */
	public var uid:Int = 0;

	/**
	 * 登陆用户名
	 */
	public var name:String = "";

	public function new() {}

	/**
	 * 连接器
	 */
	#if js
	private var _socket:WebSocket;
	#end

	/**
	 * 传输模式
	 */
	public var mode:DataMode = TEXT;

	/**
	 * 回调支持
	 */
	private var _opCallBack:Map<OpCode, ClientCallData->Void> = [];

	/**
	 * 初始化
	 * @param url 
	 * @param appkey 
	 */
	public function init(url:String, appkey:String):Void {
		#if js
		_socket = new WebSocket(url);
		_socket.onopen = function() {
			onConnected();
		};
		_socket.onmessage = function(data:MessageEvent) {
			if (data.data is String) {
				this.onMessageEvent(Json.parse(data.data));
				this.onText(data.data);
			} else {
				this.onBytes(data.data);
			}
		}
		_socket.onclose = function() {
			this.onClose();
		}
		#end
	}

	/**
	 * 调用回调
	 * @param opcode 
	 * @param args 
	 */
	private function callOp(opcode:OpCode, data:Dynamic):Void {
		var isError = opcode == Error;
		if (isError) {
			opcode = data.op;
		}
		if (_opCallBack.exists(opcode)) {
			_opCallBack.get(opcode)({
				code: isError ? 1 : 0,
				data: data,
				op: opcode
			});
			_opCallBack.remove(opcode);
		}
	}

	/**
	 * 消息逻辑处理
	 * @param data 
	 */
	private function onMessageEvent(data:Dynamic):Void {
		var opcode:OpCode = data.op;
		callOp(opcode, data.data);
		this.onOpMessage(opcode, data.data);
	}

	/**
	 * 登陆服务器
	 * @param userId 用户ID，确保每个用户的用户ID不相同，否则会发生掉线的情况
	 * @param usreName 用户名
	 */
	public function login(userId:String, usreName:String, cb:ClientCallData->Void):Void {
		this.name = usreName;
		sendClientOp(Login, {
			"openid": userId,
			"username": usreName
		}, function(data) {
			this.uid = data.data.uid;
			if (cb != null) {
				cb(data);
			}
		});
	}

	/**
	 * 更新用户数据
	 * @param data 
	 * @param cb 
	 */
	public function updateUserData(data:Dynamic, cb:ClientCallData->Void = null):Void {
		sendClientOp(UpdateUserData, data, cb);
	}

	/**
	 * 发送房间消息
	 * @param data 
	 * @param cb 
	 */
	public function sendRoomMessage(data:Dynamic, cb:ClientCallData->Void = null):Void {
		sendClientOp(RoomMessage, data, cb);
	}

	/**
	 * 设置房间状态，每个用户都可以同时修改它
	 * @param data 
	 * @param cb 
	 */
	public function setRoomState(data:Dynamic, cb:ClientCallData->Void = null):Void {
		sendClientOp(SetRoomState, data, cb);
	}

	/**
	 * 设置用户状态
	 * @param data 
	 * @param cb 
	 */
	public function setClientState(data:Dynamic, cb:ClientCallData->Void = null):Void {
		sendClientOp(SetClientState, data, cb);
	}

	/**
	 * 启动帧同步
	 * @param cb 
	 */
	public function startFrameSync(cb:ClientCallData->Void = null):Void {
		sendClientOp(StartFrameSync, null, cb);
	}

	/**
	 * 停止帧同步
	 * @param cb 
	 */
	public function stopFrameSync(cb:ClientCallData->Void = null):Void {
		sendClientOp(StopFrameSync, null, cb);
	}

	/**
	 * 创建房间
	 * @param cb 
	 */
	public function createRoom(cb:ClientCallData->Void):Void {
		sendClientOp(CreateRoom, null, cb);
	}

	/**
	 * 更新房间自定义数据
	 * @param data 
	 * @param cb 
	 */
	public function updateRoomCustomData(data:Dynamic, cb:ClientCallData->Void):Void {
		sendClientOp(UpdateRoomCustomData, data, cb);
	}

	/**
	 * 加入房间
	 * @param roomid 
	 * @param cb 
	 */
	public function joinRoom(roomid:Int, cb:ClientCallData->Void):Void {
		sendClientOp(JoinRoom, {
			id: roomid
		}, cb);
	}

	/**
	 * 退出房间
	 * @param cb 
	 */
	public function exitRoom(cb:ClientCallData->Void = null):Void {
		sendClientOp(ExitRoom, null, cb);
	}

	/**
	 * 踢出房间
	 * @param uid 
	 * @param cb 
	 */
	public function kickOut(uid:Int, cb:ClientCallData->Void = null):Void {
		sendClientOp(KickOut, {
			uid: uid
		}, cb);
	}

	/**
	 * 获取房间信息
	 * @param cb 
	 */
	public function getRoomData(cb:ClientCallData->Void):Void {
		sendClientOp(GetRoomData, null, cb);
	}

	/**
	 * 获取房间的历史聊天记录
	 * @param cb 
	 */
	public function getRoomOldMessage(cb:ClientCallData->Void):Void {
		sendClientOp(GetRoomOldMessage, null, cb);
	}

	/**
	 * 更新房间配置
	 * @param data 
	 * @param cb 
	 */
	public function updateRoomOption(data:RoomOption, cb:ClientCallData->Void = null):Void {
		sendClientOp(UpdateRoomOption, data, cb);
	}

	/**
	 * 上传帧数据
	 * @param data 
	 */
	public function uploadFrame(data:Dynamic):Void {
		sendClientOp(UploadFrame, data);
	}

	/**
	 * 发送数据
	 * @param data 
	 */
	private function sendData(data:Dynamic):Void {
		#if js
		_socket.send(data);
		#end
	}

	/**
	 * 发送Json格式的数据结构
	 * @param op 
	 * @param data 
	 */
	public function sendClientOp(op:OpCode, data:Dynamic, cb:ClientCallData->Void = null):Void {
		switch (mode) {
			case TEXT:
				var data = Json.stringify({
					op: op,
					data: data
				});
				sendData(data);
				trace("TEXT发送长度：", Bytes.ofString(data).length);
			case BYTES:
				if (data is Bytes) {
					var bdata:Bytes = data;
					var bytes = Bytes.alloc(bdata.length + 1);
					bytes.set(0, op);
					for (i in 0...bdata.length) {
						bytes.set(1 + i, bdata.get(i));
					}
					sendData(bytes.getData());
					trace("BYTES发送长度：", bytes.length);
				} else {
					var jsondata = Json.stringify(data);
					var jsonbyte = Bytes.ofString(jsondata);
					var len = jsonbyte.length + 1;
					var bytes = Bytes.alloc(len);
					bytes.set(0, op);
					for (i in 0...jsonbyte.length) {
						bytes.set(1 + i, jsonbyte.get(i));
					}
					sendData(bytes.getData());
					trace("BYTES发送长度：", bytes.length);
				}
		}
		if (cb == null)
			_opCallBack.remove(cast cb);
		else
			_opCallBack.set(op, cb);
	}

	/**
	 * 连接成功
	 */
	dynamic public function onConnected():Void {}

	/**
	 * 连接断开
	 */
	dynamic public function onClose():Void {}

	/**
	 * 文本数据
	 * @param text 
	 */
	dynamic public function onText(text:String):Void {}

	/**
	 * 二进制数据
	 * @param bytes 
	 */
	dynamic public function onBytes(bytes:Bytes):Void {}

	/**
	 * 操作Op数据
	 * @param op 
	 * @param data 
	 */
	dynamic public function onOpMessage(op:OpCode, data:Dynamic):Void {}
}
