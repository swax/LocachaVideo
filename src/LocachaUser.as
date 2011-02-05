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
			trace("1. starting listen stream");
			streamOut = new NetStream(core.netConnection, NetStream.DIRECT_CONNECTIONS);
			streamOut.addEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
			streamOut.publish("streamOut-" + farID);
			
			// play remote control stream
			trace("2. connecting to remote user");
			streamIn = new NetStream(core.netConnection, farID);
			streamIn.addEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
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
					videoStream.addEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
				}
				
				if(videoStream && videoHandle != handle)
				{
					videoHandle = handle;
					
					if(handle)
					{
						videoStream.play(handle);
						videoStream.receiveVideo(true);
					}
					else
					{
						videoStream.removeEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
						videoStream.close()
						videoStream = null;
					}
				}

				core.ui.user_update(self);
			}
				
			streamIn.client = client;
		}
		
		public function disconnect():void 
		{
			trace("disconnecting")
			connectState = UserConnectState.DISCONNECTED;
			
			if(streamOut)
			{
				streamOut.removeEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
				streamOut.close();
				streamOut = null;
			}
			
			if(streamIn)
			{
				streamIn.removeEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
				streamIn.close();
				streamIn = null;
			}

			if(videoStream)
			{
				videoHandle = null
				videoStream.removeEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
				videoStream.close();
				videoStream = null;
			}
		}
		
		private function stream_statusChange(event:NetStatusEvent):void
		{	
			trace("User stream event " + event.info.code);
			
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
					if(event.target == streamIn)
					{
						trace("3. connected")
						connectState = UserConnectState.CONNECTED;
						core.user_connected(this);
					}
					break;
				
				case "NetStream.Play.UnpublishNotify":
					if(event.target == streamIn)
						disconnect();
					
					//else if(event.target == videoStream)
						// remote video closed, update the handle
					//	videoStream.client.videoHandleUpdate(null);
					
					break;
			}
		}
	}
}