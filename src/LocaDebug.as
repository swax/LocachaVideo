package
{
	import flash.external.*;
	
	public class LocaDebug
	{
		public static function log(msg:String):void 
		{
			trace(msg);
		
			if(ExternalInterface.available)
				ExternalInterface.call("site.flash_log", msg);
		}
		
		public static function logError(func:String, err:Error):void
		{
			log("Error in " + func + ": " + err.name + " - " + err.message + " - " + err.getStackTrace());
		}
	}
}