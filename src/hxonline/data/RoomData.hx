package hxonline.data;

/**
 * 房间数据
 */
typedef RoomData = {
	id:Int,
	max:Int,
	data:Dynamic,
	state:Dynamic,
	master:ClientData,
	self:ClientData,
	users:Array<ClientData>,
	usersState:Dynamic
}

/**
 * 客户端数据
 */
typedef ClientData = {
	uid:Int,
	name:String,
	data:Dynamic,
	state:Dynamic
}
