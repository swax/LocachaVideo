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
		public var currentMic:Microphone;
		public var localConnectState:String = ConnectState.DISCONNECTED;
		
		public var localUserID:String;
		public var localUser:LocachaUser;
		public var nearID:String = "";
		public var groupID:String = "";
		
		public var users:Object = new Object();
		
		private var managePeersTimer:Timer;
		
		
		public function LocachaCore(uiHandle:LocachaVideoBar)
		{
			ui = uiHandle;

			if (ExternalInterface.available)
			{
				ExternalInterface.addCallback("setLocalUser", setLocalUser);  
				ExternalInterface.addCallback("addUser", addUser);  
				ExternalInterface.addCallback("delUser", delUser);  
				ExternalInterface.addCallback("runCommand", runCommand);  
				
				ExternalInterface.call("flash_init");
			}
			
			managePeersTimer = new Timer(1000);
			managePeersTimer.addEventListener(TimerEvent.TIMER, timer_managePeers);
		}	
		
		public function setLocalUser(localUserID:String, name:String):void
		{	
			this.localUserID = localUserID;
			
		    localUser = new LocachaUser(this, localUserID);
			localUser.update(name, "", 50, 0);
		}
		
		public function addUser(userID:String, name:String, groupID:String, priority:int, distance:int):void
		{
			if(userID == this.localUserID)
			{
				LocaDebug.log("attempt to add self");
				return;
			}
			
			var user:LocachaUser = null;
			
			if(!users[userID])
				user = new LocachaUser(this, userID);
			else
				user = users[userID];
			
			user.update(name, groupID, priority, distance);
			
			users[userID] = user;
			
			if(user.connectState == ConnectState.DISCONNECTED)
				user.connectState = ConnectState.HOLDING;
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
			
			managePeersTimer.start();
		}

		public function dispose():void
		{
			LocaDebug.log("disposing core");
			
			managePeersTimer.stop();
			
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
			try
			{
				LocaDebug.log("Core net event: " + event.info.code);
				
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
							videoStream.attachAudio(currentMic);
						}
						else
						{
							for each (var user:LocachaUser in users)
								if(event.info.stream == user.videoStream)
									user.stream_statusChange(event);
						}
						break;
					
					case "NetStream.Publish.Start":
						// not reliable to determine local video start because 
						// cam can be blank and this will fire
						localConnectState = ConnectState.PUBLISHED;
						break;
					
					case "NetStream.Connect.Closed":
						break;
				}
			}
			catch(err:Error)
			{
				LocaDebug.logError("stream_statusChange", err);
			}
		}
		
		// determines who to connect to and what to do next
		private function timer_managePeers(event:TimerEvent) : void
		{
			try
			{
				ui.raiseSizeUpdate();
				
				// connect to 10 peers ordered by priority / distance
				// dont bump anyone, when people naturally log off, start next high priotiry video
				
				var maxCams:int = 8;
				var camsInUse:int = 0;
				
				var deleteUsers:Array = new Array();
				var sortedUsers:Array = new Array();
				
				var user:LocachaUser = null;
				
				for each (user in users)
				{	
					if(user.connectState == ConnectState.CONNECTING ||
					   user.connectState == ConnectState.CONNECTED)
					{
						user.timeout++;
										
						if(user.connectState == ConnectState.CONNECTED && 
							safeGetDecodedFrames(user.videoStream) > user.lastFrame)
						{
							user.lastFrame = user.videoStream.decodedFrames;
							user.timeout = 0;
						}
						
						if(user.timeout >= 20)
						{
							LocaDebug.log("Video connect to " + user.name + " timed out");
							user.disconnect();
						}
						
						camsInUse++;
					}
					
					// remove peers in disconnected state
					if(user.connectState == ConnectState.DISCONNECTED)
						deleteUsers.push(user.userID);
					else
						sortedUsers.push(user);
				}
				
				for each (var id:int in deleteUsers) 
					delete users[user.userID];
	
				// sort users by priority/distance
				sortedUsers.sort(function(a:LocachaUser, b:LocachaUser):int {
					// -1 a before b, 0 equal, 1 a after b
					if(a.priority > b.priority)
						return -1;
					else if(a.priority < b.priority)
						return 1;
					else
					{
						if(a.distance < b.distance)
							return -1;
						else if(a.distance > b.distance)
							return 1;
						else
							return 0;
					}
				});
				
				// todo if sorted users > 50, find last unconnected users in list and disconnect them
				
				// connect to available users
				for each (user in users)
				{
					if(user.connectState == ConnectState.HOLDING && camsInUse < maxCams)
					{
						user.connect();
						camsInUse++;
					}	
				}	
				
				// check local connect state
				if(localConnectState == ConnectState.PUBLISHED && 
					safeGetDecodedFrames(videoStream) > 0)
				{
					LocaDebug.log("local video stream started");
					localConnectState = ConnectState.CONNECTED;
				
					if (ExternalInterface.available) 
						ExternalInterface.call("flash_videoUpdate", groupID);	
				}		
			}
			catch(err:Error)
			{
				LocaDebug.logError("timer_managePeers", err);
			}
		}
		
		public function safeGetDecodedFrames(stream:NetStream):uint
		{
			if(!stream)
				return 0;
			
			try
			{
				return stream.decodedFrames;
			}
			catch(err:Error)
			{
			}
			return 0;
		}
		
		/// called from ui when cam goes on/off
		public function updateLocalVideo(camera:Camera, mic:Microphone):void
		{
			currentCamera = camera;
			currentMic = mic;
			
			// setup the video stream if there's a camera
			if(camera && netConnection.connected && !videoStream)
			{
				LocaDebug.log("publishing video stream");
				groupID = "videoGroup-" + Math.round(Math.random()*1000000).toString();
				var spec:GroupSpecifier = new GroupSpecifier(groupID);
				spec.serverChannelEnabled = true; 
				spec.multicastEnabled = true;

				var auth:String = spec.groupspecWithoutAuthorizations();
				videoStream = new NetStream(netConnection, auth);
				videoStream.addEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
				
				localConnectState = ConnectState.CONNECTING;
			}

			// close the video stream if no camera
			if(!camera && videoStream)
			{
				LocaDebug.log("closing local video stream");

				videoStream.removeEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
				videoStream.close();
				videoStream = null;
				
				localConnectState = ConnectState.DISCONNECTED;
				
				if (ExternalInterface.available) 
					ExternalInterface.call("flash_videoUpdate", "");
			}
		}
		
		private function runCommand(cmd:String):void
		{
			if(cmd == "status")
				statusReport();
			else if(cmd == "msg" && videoStream)
				videoStream.send("message", "hello");
			
		}
		
		private function statusReport():void
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
			
			LocaDebug.log(status);
		}
		
	}
}