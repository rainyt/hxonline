package hxonline;

#if js
typedef WebSocket = js.html.WebSocket;
#elseif (cpp || flash)
#if lime
typedef WebSocket = hxonline.net.LimeWebSocket;
#else
typedef WebSocket = haxe.net.WebSocket;
#end
#end
