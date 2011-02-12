package
{
	import flash.external.*;
	
	public class LocaDebug
	{
		public static function log(msg:String):void {
			trace(msg);
		
			if(ExternalInterface.available)
				ExternalInterface.call("flash_log", msg);
		}
	}
}