package
{
	import flash.events.*;
	import flash.net.*;

	
	public class LocachaUser
	{
		public var core:LocachaCore;
		public var userID:String;
		public var name:String;
		public var type:String;
		public var groupID:String;
		public var distance:int;

		public var connectState:String = UserConnectState.HOLDING;

		public var videoStream:NetStream;
		

		public function LocachaUser(core:LocachaCore, userID:String):void
		{
			this.core = core;
			this.userID = userID;			
		}
		
		public function update(name:String, type:String, groupID:String, distance:int):void
		{
			this.name = name;
			this.type = type;
			this.groupID = groupID;
			this.distance = distance;
			
			if(connectState != UserConnectState.HOLDING)
			{
				disconnect();
				connect();
			}
		}
		
		public function connect():void
		{
			connectState = UserConnectState.CONNECTING;
			
			var spec:GroupSpecifier = new GroupSpecifier(groupID);
			spec.serverChannelEnabled = true; 
			spec.multicastEnabled = true;
			
			videoStream = new NetStream(core.netConnection, spec.groupspecWithAuthorizations());
			videoStream.addEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
			
			// result event is called on core netConnect
		}
		
		public function disconnect():void 
		{
			trace("disconnecting")
			connectState = UserConnectState.DISCONNECTED;
			
			if(videoStream)
			{
				videoStream.removeEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
				videoStream.close();
				videoStream = null;
			}
			
			core.ui.user_update(this);
		}
		
		public function stream_statusChange(event:NetStatusEvent):void
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
					break;
				
				case "NetStream.Connect.Success":
					connectState = UserConnectState.CONNECTED;
					
					videoStream.play("videoStream-" + userID);
					videoStream.receiveVideo(true);
					
					core.ui.user_update(this);
					
					break;
				
				case "NetStream.Play.UnpublishNotify":
					disconnect();

					break;
			}
		}
	}
}