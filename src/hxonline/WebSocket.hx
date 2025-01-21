package hxonline;

#if js
typedef WebSocket = js.html.WebSocket;
#elseif (cpp || flash)
#if (lime && lime < '8.2.0')
typedef WebSocket = hxonline.net.LimeWebSocket;
#elseif (lime && lime >= '8.2.0')
typedef WebSocket = hxonline.net.LimeWebSocket2;
#else
typedef WebSocket = haxe.net.WebSocket;
#end
#end
