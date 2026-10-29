package puffpuff.media;

#if hl
@:hlNative("blinc_abi")
extern class BitmapNative {
	static function blinc_bitmap_decode(bytes:hl.Bytes, len:Int):Int;
	static function blinc_bitmap_size(slot:Int, height:Bool):Int;
	static function blinc_bitmap_release(slot:Int):Void;
	static function blinc_bitmap_resample(slot:Int, width:Int, height:Int, fit:Int, out:hl.Bytes):Bool;
	static function blinc_bitmap_shrink(slot:Int, maxSide:Int):Bool;
}
#end
