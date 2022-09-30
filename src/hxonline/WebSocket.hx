package hxonline;

#if js
typedef WebSocket = js.html.WebSocket;
#elseif (cpp || flash)
typedef WebSocket = haxe.net.WebSocket;
#end
