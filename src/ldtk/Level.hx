package ldtk;

enum NeighbourDir {
	NorthEastCorner;
	NorthWestCorner;
	SouthEastCorner;
	SouthWestCorner;
	North;
	South;
	West;
	East;
	SameDepthOverlap;
	DepthBelow;
	DepthAbove;
}

typedef LevelBgImage = {
	var relFilePath: String;

	/** Top-left X coordinate of background image **/
	var topLeftX: Int;

	/** Top-left Y coordinate of background image **/
	var topLeftY: Int;

	/** X scale factor of background image **/
	var scaleX: Float;

	/** Y scale factor of background image **/
	var scaleY: Float;

	/** Cropped sub rectangle in background image **/
	var cropRect: {
		x: Float,
		y: Float,
		w: Float,
		h: Float,
	}
}

class Level {
	var untypedProject: ldtk.Project; // WARNING: the var type isn't the "complete" project type as generated by macros!

	/** Original parsed JSON object **/
	public var json(default,null) : ldtk.Json.LevelJson;

	public var iid(default,null) : String;
	public var uid(default,null) : Int;
	public var identifier(default,null) : String;
	public var pxWid(default,null) : Int;
	public var pxHei(default,null) : Int;
	public var worldX(default,null) : Int;
	public var worldY(default,null) : Int;
	public var worldDepth(default,null) : Int;

	/** Level background color (as Hex "#rrggbb") **/
	public var bgColor_hex(default,null): String;

	/** Level background color (as Int 0xrrggbb) **/
	public var bgColor_int(default,null): UInt;

	@:deprecated("Use bgColor_int instead") @:noCompletion
	public var bgColor(get,never) : UInt;
		@:noCompletion inline function get_bgColor() return bgColor_int;

	public var allUntypedLayers(default,null) : Array<Layer>;
	public var neighbours : Array<{ levelIid:String, dir: NeighbourDir }>;
	public var bgImageInfos(default,null) : Null<LevelBgImage>;

	/** Index in project `levels` array **/
	public var arrayIndex(default,null) : Int;

	/** Only exists if levels are stored in separate level files **/
	var externalRelPath(default,null) : Null<String>;


	public function new(project:ldtk.Project, arrayIdx:Int, json:ldtk.Json.LevelJson) {
		this.untypedProject = project;
		this.arrayIndex = arrayIdx;
		fromJson(json);
		project._assignFieldInstanceValues(this, json.fieldInstances);
	}

	/** Print class debug info **/
	@:keep public function toString() {
		return 'ldtk.Level[#$identifier, ${pxWid}x$pxHei]';
	}


	/** Parse level JSON **/
	function fromJson(json:ldtk.Json.LevelJson) {
		this.json = json;
		neighbours = [];
		allUntypedLayers = [];

		iid = json.iid;
		uid = json.uid;
		identifier = json.identifier;
		pxWid = json.pxWid;
		pxHei = json.pxHei;
		worldX = json.worldX;
		worldY = json.worldY;
		worldDepth = json.worldDepth;
		bgColor_hex = json.__bgColor;
		bgColor_int = Project.hexToInt(json.__bgColor);

		bgImageInfos = json.bgRelPath==null || json.__bgPos==null ? null : {
			relFilePath: json.bgRelPath,
			topLeftX: json.__bgPos.topLeftPx[0],
			topLeftY: json.__bgPos.topLeftPx[1],
			scaleX: json.__bgPos.scale[0],
			scaleY: json.__bgPos.scale[1],
			cropRect: {
				x: json.__bgPos.cropRect[0],
				y: json.__bgPos.cropRect[1],
				w: json.__bgPos.cropRect[2],
				h: json.__bgPos.cropRect[3],
			},
		}

		externalRelPath = json.externalRelPath;

		if( json.layerInstances!=null )
			for(json in json.layerInstances)
				allUntypedLayers.push( _instanciateLayer(json) );

		if( json.__neighbours!=null )
			for(n in json.__neighbours)
				neighbours.push({
					levelIid: n.levelIid,
					dir: switch n.dir {
						case "nw": NorthWestCorner;
						case "ne": NorthEastCorner;
						case "sw": SouthWestCorner;
						case "se": SouthEastCorner;

						case "n": North;
						case "s": South;
						case "w": West;
						case "e": East;

						case "<": DepthBelow;
						case ">": DepthAbove;
						case "o": SameDepthOverlap;

						case _: trace("WARNING: unknown neighbour level dir: "+n.dir); North;
					},
				});
	}


	function _instanciateLayer(json:ldtk.Json.LayerInstanceJson) : ldtk.Layer {
		if (json.__type == "Tiles") {
			return new ldtk.Layer_Tiles(this.untypedProject, json);
		} else if(json.__type == "AutoLayer") {
			return new ldtk.Layer_AutoLayer(this.untypedProject, json);
		}
		else {
			return new ldtk.Layer(this.untypedProject, json);
		}
		
	}


	/**
		Return TRUE if the level was previously loaded and is ready for usage (always TRUE if levels are embedded in the project file).
	**/
	public inline function isLoaded() return this.externalRelPath==null || allUntypedLayers!=null && allUntypedLayers.length>0;

	/**
		Load level if it's stored in an external file. **IMPORTANT**: this probably doesn't need to be used in most scenario, as `load()` is *automatically* called when trying to use a level variable in your project.
	**/
	public function load() {
		if( isLoaded() )
			return true;


		var bytes = untypedProject.getAsset(externalRelPath);
		try {
			var raw = bytes.toString();
			var json : ldtk.Json.LevelJson = haxe.Json.parse(raw);
			fromJson(json);
			return true;
		}
		catch(e:Dynamic) {
			Project.error('Failed to parse external level $identifier: $externalRelPath ($e)');
			return false;
		}
	}


	public inline function hasBgImage() {
		return bgImageInfos!=null;
	}


	#if !macro

		#if heaps
		var _cachedBgTile : Null<h2d.Tile>;

		/**
			Get the full "raw" (ie. non-cropped, scaled or positioned) background Tile. Use `getBgBitmap()` instead to get the "ready for display" background image.
		**/
		public function getRawBgImageTile() : Null<h2d.Tile> {
			if( bgImageInfos==null )
				return null;

			if( _cachedBgTile==null ) {
				var bytes = untypedProject.getAsset(bgImageInfos.relFilePath);
				_cachedBgTile = dn.ImageDecoder.decodeTile(bytes);
				if( _cachedBgTile==null )
					_cachedBgTile = h2d.Tile.fromColor(0xff0000, pxWid, pxHei);
			}
			return _cachedBgTile;
		}

		/**
			Return the level background image, ready for display. The bitmap coordinates and scaling also match level background settings.
		**/
		public function getBgBitmap(?parent:h2d.Object) : Null<h2d.Bitmap> {
			var t = getRawBgImageTile();
			if( t==null )
				return null;

			t = t.sub(
				bgImageInfos.cropRect.x,
				bgImageInfos.cropRect.y,
				bgImageInfos.cropRect.w,
				bgImageInfos.cropRect.h
			);
			var bmp = new h2d.Bitmap(t, parent);
			bmp.x = bgImageInfos.topLeftX;
			bmp.y = bgImageInfos.topLeftY;
			bmp.scaleX = bgImageInfos.scaleX;
			bmp.scaleY = bgImageInfos.scaleY;
			return bmp;
		}
		#end

		#if flixel
		public function getBgSprite() : Null< flixel.FlxSprite > {
			if( bgImageInfos==null )
				return null;

			// Full image
			var graphic = untypedProject.getFlxGraphicAsset( bgImageInfos.relFilePath );
			if( graphic==null )
				return null;

			// Cropped sub section
			var f = flixel.graphics.frames.FlxImageFrame.fromGraphic(graphic, flixel.math.FlxRect.weak(
				bgImageInfos.cropRect.x,
				bgImageInfos.cropRect.y,
				bgImageInfos.cropRect.w,
				bgImageInfos.cropRect.h
			));

			// FlxSprite
			var spr = new flixel.FlxSprite();
			spr.frame = f.frame;
			spr.x = bgImageInfos.topLeftX;
			spr.y = bgImageInfos.topLeftY;
			spr.origin.set(0,0);
			spr.scale.set(bgImageInfos.scaleX, bgImageInfos.scaleY);
			return spr;
		}
		#end

	#end // End of "if !macro"
}
