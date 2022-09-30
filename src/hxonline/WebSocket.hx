package hxonline;

#if js
typedef WebSocket = js.html.WebSocket;
#elseif cpp
typedef WebSocket = haxe.net.WebSocket;
#end
