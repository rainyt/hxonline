## hxonline
与`go-websocket-server`构造的服务器配合的api

## 初始化服务器
```haxe
Client.getInstance().init("ws://127.0.0.1:8888", "Egdts8");
// 使用二进制传输数据
Client.getInstance().mode = BYTES;
// 侦听连接成功
Client.getInstance().onConnected = () -> {
    // 初始化成功后，会进入到这里，在这里进行登陆操作
};
```

## 开始连接到服务器
```haxe
Client.getInstance().connect((bool:Bool)->{
    if (bool) {
        // 连接成功
    } else {
        // 连接失败
    }
});
```

## 登陆服务器
其中openid是由自已计算出来的唯一id（可使用用户注册的唯一标识），username为用户昵称
```haxe
Client.getInstance().login(openid, username, (data) -> {
    if(data.code == 0){
        // 登陆成功
    } else {
        // 登陆失败
    }
});
```

## 更新用户数据
```haxe
// 更新用户数据
Client.getInstance().updateUserData({
    test: 1,
    lv: 100,
    name: "最强使者"
});
```

