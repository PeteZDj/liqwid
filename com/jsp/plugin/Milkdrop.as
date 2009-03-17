﻿/*       *      Copyright 2009 (c) Scott Penberthy, scottpenberthy.com. All Rights Reserved. *       *      This software is distributed under commercial and open source licenses. *      You may use the GPL open source license described below or you may acquire  *      a commercial license from scottpenberthy.com. You agree to be fully bound  *      by the terms of either license. Consult the LICENSE.TXT distributed with  *      this software for full details. *       *      This software is open source; you can redistribute it and/or modify it  *      under the terms of the GNU General Public License as published by the  *      Free Software Foundation; either version 2 of the License, or (at your  *      option) any later version. See the GNU General Public License for more  *      details at: http://scottpenberthy.com/legal/gplLicense.html *       *      This program is distributed WITHOUT ANY WARRANTY; without even the  *      implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  *       *      This GPL license does NOT permit incorporating this software into  *      proprietary programs. If you are unable to comply with the GPL, you must *      acquire a commercial license to use this software. Commercial licenses  *      for this software and support services are available by contacting *      scott.penberthy@gmail.com. * */  // TODO Blend presets when they change, Geiss style // TODO optimize this.  The Milkdrop variable scoping is, um, unique.package com.jsp.plugin {	import flash.display.BitmapData;	import flash.display.Sprite;	import flash.events.Event;	import flash.events.MouseEvent;	import flash.events.TimerEvent;	import flash.utils.Timer;	import flash.utils.getTimer;	import com.jsp.audio.MusicAnalyzer;	import com.jsp.audio.Wave;	import com.jsp.calculator.*;	import com.jsp.graphics.Border;	import com.jsp.graphics.Frame;	import com.jsp.graphics.uvPolygon;	import com.jsp.graphics.uvSprite;	import com.jsp.graphics.Shader;	import com.jsp.graphics.SlideShow;	import com.jsp.graphics.Chart;	import com.jsp.video.Webcam;	import com.jsp.feeds.PresetFeed;	import com.jsp.events.LiqwidEvent;	import com.jsp.graphics.Pixel;	public class Milkdrop extends Visualizer {		private var _exp:Expression;		private var _cFrame:Calculator;		private var _frameNum:int=0;		private var _useMotionVectors:Boolean=false;		private var _modWaveAlphaByVolume:Boolean=false;		private var _aStart:Number, _aEnd:Number;		private var _snapshot:Array=null;		private var _cShapes:Array;		private var _shapeInit:Array;		private var _cTool:Calculator;		private var _needCamera:Boolean=false;		private var _needSlides:Boolean=false;		private var _needVideo:Boolean=false;		private var _monitor:Chart;				//		// Should this be its own class?		//		protected var _frameConfig:Object = {			warp: 1.0,			warp_speed: 1.0,			warp_scale: 1.0,			zoom: 1.0,			rot: 0.0,			cx: 0.5,			cy: 0.5,			dx: 0.0,			dy: 0.0,			sx: 1.0,			sy: 1.0,			decay: 0.98,			wave_scale: 1.0,			monitor: 0, // undefined,			time: 0.0,			frame: 0.0,			mouse_x: 0.5,			mouse_y: 0.5,			fps: 24,			rating: 1.0,			progress: 0.5,			darkcenter:0,			darkencenter: 0,			ve_zoom: 0.5,			ve_orient: 1,			ve_alpha: 0,			invert: 0,			brighten: 0,			darken: 0,			solarize: 0,			wave_dots: 0,			max_color: 1,			wave_param: 0.0,			wave_alpha_start: 0.0,			wave_alpha_end: 1.0,			wave_mode: 5,			wave_x: 0.5,			wave_y: 0.5,			wave_r: 0.5,			wave_g: 0.5,			wave_b: 0.5,			wave_a: 1.0,			wave_thick: 1,			wave_additive: 0,			wave_brighten: 1,			mod_wave_alpha_by_volume: 0,			ob_size: 0.001,			ob_r: 0.1,			ob_g: 0.1,			ob_b: 0.8,			ob_a: 0.6,			ib_size: 0.001,			ib_r: 0.2,			ib_g: 0.5,			ib_b: 0.2,			ib_a: 0.2,			scale_sound: 1.0,			wave_smooth: 0,			interpolate: 1,			mid: 0,			bass: 0,			treble: 0,			mid_att: 0,			bass_att: 0,			treble_att: 0,			amp: 0,			meshx: 12,			meshy: 9,			wrap: 1,			q1: 0,			q2: 0,			q3: 0,			q4: 0,			q5: 0,			q6: 0,			q7: 0,			q8: 0,			motionVectors: 0,			mv_r: 1,			mv_g: 1,			mv_b: 1,			mv_a: 0,			mv_x: 4,			mv_y: 4,			mv_dx: 0.01,			mv_dy: 0.01,			mv_l: 1			};		/** This function is automatically called by the player after the plugin has loaded. **/		public function Milkdrop(w:Number, h:Number):void {			super(w,h);			//trace("Creating milkdrop");			_cFrame = new Calculator();			_cTool = new Calculator();			_monitor = new Chart('unknown',300,90);			_monitor.visible = false;			addChild(_monitor);		}			override protected function tic():void {			readFrame();			_cFrame.eval();			writeFrame();			doShapes();			_frame.render(_t);			if (_needCamera) useCamera();			if (_needSlides) {				if (_show) _show.start();			}			else {				// let's be smarter about when to call this please				if (_show) _show.stop();			}			if (_monitor.visible) _monitor.plot();		}				override protected function updatePreset():void {			//			// _program will have {author:, title:, preset:} attributes			//			//trace("Updating preset in Milkdrop.");			if (_program == null || _program.preset == null) return;			//trace("Using preset:"+_program.preset);			compilePreset();			createFirstFrame();			addFrameShader();			addPixelShader();			addShapeShaders();			checkMonitor();		}		private function snapshotFrame():void {			var m:Array=_cFrame.memory;			_snapshot = m.slice(0);		}		private function restoreFrame():void {			if (_snapshot==null) {				return;			}			var m:Array = _cFrame.memory;			var len1:int = Math.min(_snapshot.length,Milk.FRAME_END);			for (var i:uint = 0; i<len1; i++) {				m[i]=_snapshot[i];			}		}		private function compilePreset():void {			// _exp now has 			//			// 1) global variables in the top-level expression			// 2) per_frame_ bytecodes to run each frame			// 3) per_pixel_ bytecodes to run each pixel			// ...			_exp=new Expression(_program.preset);			_exp.compile();			//_exp.showJit();			_cFrame.expandMemory();		}				private function checkMonitor():void {			var mvar:String = _exp.monitor(Milk.frame.code);			//trace("FRAME MONITOR mvar="+mvar);			if (mvar) {				_monitor.title = mvar;				_monitor.visible = true;			}			else {				_monitor.visible = false;			}		}		private function createFirstFrame():void {			restoreFrameDefaults();			_cFrame.bytecodes = _exp.bytecodes;// global vars			_cFrame.eval();			initializeFrameUsingPresetValues();			_cFrame.bytecodes = _exp.blockCodes(Milk.frame.init);// init routine			_cFrame.eval();			_monitor.clear();			snapshotFrame();		}		private function addFrameShader():void {			// initialize and load up our frame shader			var frameShader:Array=_exp.blockCodes(Milk.frame.code);			if (frameShader) {				//trace("Frame shader:");				//_exp.showOps(frameShader);			} else {				_exp = new Expression(mypreset(_program.preset));				_exp.compile();				_cFrame.expandMemory();				_cFrame.bytecodes = _exp.blockCodes(Milk.frame.code);				//trace("Frame shader:");				//_exp.showOps(_cFrame.bytecodes);			}			_cFrame.bytecodes = frameShader;			_cFrame.eval();		}		private function addPixelShader():void {			// Initialize and load up our pixel shader			var pixelShader:Array = _exp.blockCodes(Milk.pixel.code);			if (pixelShader) {				//trace("Pixel shader:");				//_exp.showOps(pixelShader);			}			_shader.storeCodes(pixelShader);			_frame.useShader(_shader);			writeFrame();		}				private function addShapeShaders():void {			// Initialize and load up each shape			var shapeCodes:Array;			var shapeShader:Array;			var shapeInit:Array;			var len:Number = Milk.NUM_SHAPES;						_cShapes = new Array();			_shapeInit = new Array();			_cTool.clear();			for (var i:uint=0; i < len; i++) {				_frame.shape(i).active = false;				shapeCodes = _exp.blockCodes(Milk.shape[i].code);				shapeInit = _exp.blockCodes(Milk.shape[i].per_frame_init);				shapeShader = _exp.blockCodes(Milk.shape[i].per_frame);							if (shapeCodes) {					_cTool.bytecodes = shapeCodes;					_cTool.eval();					if (_cTool.lookup('enabled') == 1) {						//trace("Adding shape "+i);						var cs:Calculator = new Calculator();						_cShapes.push(cs);						cs.clear();						cs.bytecodes = shapeCodes;						cs.eval();						if (shapeInit) {							cs.bytecodes = shapeInit;							cs.eval();						}						_shapeInit.push(cs.memory.slice(0));						cs.bytecodes = shapeShader;						//trace("\n**SHAPE "+i+" SHADER**\n");						//_exp.showOps(shapeShader);					}				}			}		}				private function doShapes():void {			for (var i:int=0; i < _cShapes.length; i++) {				var c:Calculator = _cShapes[i];				var m:Array = c.memory;				var shape:uvPolygon = _frame.shape(i);						c.eval();				//trace("shape amp="+c.lookup('amp'));				shape.active = true;				shape.sides = m[Milk.SIDES];				shape.inner(m[Milk.R],m[Milk.G],m[Milk.B],m[Milk.A]);				shape.outer(m[Milk.R2],m[Milk.G2],m[Milk.B2],m[Milk.A2]);				shape.border(m[Milk.BORDER_R],m[Milk.BORDER_G],m[Milk.BORDER_B],m[Milk.BORDER_A]);				shape.uv(m[Milk.X],m[Milk.Y]);				shape.progress = _t;				shape.rad = m[Milk.RAD];								_needVideo = _needSlides = _needCamera = shape.textured = false;				//m[Milk.TEXTURED]=1;				switch (m[Milk.TEXTURED]) {					case 1:						if (_frame.raw) shape.useTexture(_frame.raw);						break;											case 2:									if (_show) {							if (_show.raw) shape.useTexture(_show.raw);							_needSlides = true;						}						break;					case 3:						if (!_cam) {							_needCamera = true;							break;						}						else if (_cam.raw) {							shape.useTexture(_cam.raw);						}						break;					case 3:						_needVideo = true;						//trace("Shape: Video support not yet implemented.");						// show a video!						break;				}				shape.tex_zoom = m[Milk.TEX_ZOOM];				// tex rotation?			}		}									private function readFrame():void {			var m:Array = _cFrame.memory;			restoreFrame();			_frame.motionVectors = _useMotionVectors || (m[Milk.MV_A] > 0);			_wave.progress=_t;// TODO rename wave.progress to wave.time			m[Milk.FPS]=15;			m[Milk.TIME]=_t;			m[Milk.FRAME]=_frameNum;			m[Milk.MOUSE_X] = (mouseX - _w2) / _w2;			m[Milk.MOUSE_Y] = (mouseY - _h2) / _h2;			m[Milk.PROGRESS]=_progress;			m[Milk.BASS]=_ma.bass;			m[Milk.MID]=_ma.mid;			m[Milk.TREBLE]=_ma.treble;			m[Milk.BASS_ATT]=_ma.bass_att;			m[Milk.MID_ATT]=_ma.mid_att;			m[Milk.TREBLE_ATT]=_ma.treb_att;			m[Milk.AMP]=_ma.amp;			m[Milk.MESHX] = 16;			m[Milk.MESHY] = 9;		}		private function writeFrame():void {			var m:Array=_cFrame.memory;			_frameNum++;			// decay			_frame.decay=m[Milk.DECAY];			_frame.echoAlpha=m[Milk.VE_ALPHA];			_frame.echoOrient=m[Milk.VE_ORIENT];			_frame.echoZoom=Math.min(1000,Math.max(0.001,m[Milk.VE_ZOOM]));			// inner border			_border.inner(m[Milk.IB_R],m[Milk.IB_G],m[Milk.IB_B],m[Milk.IB_A],m[Milk.IB_SIZE]);			// outer border			_border.outer(m[Milk.OB_R],m[Milk.OB_G],m[Milk.OB_B],m[Milk.OB_A],m[Milk.OB_SIZE]);			// wave properties			var wa:Number = m[Milk.WAVE_A];			if (_modWaveAlphaByVolume) wa *= (_ma.amp - _aStart)/(_aEnd - _aStart);			if (wa < 0) wa=0;			if (wa > 1) wa=1;			if (wa < 0.1) wa = 0.1;			_wave.setColor(m[Milk.WAVE_R],m[Milk.WAVE_G],m[Milk.WAVE_B],wa);			_wave.mode=m[Milk.WAVE_MODE];			_wave.uv(m[Milk.WAVE_X], m[Milk.WAVE_Y]);			_wave.setLevels(m[Milk.BASS], m[Milk.MID], m[Milk.TREBLE]);			_wave.thick = m[Milk.WAVE_THICK];			_wave.mystery=m[Milk.WAVE_MYSTERY]; 			_wave.sample(_ma.L, _ma.R, m[Milk.WAVE_MODE]);			//trace("Wave "+_wave.mode+" ("+_wave.r+","+_wave.g+","+_wave.b+") @ ("+_wave.u+","+_wave.v+") alpha="+_wave.a+" scale="+_wave.scale);			// motion vector properties			_shader.motionVectors(m[Milk.MV_X],			 	 m[Milk.MV_Y],			 	 m[Milk.MV_R],			 	 m[Milk.MV_G],			 	 m[Milk.MV_B],			 	 m[Milk.MV_A]);			_shader.mv_l = Math.min(m[Milk.MV_L],10);			_shader.mv_dx = m[Milk.MV_DX];			_shader.mv_dy = m[Milk.MV_DY];						if (_monitor.visible) {				//trace("monitor="+m[Milk.MONITOR]);				_monitor.track(m[Milk.MONITOR]);			}			// Update our shaders			copyPixelVars(_shader.memory);			copyQVars(_shader.memory);			if (_cShapes) prepareShapeShaders();		}				private function prepareShapeShaders():void {			// TODO optimize me			for (var i:int=0; i < _cShapes.length; i++) {				var sm:Array = _cShapes[i].memory;				copyPixelVars(sm);				copyTVars(sm);			}		}		private function copyPixelVars(to:Array):void {			var from:Array=_cFrame.memory;			var start:Number=Milk.PIXEL_START;			var end:Number=Milk.PIXEL_END;			// TODO I don't think we need ALL of these			// TODO and we might even need more, like custom values			//			for (var i:uint; i <= end; i++) {				to[i]=from[i];			}		}				private function copyQVars(to:Array):void {			var from:Array=_cFrame.memory;			var start:Number=Milk.Q1;			var end:Number=Milk.Q9;						for (var i:uint; i <= end; i++) {				to[i]=from[i];			}		}				private function copyTVars(to:Array):void {			var from:Array=_cFrame.memory;			var start:Number=Milk.T1;			var end:Number=Milk.T8;			for (var i:uint; i <= end; i++) {				to[i]=from[i];			}		}				protected function restoreFrameDefaults():void {			_cFrame.clear();			for (var key:String in _frameConfig) {				_cFrame.store(key, _frameConfig[key]);				//trace("Restoring "+key+" to "+_frameConfig[key]);			}			for (var i:uint=0; i < _presets.length; i++) {				var varName:String=_presets[i][0];				var presetName:String=_presets[i][1].toLowerCase();				_cFrame.store(presetName,_cFrame.lookup(varName));			}			_frameNum=0;		}		private function preset(varName:String, presetName:String):void {			_cFrame.store(varName, getPreset(presetName.toLowerCase()));		}		//		// Format is ['local variable', 'preset name']		//		// Why he does this, I don't know.		//		protected var _presets:Array = 		[['gamma','fGammaAdj'],		 ['decay','fDecay'],		 ['ve_alpha','fVideoEchoAlpha'],		 ['ve_zoom','fVideoEchoZoom'],		 ['ve_orient','nVideoEchoOrientation'],		 ['wave_mode','nWaveMode'],		 ['additive','bAdditiveWaves'],		 ['max_color','bMaximizeWaveColor'],		 ['wrap','bTexWrap'],		 ['dark_center','bDarkenCenter'],		 ['mv_y','nMotionVectorsY'],		 ['mv_x','nMotionVectorsX'],		 ['brighten','bBrighten'],		 ['darken','bDarken'],		 ['invert','bInvert'],		 ['solarize','bSolarize'],		 ['wave_a','fWaveAlpha'],		 ['wave_dots','bwavedots'],		 ['wave_thick','bwavethick'],		 ['wrap','btexwrap'],		 ['wave_scale','fWaveScale'],		 ['wave_smooth','fWaveSmoothing'],		 ['wave_mystery','fWaveParam'],		 ['wave_alpha_start','fModWaveAlphaStart'],		 ['wave_alpha_end','fModWaveAlphaEnd'],		 ['warp_speed','fWarpAnimSpeed'],		 ['warp_scale','fWarpScale'],		 ['zoom_exp','fZoomExponent'],		 ['shader','fShader']		 ];		private function bool(name:String):Boolean {			var val:Number=_cFrame.lookup(name.toLowerCase());			if (isNaN(val)) {				return false;			} else {				return (val != 0);			}		}		private function getPreset(name:String):Number {			var val:Number=_cFrame.lookup(name.toLowerCase());			if (isNaN(val)) {				trace("Defaulting "+name+" in frame");				return _frameConfig[name];			} else {				//trace("Preset "+name+" changed to "+val);				return val;			}		}		protected function initializeFrameUsingPresetValues():void {			var len:int=_presets.length;			for (var i:int=0; i < len; i++) {				var p:Array=_presets[i];				preset(p[0],p[1]);			}			_ma.wave_scale=getPreset('wave_scale');			_ma.wave_smooth=getPreset('wave_smooth');			_frame.additive=bool('badditivewaves');			_frame.echo=bool('ve_alpha');			_frame.echoAlpha=getPreset('ve_alpha');			_frame.echoOrient=getPreset('ve_orient');			_frame.echoZoom=getPreset('ve_zoom');			_frame.solarize=bool('solarize');			_frame.lighten=bool('brighten');			_frame.darken=bool('darken');			_frame.decay=getPreset('decay');			_wave.thick=bool('bwavethick')?4:0;			_wave.dots=bool('bwavedots');			_wave.brightColors=bool('bmaximizewavecolor');			_wave.a=getPreset('wave_a');			_wave.mystery=getPreset('wave_mystery');			_useMotionVectors=bool('bmotionvectorson');			_modWaveAlphaByVolume=bool('bmodwavealphabyvolume');			if (_modWaveAlphaByVolume) {				_aStart = getPreset('wave_alpha_start');				_aEnd = getPreset('wave_alpha_end');			}		}	}}