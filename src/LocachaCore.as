package
{
	import flash.events.*;
	import flash.external.*;
	import flash.media.*;
	import flash.net.*;
	import flash.utils.*;
	import mx.controls.*;
	import mx.core.mx_internal;

	
	public class LocachaCore
	{
		public const SERVER_ADDRESS:String = "rtmfp://p2p.rtmfp.net";
		public const DEVELOPER_KEY:String = "71513203c7af510770d7d3a4-fd8e748c788e";
		
		public var ui:LocachaVideoBar;
		
		public var netConnection:NetConnection;
		public var videoStream:NetStream;
		public var currentCamera:Camera;
		
		public var localUserID:String;
		public var localUser:LocachaUser;
		public var nearID:String = "";
		public var groupID:String = "";
		
		public var users:Object = new Object();
		
		private var statusTimer:Timer;
		
		
		public function LocachaCore(uiHandle:LocachaVideoBar)
		{
			ui = uiHandle;

			if (ExternalInterface.available)
			{
				ExternalInterface.addCallback("setLocalUser", setLocalUser);  
				ExternalInterface.addCallback("addUser", addUser);  
				ExternalInterface.addCallback("delUser", delUser);  
				
				ExternalInterface.call("flash_init");
				ui.raiseSizeUpdate();
			}
			
			statusTimer = new Timer(1000);
			statusTimer.addEventListener(TimerEvent.TIMER, timer_userStatus);
			statusTimer.start();
			
		}	
		
		public function setLocalUser(name:String, localUserID:String):void
		{	
			this.localUserID = localUserID;
			
		    localUser = new LocachaUser(this, localUserID);
			localUser.update(name, "local", "", 0);
		}
		
		public function addUser(userID:String, name:String, type:String, groupID:String, distance:int):void
		{
			if(userID == this.localUserID)
			{
				Alert.show("adding self")
				return;
			}
			
			var user:LocachaUser = null;
			
			if(!users[userID])
				user = new LocachaUser(this, userID);
			else
				user = users[userID];
			
			user.update(name, type, groupID, distance);
			
			users[userID] = user;
			
			if(user.connectState == UserConnectState.DISCONNECTED)
				user.connectState = UserConnectState.HOLDING;
			
			managePeers();
		}
		
		public function delUser(userID:String):void
		{
			if(!users[userID])
				return;
			
			var user:LocachaUser = users[userID];
			
			user.disconnect();
			
			delete users[userID];
			
		    ui.user_update(user);
		}
		
		public function connect():void
		{
			if(netConnection)
				return;
			
			netConnection = new NetConnection();
			netConnection.addEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
			netConnection.connect(SERVER_ADDRESS + "/" + DEVELOPER_KEY);	
		}

		public function dispose():void
		{
			trace("disposing core");
			
			if(videoStream)
			{
				videoStream.removeEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
				videoStream.close();
				videoStream = null;
			}
			
			for each (var user:LocachaUser in users)
				user.disconnect();
			users = new Object();
			
			if(netConnection)
			{
				netConnection.removeEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
				netConnection.close();
				netConnection = null;
			}
		}
		
		
		private function stream_statusChange(event:NetStatusEvent):void
		{
			trace("Core net event: " + event.info.code);
			
			switch (event.info.code)
			{
				case "NetConnection.Connect.Success":
					break;
				
				case "NetConnection.Connect.Closed":
					break;
				
				case "NetConnection.Connect.Failed":
					break;
				
				case "NetStream.Connect.Success":

					// we get this when other party connects to our control stream our outgoing stream
					//status("Connection from: " + event.info.stream.farID + "\n");
					if(event.info.stream == videoStream)
					{
						videoStream.publish("videoStream-" + localUserID);
						
						videoStream.attachCamera(currentCamera);
					}
					else
					{
						for each (var user:LocachaUser in users)
							if(event.info.stream == user.videoStream)
								user.stream_statusChange(event);
					}
					break;
				
				case "NetStream.Publish.Start":
					if(event.target == videoStream)
					{
						if (ExternalInterface.available) 
							ExternalInterface.call("flash_videoStart", groupID);
	
					}
					break;
				
				case "NetStream.Connect.Closed":
					break;
			}
		}
		
		// determines who to connect to and what to do next
		private function managePeers() : void
		{
			for each (var user:LocachaUser in users)
			{
				if(user.connectState == UserConnectState.HOLDING)
					user.connect();		
			}
		}
		
		/// called from ui when cam goes on/off
		public function updateVideo(camera:Camera):void
		{
			currentCamera = camera;
			
			// setup the video stream if there's a camera
			if(camera && netConnection.connected)
			{
				if(!videoStream)
				{
					trace("publishing video stream");
					groupID = "videoGroup-" + Math.round(Math.random()*1000000).toString();
					var spec:GroupSpecifier = new GroupSpecifier(groupID);
					spec.serverChannelEnabled = true; 
					spec.multicastEnabled = true;

					var auth:String = spec.groupspecWithoutAuthorizations();
					videoStream = new NetStream(netConnection, auth);
					videoStream.addEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
				}
				else
				{
					videoStream.attachCamera(camera);
				}
			}

			// close the video stream if no camera
			if(!camera && videoStream)
			{
				trace("closing local video stream");

				videoStream.removeEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
				videoStream.close();
				videoStream = null;
			}
		}
		
		private function timer_userStatus(event:TimerEvent):void
		{
			var status:String = "my id: " + this.localUserID + "<br />";
			
			if(netConnection && netConnection.connected)
				status += "net: connected<br />";	
			else
				status += "net: disconnected<br />";
			
			for each (var user:LocachaUser in users)
			{
				status += "remote " + user.userID.substr(0, 4) + ": " +
					user.connectState + "<br />";
			}
			
			if (ExternalInterface.available)
				ExternalInterface.call("flash_debugStatus", status);
		}
	}
}