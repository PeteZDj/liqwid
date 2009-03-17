﻿/*       *      Copyright 2009 (c) Scott Penberthy, scottpenberthy.com. All Rights Reserved. *       *      This software is distributed under commercial and open source licenses. *      You may use the GPL open source license described below or you may acquire  *      a commercial license from scottpenberthy.com. You agree to be fully bound  *      by the terms of either license. Consult the LICENSE.TXT distributed with  *      this software for full details. *       *      This software is open source; you can redistribute it and/or modify it  *      under the terms of the GNU General Public License as published by the  *      Free Software Foundation; either version 2 of the License, or (at your  *      option) any later version. See the GNU General Public License for more  *      details at: http://scottpenberthy.com/legal/gplLicense.html *       *      This program is distributed WITHOUT ANY WARRANTY; without even the  *      implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  *       *      This GPL license does NOT permit incorporating this software into  *      proprietary programs. If you are unable to comply with the GPL, you must *      acquire a commercial license to use this software. Commercial licenses  *      for this software and support services are available by contacting *      scott.penberthy@gmail.com. * */package com.jsp.plugin { 		import flash.display.MovieClip;	import flash.display.Sprite;	import flash.display.StageAlign;	import flash.display.StageScaleMode;	import flash.events.Event;	import flash.events.MouseEvent;	import flash.events.ContextMenuEvent;	import flash.net.URLRequest;	import flash.net.navigateToURL;	import flash.ui.ContextMenu;	import flash.ui.ContextMenuItem;		import com.jeroenwijering.events.*;	import com.jeroenwijering.utils.*;	import com.jsp.events.LiqwidEvent;	import com.jsp.graphics.Flickr;	import com.jsp.plugin.Milkdrop;	import com.jsp.plugin.Visualizer;	import com.jsp.feeds.PresetFeed;		public class Liqwid extends Sprite implements PluginInterface {		private var _testImages:Array = 	['http://localhost/mesh/slides.xml',	 'http://feed284.photobucket.com/albums/ll15/wolftr33/beach%20ass/feed.rss',	 'http://api.flickr.com/services/feeds/photos_public.gne?id=33643654@N07&lang=en-us&format=rss_200',	 'http://api.flickr.com/services/feeds/photos_public.gne?id=93559610@N00&lang=en-us&format=rss_200',	 'flickr'	 ];		private var _testPlaylists:Array = 	['2816289291','2921344267','2839366155', '3012758283', '15073438987'];		private var _presetURL:String = "http://localhost/mesh/presets.xml";	    /** Reference to the JW Player‚Äôs View object. **/    private var view:AbstractView;	private var _clip:Sprite;	private var _flickr:Flickr;	private var _view:AbstractView;	private var _viz:Visualizer;	private var _w:Number;	private var _h:Number;		//TODO add a config element that can also be set from flashvars    /** This function is automatically called by the player after the plugin has loaded. **/    public function initializePlugin(vw:AbstractView):void {		_view = vw;		init();	}		import com.jsp.graphics.*;	import flash.display.Bitmap;	import flash.display.BitmapData;	import flash.display.Sprite;		private var _txt:Texture;		private function init2():void {		//		// for debugging		//		_txt = new Texture("http://localhost/cake-256.png");		_txt.addEventListener(Event.COMPLETE, doDebug);		_txt.load();	}		private var _echo:VideoEcho;	private var _disp:BitmapData;	private var _bmp:Bitmap;		private function doDebug(e:Event):void {		var echo:VideoEcho = new VideoEcho(_txt.width, _txt.height);		_disp = new BitmapData(_txt.width, _txt.height, true, 0x000000);		_bmp = new Bitmap(_disp);		_disp.draw(_txt);		addChild(_bmp);		echo.orient = 2;		echo.zoom = 0.1;		echo.alpha = 0.1;		_echo = echo;		stage.addEventListener(MouseEvent.CLICK, ticTest);	}		import flash.geom.ColorTransform;		private function ticTest(e:Event):void {		_echo.orient = (_echo.orient + 1)%4;		_echo.zoom += 0.05;		_echo.alpha = (_echo.alpha + 0.1)%1;				_disp.fillRect(_disp.rect, 0x000000);		_disp.draw(_txt);		_echo.echo(_txt.raw, _disp);	}	private function init():void {		_w = _view.config['width'];		_h = _view.config['height'];		stage.align = StageAlign.TOP_LEFT;		stage.scaleMode = StageScaleMode.NO_SCALE;			reconfig();		createElements();		aboutItem();		listeners();		getPictures();		//useCamera();	}		private function createElements():void {		_clip = new Sprite();		_clip.visible = false;		trace("About to create Milkdrop...("+_w+"x"+_h+")");		try {			_viz = new Milkdrop(_w, _h);		}		catch (e:Error) {			trace("Got error "+e);			trace("Stack: "+e.getStackTrace());		}		//_viz = new Visualizer(_w,_h);		_clip.addChild(_viz);		trace("Created milkdrop viz");		if (_presetURL) {			_viz.usePresetFeed(new PresetFeed(_presetURL));		}			addChild(_clip);	}		private function getPictures():void {		if (_view.config['liqwid.images'] == undefined) return;		if (_view.config['liqwid.images'] == 'flickr') testFlickr();		else {			var pl:Playlister = new Playlister();			pl.addEventListener(Event.COMPLETE, gotPictures);			pl.load(_view.config['liqwid.images']);		}	}		private function gotPictures(e:Event):void {		var pl:Playlister = e.target as Playlister;		var pics:Array = new Array();		var list:Object = pl.playlist;		for (var i:int=0; i < list.length; i++) {			var o:Object = list[i];			if (o['file']) {				pics.push({source: o['file']});			}			else if (o['image']) {				pics.push({source: o['image']});			}		}		if (pics.length > 0) {			trace("Found "+pics.length+" photos in the feed.");			_viz.usePictures(pics, parseInt(_view.config['liqwid.speed']));		}	}		private function useCamera():void {		_viz.useCamera();	}		private function reconfig():void {		_view.config['aboutliqwid'] = "About Liqwid";		_view.config['liqwidlink'] = "http://scottpenberthy.com/liqwid";		_view.config['liqwid.images'] = _testImages[0];		_view.config['liqwid.speed'] = '3';		_view.config['liqwid.presets'] = '';  // list of presets		_view.config['file'] = 'http://localhost/mesh/music.xml';		//_view.config['file'] = projectPlaylist(_testPlaylists[1]);		_view.sendEvent('LOAD', _view.config);	}		private function projectPlaylist(id:String):String {		return 'http://scottpenberthy.com/mesh/proxy.php?u='+escape('http://pl.playlist.com/pl.php?e=1&playlist='+id);	}			private function listeners():void {		_view.addModelListener(ModelEvent.STATE,stateHandler);		_view.addModelListener(ModelEvent.META,metaHandler);		_view.addControllerListener(ControllerEvent.RESIZE,resizeHandler);		_view.addControllerListener(ControllerEvent.STOP,stopHandler);		_clip.addEventListener(MouseEvent.CLICK, clickHandler);	}	private function metaHandler(e:ModelEvent):void {		//trace("Heard meta! "+e.data);		if (e.data.artist) trace("Artist: "+e.data.artist);		if (e.data.song) trace("Song: "+e.data.song);		if (e.data.album) trace("Album: "+e.data.album);		if (e.data.year) trace("Year: "+e.data.year);	}		    /** Add a fullscreen menu item. **/	private function aboutItem():void {		if(_view.config['aboutliqwid']) {			var context:ContextMenu = _view.skin.contextMenu;			var itm:ContextMenuItem = new ContextMenuItem(_view.config['aboutliqwid']+'...');			itm.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT,aboutHandler);			itm.separatorBefore = false;			context.customItems.push(itm);		}	}	/** jump to the about page. **/	private function aboutHandler(evt:ContextMenuEvent):void {		navigateToURL(new URLRequest(_view.config['liqwidlink']),'_blank');	}	 /** Only show the visualizer when content is playing. **/    private function stateHandler(evt:ModelEvent=null) {		  var s:String = _view.config['state'];		  //trace("Heard state "+s);		  if (s == ModelStates.PLAYING || s == ModelStates.BUFFERING) play();		  if (s == ModelStates.PAUSED) pause();	}	private function testFlickr():void {		_flickr = new Flickr();		_flickr.addEventListener(LiqwidEvent.IMAGE_LIST, gotFlickrImages);		_flickr.interestingPhotos();	}			private function gotFlickrImages(e:LiqwidEvent):void {		var photos:Array = e.data.imageList;		//trace("Flickr found "+photos.length+" photographs.");		_viz.usePictures(photos, 3); 	}		private function play():void {		//trace("** Starting visualizer");		_viz.play();		_clip.visible = true;	}		private function pause():void {		_viz.pause();	}	private function resizeHandler(e:ControllerEvent):void {		//trace("Config size is "+_view.config['width']+"x"+_view.config['height']);		if (stage.displayState == 'fullScreen') {			_viz.resize(stage.stageWidth, stage.stageHeight);        }        else {			_w = _view.config['width'];			_h = _view.config['height'];           _viz.resize(_w,_h);        }	}		private function stopHandler(e:ControllerEvent):void  {		pause();		_clip.visible = false;	}		private function clickHandler(e:MouseEvent):void {		_view.sendEvent(_view.config['displayclick']);	}		}}