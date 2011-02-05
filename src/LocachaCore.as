package
{
	import flash.events.*;
	import flash.media.*;
	import flash.net.*;

	
	public class LocachaCore
	{
		public const SERVER_ADDRESS:String = "rtmfp://p2p.rtmfp.net";
		public const DEVELOPER_KEY:String = "71513203c7af510770d7d3a4-fd8e748c788e";
		
		public var ui:Object;
		public var netConnection:NetConnection;
		public var listenerStream:NetStream;
		
		public var nearID:String;
		public var users:Object = new Object();
		

		public function LocachaCore(uiHandle:Object)
		{
			ui = uiHandle;
		}	
		
		public function addUser(farID:String):void
		{
			if(users[farID])
				return;
			
			var user:LocachaUser = new LocachaUser(this, farID);
			
			users[farID] = user;
			
			managePeers();
		}
		
		public function connect():void
		{
			netConnection = new NetConnection();
			netConnection.addEventListener(NetStatusEvent.NET_STATUS, netConnection_statusChange);
			netConnection.connect(SERVER_ADDRESS + "/" + DEVELOPER_KEY);	
		}
		
		private function netConnection_statusChange(event:NetStatusEvent):void
		{
			net_statusChange("netConnection", event);
		}
		
		private function net_statusChange(source:String, event:NetStatusEvent):void
		{
			trace(source + " event: " + event.info.code + "\n");
			
			switch (event.info.code)
			{
				case "NetConnection.Connect.Success":
					//connectSuccess();
					ui.core_connected();
					nearID = netConnection.nearID;
					break;
				
				case "NetConnection.Connect.Closed":
					//loginState = LoginNotConnected;
					//callState = CallNotReady;
					ui.core_disconnected();
					break;
				
				case "NetConnection.Connect.Failed":
					//status("Unable to connect to " + connectUrl + "\n");
					//loginState = LoginNotConnected;
					ui.core_disconnected();
					break;
				
				case "NetStream.Connect.Success":
					// we get this when other party connects to our control stream our outgoing stream
					//status("Connection from: " + event.info.stream.farID + "\n");
					break;
				
				case "NetStream.Connect.Closed":
					//onHangup();
					break;
			}
		}
		
		public function user_connected(user:LocachaUser):void
		{
			managePeers();
		}
	
		// determines who to connect to and what to do next
		private function managePeers() : void
		{
			for each (var user:LocachaUser in users)
			{
				if(user.connectState == UserConnectState.DISCONNECTED)
				{
					user.connect();		
				}
				else if(user.connectState == UserConnectState.CONNECTED)
				{
					if(user.status == UserStatus.HOLDING)
					{
						user.status = UserStatus.REQUESTING;
						user.streamOut.send("requestVideo");	
					}
				}
			}
		}
		
		public function user_requestVideo(user:LocachaUser):void
		{
			trace("user requesting video");
			
			// see if we want to accept request
			var accept:Boolean = true;
			
			user.status = UserStatus.ACTIVE;
			// send handle to our video stream
			
			user.streamOut.send("requestVideoResponse", accept);
			
			user.streamOut.send("videoHandleUpdate", videoHandle);
		}
		
		public function user_requestVideoResponse(user:LocachaUser, accept:Boolean):void
		{
			trace("sending video request response");
			
			if(accept)
			{
				user.status = UserStatus.ACTIVE;
				
				user.streamOut.send("videoHandleUpdate", videoHandle);
			}
		}
		
		private var videoStream:NetStream = null;
		private var videoHandle:String = null;
		
		public function updateVideo(camera:Camera):void
		{
			// setup the video stream if there's a camera
			if(camera && !videoStream && netConnection.connected)
			{
				trace("creating local video stream");
				videoStream = new NetStream(netConnection, NetStream.DIRECT_CONNECTIONS);
				videoStream.addEventListener(NetStatusEvent.NET_STATUS, videoStream_statusChange);
				
				videoHandle = "videoStream-" + Math.round(Math.random()*1000000).toString();
				videoStream.publish(videoHandle);
				videoStream.attachCamera(camera);
			}
			
			// close the video stream if no camera
			if(!camera && videoStream)
			{
				trace("closing local video stream");
				videoHandle = null;
				
				videoStream.removeEventListener(NetStatusEvent.NET_STATUS, videoStream_statusChange);
				videoStream.close();
				videoStream = null;
			}
			
			// if users already connected, update them of status, or lack there of
			for each (var user:LocachaUser in users)
				user.streamOut.send("videoHandleUpdate", videoHandle);
		}
		
		private function videoStream_statusChange(event:NetStatusEvent):void
		{
			net_statusChange("videoStream", event);
		}
		
	}
}