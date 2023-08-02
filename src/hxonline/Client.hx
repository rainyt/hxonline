package hxonline;

import hxonline.data.UserUIDData;
import haxe.Exception;
import hxonline.data.MatchOption;
import hxonline.data.RoomData;
import hxonline.data.ClientCallData;
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
	var FrameSyncReady = 27; // 帧同步准备传输
	var ResetRoom = 28; // 重置房间状态信息
	var Matched = 29; // 匹配成功
	var LockRoom = 30; // 锁定房间
	var UnlockRoom = 31; // 取消锁定房间
	var MatchRoom = 32; // 匹配房间
	var SetRoomMatchOption = 33; // 设置房间的匹配参数
	var UpdateRoomUserData = 34; // 更新房间用户数据
	var GetRoomList = 35; // 获取房间列表
	var SendServerMsg = 36; // 发送全服消息
	var GetServerMsg = 37; // 接收到全服消息
	var ListenerServerMsg = 38; // 侦听全服消息
	var CannelListenerServerMsg = 39; // 取消侦听全服消息
	var GetUserDataByUID = 40; // 根据UID获取用户数据
	var GetServerOldMsg = 41; // 获取历史全服消息
	var ExtendsCall = 42; // 扩展方法调用
	var CannelMatchUser = 43; // 取消匹配用户
	var SendToUser = 44; // 给某个用户发送独立消息
	var UserMessage = 45; // 接收到用户的独立消息
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
 * go-websocket-server实时同步服务器客户端
 */
class Client {
	/**
	 * 调试模式
	 */
	public static var debug:Bool = false;

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
	public var userId:String = "";

	/**
	 * 登陆使用的昵称
	 */
	public var name:String = "";

	/**
	 * 服务器地址
	 */
	public var serverUrl:String;

	/**
	 * 服务器的验证APPKEY
	 */
	public var serverAppKey:String;

	/**
	 * 当前房间数据
	 */
	public static var roomData:RoomData;

	private function new() {}

	/**
	 * 连接器
	 */
	#if (js || cpp || flash)
	private var _socket:WebSocket;
	#end

	/**
	 * 传输模式
	 */
	public var mode:DataMode = TEXT;

	/**
	 * 回调支持
	 */
	private var _opCallBack:Map<OpCode, Array<ClientCallData->Void>> = [];

	/**
	 * 初始化
	 * @param url 
	 * @param appkey 
	 */
	public function init(url:String, appid:String):Void {
		trace("[hxonline]init url:" + url, appid);
		serverUrl = url;
		serverAppKey = appid;
		#if ios
		sys.ssl.Socket.DEFAULT_VERIFY_CERT = false;
		#end
	}

	/**
	 * 关闭连接
	 */
	public function close():Void {
		#if (js || cpp || flash)
		if (_socket != null) {
			#if (cpp || flash)
			if (_socket.readyState != Closed) {
				trace("[Client]close()");
				_socket.close();
			}
			#else
			if (_socket.readyState != WebSocket.CLOSED) {
				trace("[Client]close()");
				_socket.close(1000, "主动退出");
			}
			#end
			_socket = null;
			_opCallBack = [];
		}
		#end
	}

	private var _connectCb:Bool->Void;

	/**
	 * 是否连接中
	 * @return Bool
	 */
	public function connected():Bool {
		#if js
		return _socket != null && _socket.readyState != WebSocket.CLOSED;
		#elseif (flash || cpp)
		return _socket != null && _socket.readyState != Closed;
		#else
		return false;
		#end
	}

	/**
	 * 连接服务器
	 * @param cb 
	 */
	public function connect(cb:Bool->Void = null):Void {
		trace("connecting", serverUrl);
		_connectCb = cb;
		#if js
		if (_socket != null) {
			if (_socket.readyState == WebSocket.OPEN) {
				trace("重复登陆");
				if (_connectCb != null) {
					_connectCb(true);
					_connectCb = null;
				}
				return;
			}
		}
		if (_socket != null && _socket.readyState != WebSocket.CLOSED) {
			_socket.close();
		}
		_socket = new WebSocket(serverUrl);
		_socket.onopen = function() {
			if (onConnected != null)
				onConnected();
			if (_connectCb != null) {
				_connectCb(true);
				_connectCb = null;
			}
		};
		_socket.onmessage = function(data:MessageEvent) {
			if (data.data is String) {
				if (onMessageEvent != null)
					this.onMessageEvent(Json.parse(data.data));
				if (onText != null)
					this.onText(data.data);
			} else {
				if (onBytes != null)
					this.onBytes(data.data);
			}
		}
		_socket.onerror = function() {
			if (_connectCb != null) {
				_connectCb(false);
				_connectCb = null;
			}
		}
		_socket.onclose = function() {
			trace("[Client]onClosed()");
			roomData = null;
			if (onClose != null)
				this.onClose();
		}
		#elseif (cpp || flash)
		if (_socket != null) {
			if (_socket.readyState == Connecting) {
				if (_connectCb != null) {
					_connectCb(true);
					_connectCb = null;
				}
				return;
			}
		}
		if (_socket != null && _socket.readyState != Closed) {
			_socket.close();
		}
		_socket = WebSocket.create(serverUrl, null, null, false);
		_socket.onopen = function() {
			trace("open");
			if (onConnected != null)
				onConnected();
			if (_connectCb != null) {
				_connectCb(true);
				_connectCb = null;
			}
		};
		_socket.onmessageBytes = function(data) {
			if (onBytes != null)
				this.onBytes(data);
		}
		_socket.onmessageString = function(data) {
			if (onMessageEvent != null)
				this.onMessageEvent(Json.parse(data));
			if (onText != null)
				this.onText(data);
		}
		_socket.onerror = function(message) {
			trace("[Client]onError()" + message);
			if (_connectCb != null) {
				_connectCb(false);
				_connectCb = null;
			}
		}
		_socket.onclose = function(?e:Null<Dynamic>) {
			trace("[Client]onClosed()");
			roomData = null;
			if (this.onClose != null)
				this.onClose();
		}
		#end
	}

	public function process():Void {
		#if (cpp || flash)
		if (_socket != null)
			_socket.process();
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
		switch opcode {
			case Error:
			case Message:
			case CreateRoom:
			case JoinRoom:
			case ChangedRoom:
			case GetRoomData:
			case StartFrameSync:
			case StopFrameSync:
			case UploadFrame:
			case Login:
			case FData:
			case RoomMessage:
			case JoinRoomClient:
				if (roomData != null) {
					var isExsit = false;
					for (user in roomData.users) {
						if (user.uid == data.uid) {
							isExsit = true;
							break;
						}
					}
					if (!isExsit)
						roomData.users.push(data);
				}
				UserUIDData.getInstance().cacheUserData(data);
			case ExitRoomClient:
				if (roomData != null) {
					for (index => user in roomData.users) {
						if (user.uid == data.uid) {
							roomData.users.remove(roomData.users[index]);
							break;
						}
					}
				}
			case OutOnlineRoomClient:
			case ExitRoom:
				roomData = null;
			case MatchUser:
			case Matched:
				if (_matchCallBack != null) {
					_matchCallBack({
						code: isError ? 1 : 0,
						data: data,
						op: opcode
					});
					_matchCallBack = null;
				}
			case UpdateUserData:
			case UpdateRoomUserData:
				if (roomData != null) {
					for (user in roomData.users) {
						if (user.uid == data.uid) {
							if (user.data == null) {
								user.data = {};
							}
							this.updateData(user.data, data.data);
							UserUIDData.getInstance().cacheUserData(user);
							break;
						}
					}
				}
			case GetRoomOldMessage:
			case UpdateRoomCustomData:
			case UpdateRoomOption:
			case KickOut:
			case SelfKickOut:
			case GetFrameAt:
			case SetRoomState:
			case RoomStateUpdate:
				// 房间状态更新时
				if (roomData != null)
					this.updateData(roomData.state, data);
			case SetClientState:
			case ClientStateUpdate:
				// 客户端状态更新时
				if (roomData != null)
					for (user in roomData.users) {
						if (user.uid == data.uid) {
							if (user.state == null) {
								user.state = {};
							}
							this.updateData(user.state, data.data);
							break;
						}
					}
			default:
		}
		if (_opCallBack.exists(opcode)) {
			var nextCall = _opCallBack.get(opcode).shift();
			if (nextCall != null)
				nextCall({
					code: isError ? 1 : 0,
					data: data,
					op: opcode
				});
		}
	}

	/**
	 * 更新数据
	 * @param rootData 
	 * @param data 
	 */
	private function updateData(rootData:Dynamic, data:Dynamic):Void {
		if (rootData == null || data == null)
			return;
		var keys = Reflect.fields(data);
		for (v in keys) {
			Reflect.setProperty(rootData, v, Reflect.getProperty(data, v));
		}
	}

	/**
	 * 消息逻辑处理
	 * @param data 
	 */
	private function onMessageEvent(data:Dynamic):Void {
		var opcode:OpCode = data.op;
		if (debug) {
			if (data != null && opcode != FData)
				trace(Json.stringify(data));
		}
		callOp(opcode, data.data);
		if (onOpMessage != null)
			this.onOpMessage(opcode, data.data);
	}

	/**
	 * 登陆服务器
	 * @param userId 用户ID，确保每个用户的用户ID不相同，否则会发生掉线的情况
	 * @param usreName 用户名
	 */
	public function login(userId:String, usreName:String, cb:ClientCallData->Void):Void {
		this.name = usreName;
		this.userId = userId;
		connect((bool) -> {
			if (bool) {
				sendClientOp(Login, {
					"openid": userId,
					"username": usreName,
					"appid": serverAppKey
				}, function(data) {
					this.uid = data.data.uid;
					if (cb != null) {
						cb(data);
					}
				});
			} else {
				trace("Client.login.fail");
				if (cb != null) {
					trace("Client.login.callback");
					cb({
						code: -1,
						op: Login,
						data: "无法连接服务器"
					});
				}
			}
		});
	}

	/**
	 * 更新用户数据
	 * @param data 
	 * @param cb 
	 */
	public function updateUserData(data:Dynamic, cb:ClientCallData->Void = null):Void {
		if (roomData != null) {
			this.updateData(roomData.self.data, data);
			UserUIDData.getInstance().cacheUserData(roomData.self);
		}
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
	 * 发送消息给指定的用户
	 * @param uid 
	 * @param data 
	 * @param cb 
	 */
	public function sendUserMessage(uid:Int, data:Dynamic, cb:ClientCallData->Void = null):Void {
		sendClientOp(SendToUser, {
			uid: uid,
			data: data
		}, cb);
	}

	/**
	 * 发送全服消息
	 * @param data 
	 * @param cb 
	 */
	public function sendServerMessage(data:Dynamic, cb:ClientCallData->Void = null):Void {
		sendClientOp(SendServerMsg, data, cb);
	}

	/**
	 * 获取服务器历史消息
	 * @param counts 
	 * @param cb 
	 */
	public function getServerOldMsg(counts:Int, cb:ClientCallData->Void = null):Void {
		sendClientOp(GetServerOldMsg, {
			counts: counts
		}, cb);
	}

	/**
	 * 侦听全服消息
	 * @param cb 
	 */
	public function listenerServerMessage(cb:ClientCallData->Void = null):Void {
		sendClientOp(ListenerServerMsg, null, cb);
	}

	/**
	 * 取消侦听全服消息
	 * @param cb 
	 */
	public function removeServerMessage(cb:ClientCallData->Void = null):Void {
		sendClientOp(CannelListenerServerMsg, null, cb);
	}

	/**
	 * 设置房间状态，每个用户都可以同时修改它
	 * @param data 
	 * @param cb 
	 */
	public function setRoomState(setData:Dynamic, cb:ClientCallData->Void = null):Void {
		sendClientOp(SetRoomState, setData, function(data) {
			if (data.code == 0) {
				if (roomData != null) {
					this.updateData(roomData.state, setData);
				}
			}
			if (cb != null) {
				cb(data);
			}
		});
	}

	/**
	 * 设置用户状态
	 * @param data 
	 * @param cb 	
	 */
	public function setClientState(setData:Dynamic, cb:ClientCallData->Void = null):Void {
		if (roomData == null)
			return;
		sendClientOp(SetClientState, setData, function(data) {
			if (data.code == 0) {
				if (roomData != null) {
					this.updateData(roomData.self.state, setData);
				}
			}
			if (cb != null) {
				cb(data);
			}
		});
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
	public function joinRoom(roomid:Int, cb:ClientCallData->Void, password:String = null):Void {
		sendClientOp(JoinRoom, {
			id: roomid,
			password: password
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
	 * 当前状态，自已是否房主
	 * @return Bool
	 */
	public function isMatser():Bool {
		if (roomData != null) {
			return roomData.master.uid == roomData.self.uid;
		}
		return false;
	}

	/**
	 * 锁定房间，锁定后，外面的人将无法加入
	 * @param cb 
	 */
	public function lockRoom(cb:ClientCallData->Void = null):Void {
		sendClientOp(LockRoom, null, cb);
	}

	/**
	 * 解锁房间，解锁后，房间才允许加入
	 * @param cb 
	 */
	public function unlockRoom(cb:ClientCallData->Void = null):Void {
		sendClientOp(UnlockRoom, null, cb);
	}

	/**
	 * 检测所有的客户端的状态值是否等于value
	 * @param stateKey 
	 * @param value 
	 * @return Bool
	 */
	public function checkAllClientState(stateKey:String, value:Dynamic):Bool {
		if (roomData != null) {
			var counts = 0;
			for (v in roomData.users) {
				if (Reflect.getProperty(v.state, stateKey) == value) {
					counts++;
				}
			}
			return counts == roomData.users.length;
		}
		return false;
	}

	/**
	 * 获取房间信息
	 * @param cb 
	 */
	public function getRoomData(cb:ClientCallData->Void):Void {
		if (cb != null)
			sendClientOp(GetRoomData, null, function(data) {
				if (data.code == 0) {
					roomData = data.data;
					// 定位是自已的用户数据
					var list:Array<Dynamic> = data.data.users;
					for (index => value in list) {
						var state:Dynamic = Reflect.getProperty(data.data.usersState, value.uid);
						value.state = state == null ? {} : state;
						if (value.uid == this.uid) {
							data.data.self = value;
						}
						UserUIDData.getInstance().cacheUserData(value);
					}
				}
				cb(data);
			});
		else
			sendClientOp(GetRoomData);
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
	 * 重置房间数据，新的房间数据，请通过`getRoomData`接口获得
	 * @param cb 
	 */
	public function resetRoom(cb:ClientCallData->Void = null) {
		sendClientOp(ResetRoom, null, cb);
	}

	/**
	 * 匹配回调
	 */
	private var _matchCallBack:ClientCallData->Void;

	/**
	 * 匹配用户
	 * @param cb 
	 */
	public function matchUser(option:MatchOption, cb:ClientCallData->Void) {
		_matchCallBack = cb;
		sendClientOp(MatchUser, option, function(data:ClientCallData) {
			if (data.code != 0) {
				_matchCallBack(data);
			}
		});
	}

	/**
	 * 取消匹配用户行为
	 * @param cb 
	 */
	public function cannelMathUser(cb:ClientCallData->Void) {
		sendClientOp(MatchUser, CannelMatchUser, cb);
	}

	/**
	 * 匹配房间，如果不存在对应的房间时，则自动创建房间
	 * @param cb 
	 */
	public function matchRoom(option:MatchOption, cb:ClientCallData->Void) {
		sendClientOp(MatchRoom, option, cb);
	}

	/**
	 * 发送数据
	 * @param data 
	 */
	private function sendData(data:Dynamic):Void {
		#if js
		try {
			_socket.send(data);
		} catch (e:Exception) {}
		#elseif (cpp || flash)
		try {
			if (data is String) {
				if (debug)
					trace('send data:', data);
				_socket.sendString(data);
			} else
				_socket.sendBytes(data);
		} catch (e:Exception) {}
		#end
	}

	/**
	 * 发送Json格式的数据结构
	 * @param op 
	 * @param data 
	 */
	public function sendClientOp(op:OpCode, data:Dynamic = null, cb:ClientCallData->Void = null):Void {
		if (!connected())
			return;
		if (debug) {
			trace("发送：", op, data);
		}
		switch (mode) {
			case TEXT:
				var data = Json.stringify({
					op: op,
					data: data
				});
				sendData(data);
			// trace("TEXT发送长度：", Bytes.ofString(data).length);
			case BYTES:
				if (data is Bytes) {
					var bdata:Bytes = data;
					var bytes = Bytes.alloc(bdata.length + 1);
					bytes.set(0, op);
					for (i in 0...bdata.length) {
						bytes.set(1 + i, bdata.get(i));
					}
					sendData(bytes.getData());
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
				}
		}
		if (!_opCallBack.exists(op)) {
			_opCallBack.set(op, []);
		}
		if (cb == null) {
			_opCallBack.get(op).push(null);
		} else {
			_opCallBack.get(op).push(cb);
		}
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

	/**
	 * 获取UID在users里的索引
	 * @param arg0 
	 * @return Int
	 */
	public function getUidIndex(arg0:Null<Int>):Int {
		if (roomData != null) {
			for (i => user in roomData.users) {
				if (user.uid == arg0) {
					return i;
				}
			}
		}
		return -1;
	}

	/**
	 * 获取房间列表信息
	 * @param page 
	 * @param counts 
	 * @param cb 
	 */
	public function getRoomList(page:Int, counts:Int, cb:ClientCallData->Void):Void {
		sendClientOp(GetRoomList, {
			page: page,
			counts: counts
		}, cb);
	}

	/**
	 * 通过UID获取用户数据
	 * @param uid 
	 * @param cb 
	 */
	public function getUserDataByUid(uid:Int, cb:ClientCallData->Void):Void {
		sendClientOp(GetUserDataByUID, {
			uid: uid
		}, cb);
	}

	/**
	 * 调用扩展方法
	 * @param uid 
	 * @param cb 
	 */
	public function call(api:String, data:Dynamic, cb:ClientCallData->Void = null):Void {
		sendClientOp(ExtendsCall, {
			f: api,
			d: data
		}, cb);
	}
}
