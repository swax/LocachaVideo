package
{
	import flash.events.*;
	import flash.net.*;
	
	import mx.charts.AreaChart;
	import mx.controls.*;
	
	
	public class LocachaUser
	{
		public var core:LocachaCore;
		public var userID:String;
		public var name:String;
		public var groupID:String;
		public var priority:int;
		public var distance:int;

		public var timeout:int;
		public var connectState:String = ConnectState.HOLDING;

		public var videoStream:NetStream;
		public var audioSamples:Array = new Array();
		

		public function LocachaUser(core:LocachaCore, userID:String):void
		{
			this.core = core;
			this.userID = userID;			
		}
		
		public function update(name:String, groupID:String, priority:int, distance:int):void
		{
			var prevGroupID:String = this.groupID;
			
			this.name = name;
			this.groupID = groupID;
			this.priority = priority;
			this.distance = distance;
			
			if(connectState != ConnectState.HOLDING && groupID != prevGroupID)
			{
				disconnect();
				connect();
			}
		}
		
		public function connect():void
		{
			timeout = 0;
			
			connectState = ConnectState.CONNECTING;
			
			var spec:GroupSpecifier = new GroupSpecifier(groupID);
			spec.serverChannelEnabled = true; 
			spec.multicastEnabled = true;
			
			videoStream = new NetStream(core.netConnection, spec.groupspecWithAuthorizations());
			videoStream.addEventListener(NetStatusEvent.NET_STATUS, stream_statusChange);
			
			var client:Object = new Object();
			client.audioSamples = function(samples:Array):void 
			{						
				try
				{
					timeout = 0; //psuedo ping
					
					for each(var sample:Number in samples)
						audioSamples.push(sample);
						
					while(audioSamples.length > 10)
						audioSamples.pop();
				}
				catch(exc:Error)
				{
					LocaDebug.logError("AUDIO SAMPLES EVENT MYSTERY ERROR", exc);
				}
			}
			videoStream.client = client;
			
			// result event is called on core netConnect
		}
		
		public function disconnect():void 
		{
			LocaDebug.log("disconnecting")
			connectState = ConnectState.DISCONNECTED;
						
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
			LocaDebug.log("User stream event " + event.info.code);
			
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
					videoStream.play("videoStream-" + userID);
					videoStream.receiveVideo(true);
					connectState = ConnectState.CONNECTED;
					LocaDebug.log("Playing " + name + " video!");
					core.ui.user_update(this); 
					break;
				
				//case "NetStream.MulticastStream.Reset":
				case "NetStream.Play.UnpublishNotify":
					disconnect();

					break;
			}
		}
	}
}