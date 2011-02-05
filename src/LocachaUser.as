package
{
	import flash.events.*;
	import flash.net.*;

	
	public class LocachaUser
	{
		public var core:LocachaCore;
		public var farID:String;
		
		public var streamIn:NetStream;
		public var streamOut:NetStream;
		
		public var connectState:String = UserConnectState.DISCONNECTED;
		public var status:String = UserStatus.HOLDING;
		
		public var videoHandle:String;
		public var videoStream:NetStream;
		
		public function LocachaUser(core:LocachaCore, farID:String):void
		{
			this.core = core;
			this.farID = farID;
		}
		
		public function connect():void
		{
			connectState = UserConnectState.CONNECTING;
			
			// publish listener
			trace("starting listen stream");
			streamOut = new NetStream(core.netConnection, NetStream.DIRECT_CONNECTIONS);
			streamOut.addEventListener(NetStatusEvent.NET_STATUS, outStream_statusChange);
			streamOut.publish("streamOut-" + farID);
			
			// play remote control stream
			trace("connecting to remote user");
			streamIn = new NetStream(core.netConnection, farID);
			streamIn.addEventListener(NetStatusEvent.NET_STATUS, inStream_statusChange);
			streamIn.play("streamOut-" + core.nearID);
			
			var self:LocachaUser = this;
			var client:Object = new Object;
			
			client.requestVideo = function():void
			{
				core.user_requestVideo(self);
			}
			client.requestVideoResponse = function(accept:Boolean):void
			{
				core.user_requestVideoResponse(self, accept);
			}
			client.videoHandleUpdate = function(handle:String):void
			{
				trace("user recv video handle update: " + handle);
				
				if(handle && !videoStream)
				{
					trace("remote video stream created");
					// callee subscribes to media, to be able to get the remote user name
					videoStream = new NetStream(core.netConnection, farID);
					videoStream.addEventListener(NetStatusEvent.NET_STATUS, 
						function(event:NetStatusEvent):void{stream_statusChange("videoStream", event);});
				}
				
				if(videoStream && videoHandle != handle)
				{
					videoHandle = handle;
					videoStream.play(handle);
					videoStream.receiveVideo(true);
				}

				core.ui.user_update(self);
			}
				
			streamIn.client = client;
		}
		
		public function disconnect():void 
		{
			connectState = UserConnectState.DISCONNECTED;
			
			if(streamOut)
			{
				streamOut.removeEventListener(NetStatusEvent.NET_STATUS, outStream_statusChange);
				streamOut.close();
				streamOut = null;
			}
			
			if(streamIn)
			{
				streamIn.removeEventListener(NetStatusEvent.NET_STATUS, inStream_statusChange);
				streamIn.close();
				streamIn = null;
			}
		}
		
		private function inStream_statusChange(event:NetStatusEvent):void
		{
			stream_statusChange("inStream", event);
		}
		
		private function outStream_statusChange(event:NetStatusEvent):void
		{
			stream_statusChange("outStream", event);
		}
		
		private function stream_statusChange(source:String, event:NetStatusEvent):void
		{
			trace("User " + source + ": " + event.info.code);
			
			switch (event.info.code)
			{
				case "NetStream.Publish.Start":
					break;
				
				case "NetStream.Play.PublishNotify":
					break;
				
				case "NetStream.Play.Reset":
					break;
				
				case "NetStream.Play.Start":
					// remote peer connected
					// we can't play stream unless remote side has published a stream
					// specifically for us, so if we can play, their connected as well
					if(source == "inStream")
					{
						connectState = UserConnectState.CONNECTED;
						core.user_connected(this);
					}
					break;
				
				case "NetStream.Play.UnpublishNotify":
					if(source == "inStream")
						disconnect();
					break;
			}
		}
	}
}