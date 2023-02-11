package hxonline.data;

typedef MatchOption = {
	// 匹配键值
	key:String,
	// 匹配人数
	number:Int,
	// 匹配权重
	range:Dynamic<MatchRange>
}

typedef MatchRange = {
	// 匹配范围最小值
	min:Int,
	// 匹配范围最大值
	max:Int
}
