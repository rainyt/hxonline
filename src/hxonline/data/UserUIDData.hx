package hxonline.data;

import hxonline.data.RoomData.ClientData;

/**
 * 缓存UID用户数据使用
 */
class UserUIDData {
	private static var _uidData:UserUIDData;

	public static function getInstance():UserUIDData {
		if (_uidData == null) {
			_uidData = new UserUIDData();
		}
		return _uidData;
	}

	/**
	 * 当前缓存的所有用户的UID绑定的数据
	 */
	public var dataBindUid:Map<Int, ClientData> = [];

	private function new() {}

	/**
	 * 通过UID获取用户数据，如果用户数据不存在时，则会返回null
	 * @param uid 
	 * @return ClientData
	 */
	public function getUserDataByUid(uid:Int):ClientData {
		return dataBindUid.get(uid);
	}

	/**
	 * 通过UID加载用户数据，如果用户数据无法被加载时，则返回null
	 * @param uid 
	 * @param cb 
	 */
	public function loadUserDataByUid(uid:Int, cb:ClientData->Void, useCache:Bool = false):Void {
		// 查询缓存对象
		if (useCache) {
			var data = getUserDataByUid(uid);
			if (data != null) {
				cb(data);
				return;
			}
		}
		// 通过加载
		Client.getInstance().getUserDataByUid(uid, (data) -> {
			if (data.code == 0) {
				var userdata:ClientData = {
					uid: uid,
					data: data.data.data,
					state: {},
					name: data.data.name
				};
				if (onUserDataUpdate != null)
					onUserDataUpdate(userdata);
				dataBindUid.set(userdata.uid, userdata);
				cb(userdata);
			} else {
				// 失败
				cb(null);
			}
		});
	}

	public static var onUserDataUpdate:ClientData->Void;

	/**
	 * 缓存用户数据
	 * @param data 
	 */
	public function cacheUserData(data:ClientData):Void {
		if (data != null && data.uid != null) {
			if (onUserDataUpdate != null)
				onUserDataUpdate(data);
			dataBindUid.set(data.uid, data);
		}
	}
}
