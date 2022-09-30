package;

import haxe.Timer;
import hxonline.Client;
import hxonline.WebSocket;

class Main {
	static function main() {
		Client.getInstance().init("ws://127.0.0.1:8888", null);
		Client.getInstance().login("1", "左眼", (data) -> {
			trace("登陆结果：", data);
		});
        // while(true){
            // Client.getInstance().con
        // }
        #if sys
        while (true) {
            Client.getInstance().process();
            Sys.sleep(0.1);
        }
        #end
	}
}
