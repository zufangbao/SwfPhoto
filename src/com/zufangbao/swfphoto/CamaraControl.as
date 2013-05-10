package com.zufangbao.swfphoto 
{	
	import fl.controls.ProgressBar;
	import fl.controls.ProgressBarMode;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.external.ExternalInterface;
	import flash.text.TextField;
	import flash.text.TextFormatAlign;
	import flash.text.TextFormat;
	import flash.text.TextFieldAutoSize;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.utils.ByteArray;
	import flash.system.Security;
	import flash.events.*;
	
	import com.adobe.images.JPGEncoder;
	import com.zufangbao.core.net.UploadPostHelper;
	
	/**
	 * 摄像头控制
	 * byshome@gmail.com
	 * http://www.zufangbao.com
	 * 2013-05-10
	 */
	[SWF(backgroundColor="0x000")]
	public class CamaraControl extends Sprite
	{
		/**版本号*/
		private const version:String = "CamaraControl 1.0.0";
		/**当前控件名称*/
		private var movieName:String;
		/**是否有摄像头*/
		private var hasCamera:Boolean = false;
		/**没有摄像头的提示标签*/
		private var textNoCamera:TextField;
		/**没有摄像头的提示内容*/
		private var noCameraText:String = "没有找到摄像头，\n请检查摄像头是否已正确连接";
		/**没有摄像头的提示内容文本大小*/
		private var noCameraTextSize:Number = 12;
		/**摄像头*/
		private var camera:Camera;
		/**视频*/
		private var video:Video;
		/**拍照后的数据*/
		private var photoData:BitmapData = null;
		/**拍照后的图片*/
		private var photoImage:Bitmap = null;
		/**上传组件*/
		private var uploadLoader:URLLoader = null;
		/**是否正在上传标记*/
		private var doUploading:Boolean = false;
		/**上传图片的URL*/
		private var uploadUrl:String;
		/**上传文件字段名称*/
		private var fileFieldName:String;
		private var progressBarWidth:Number;
		private var progressBarHeight:Number;
		/**上传文件的进度条*/
		private var progressBar:ProgressBar = null;
		/**上传文件的进度条标签*/
		private var progressLabel:TextField = null;
		/**没有摄像头通知事件*/
		private var noCamera_Callback:String;
		/**生成快照通知事件*/
		private var snapped_Callback:String;
		/**重置为摄像模式通知事件*/
		private var resetted_Callback:String;
		/**开始上传通知事件*/
		private var uploadBegin_Callback:String;
		/**上传进度通知事件*/
		private var uploadProgress_Callback:String;
		/**上传过程出错通知事件*/
		private var uploadError_Callback:String;
		/**上传成功通知事件*/
		private var uploadSuccess_Callback:String;
		/**上传的照片大小*/
		private var photoByteSize:Number = 0;
		public function CamaraControl()
		{
			//如果不支持下述组件，不执行
			if (!flash.net.URLRequest || !flash.external.ExternalInterface || !flash.external.ExternalInterface.available) {
				return;
			}
			
			this.movieName = root.loaderInfo.parameters.movieName;
			this.initEventCallback();
			
			//取得摄像头数
			this.hasCamera = Camera.names.length > 0;
			if (!this.hasCamera) {//没有摄像头
				ExternalCall.noCamera(this.noCamera_Callback);
			}
			Security.allowDomain("*");//允许上传到任何的域名下
			//不显示flash script is running slowly错误
			var counter:Number = 0;
			root.addEventListener(Event.ENTER_FRAME, function ():void { if (++counter > 100) counter = 0; } );
			
			this.stage.align = StageAlign.TOP_LEFT;
			this.stage.scaleMode = StageScaleMode.NO_SCALE;
			
			//没有摄像头的时候显示无摄像头
			this.initNoCameraText();
			//初始化摄像头
			this.initCamera();
			//初始化上传内容
			this.initUpload();
		}
		/**
		 * 初始化事件回调通知
		 */
		private function initEventCallback():void {
			//主要回调
			this.noCamera_Callback = "SWFPhoto.instances[\"" + this.movieName + "\"].noCamera";
			this.snapped_Callback = "SWFPhoto.instances[\"" + this.movieName + "\"].snapped";
			this.resetted_Callback = "SWFPhoto.instances[\"" + this.movieName + "\"].resetted";
			this.uploadBegin_Callback = "SWFPhoto.instances[\"" + this.movieName + "\"].uploadBegin";
			this.uploadProgress_Callback = "SWFPhoto.instances[\"" + this.movieName + "\"].uploadProgress";
			this.uploadError_Callback = "SWFPhoto.instances[\"" + this.movieName + "\"].uploadError";
			this.uploadSuccess_Callback = "SWFPhoto.instances[\"" + this.movieName + "\"].uploadSuccess";
			//调用
			ExternalInterface.addCallback("doSnap", this.doSnap);
			ExternalInterface.addCallback("resetCamera", this.resetCamera);
			ExternalInterface.addCallback("doUpload", this.doUpload);
		}
		/**
		 * 初始化没有摄像头的时候显示
		 */
		private function initNoCameraText():void {
			if (this.hasCamera) return;//有摄像头，不处理
			this.textNoCamera = new TextField();
			this.textNoCamera.width = this.stage.stageWidth;
			this.textNoCamera.background = true;
			this.textNoCamera.backgroundColor = 0;
			this.textNoCamera.textColor = 0xFFFFFF;
			this.textNoCamera.autoSize = TextFieldAutoSize.CENTER;
			this.stage.addChild(this.textNoCamera);
			//接受传入的参数
			try {
				var text:String = String(root.loaderInfo.parameters.noCameraText);
				if (text != null && text.length > 0 && text != "undefined") {
					this.noCameraText = text;
				}
			} catch (ex:Object) {
			}
			//更新标签
			this.textNoCamera.text = this.noCameraText;
			try {
				var textSize:Number = Number(root.loaderInfo.parameters.noCameraTextSize);
				if (isNaN(textSize) && textSize > 0) {
					this.noCameraTextSize = textSize;
				}
			} catch (ex:Object) {
			}
			//
			var format:TextFormat = new TextFormat();//左右居中
			format.align = TextFormatAlign.CENTER;
			format.size = this.noCameraTextSize;
			this.textNoCamera.setTextFormat(format);
			//纵向居中
			this.textNoCamera.height = this.textNoCamera.textHeight;
			var posY:Number = (this.stage.stageHeight - this.textNoCamera.height) / 2;
			this.textNoCamera.y = posY;
		}
		/**
		 * 初始化摄像头
		 */
		private function initCamera():void {
			if (!this.hasCamera) return;//没有摄像头，不处理
			this.camera = Camera.getCamera();//获取一个摄像头
			this.camera.setMode(this.stage.stageWidth, this.stage.stageHeight, 15, true);
			this.video = new Video(this.stage.stageWidth, this.stage.stageHeight);
			this.video.attachCamera(this.camera);
			this.stage.addChild(this.video);
		}
		/**
		 * 初始化上传
		 */
		private function initUpload():void {
			if (!this.hasCamera) return;//没有摄像头，不处理
			//上传的URL参数
			try {
				var uploadUrl:String = String(root.loaderInfo.parameters.uploadUrl);
				if (uploadUrl != null && uploadUrl.length > 0 && uploadUrl != "undefined") {
					this.uploadUrl = uploadUrl;
				}
			} catch (ex:Object) {
			}
			//上传的文件字段名称
			try {
				var fileFieldName:String = String(root.loaderInfo.parameters.fileFieldName);
				if (fileFieldName != null && fileFieldName.length > 0 && fileFieldName != "undefined") {
					this.fileFieldName = fileFieldName;
				}
			} catch (ex:Object) {
			}
		}
		/**
		 * 生成快照
		 */
		private function doSnap():Boolean {
			if (!this.hasCamera) return false;//没有摄像头，不处理
			if (!this.stage.contains(this.video)) return false;//如果当前已经是拍照状态，不允许重复拍照
			if (this.doUploading) return false;//正在上传的话，不允许拍照
			ExternalCall.snapped(this.snapped_Callback);
			if (this.photoData == null) this.photoData = new BitmapData(this.stage.stageWidth, this.stage.stageHeight, true, 0);
			this.photoData.draw(this.video, null, null, null, null, false);
			this.photoImage = new Bitmap(this.photoData, "auto", false);
			this.stage.removeChild(this.video);
			this.stage.addChild(this.photoImage);
			return true;
		}
		/**
		 * 重置为Vidio状态
		 */
		private function resetCamera():Boolean {
			if (!this.hasCamera) return false;//没有摄像头，不处理
			if (this.doUploading) return false;//正在上传的话，不允许重置
			if (!this.stage.contains(this.photoImage)) return false;
			this.stage.removeChild(this.photoImage);
			if (this.uploadLoader != null) {
				try{
					this.uploadLoader.close();
				}catch (error:Error) {
				}finally {
					this.uploadLoader = null;
				}
			}
			if (this.progressBar != null && this.stage.contains(this.progressBar)){
				this.stage.removeChild(this.progressBar);
				this.progressBar = null;
			}
			if (this.progressLabel != null && this.stage.contains(this.progressLabel)){
				this.stage.removeChild(this.progressLabel);
				this.progressLabel = null;
			}
			this.stage.addChild(this.video);
			ExternalCall.resetted(this.resetted_Callback);
			return true;
		}
		private var errorCode:Number;
		/**执行上传照片*/
		private function doUpload():Boolean {
			if (!this.hasCamera) return false;//没有摄像头，不处理
			if (!this.stage.contains(this.photoImage)) return false;
			if (this.doUploading) return false;//正在上传的话，不允许重复上传
			this.doUploading = true;//表示正在上传
			try{
				//创建上传进度条
				this.createProgressBar();
				//创建上传控制器
				this.createUploadLoader();
			}catch (e:Error) {
				ExternalCall.uploadError(this.uploadError_Callback, e.errorID, e.message);
				return false;
			}
			return true;
		}
		/**
		 * 创建上传进度条
		 */
		private function createProgressBar():void {
			this.progressBarWidth = this.stage.stageWidth * 0.8;
			this.progressBarHeight = 18;
			//进度条宽度高度
			try {
				var progressWidth:Number = Number(root.loaderInfo.parameters.progressWidth);
				var progressHeight:Number = Number(root.loaderInfo.parameters.progressHeight);
				if (!isNaN(progressWidth) && progressWidth > 0 && !isNaN(progressHeight) && progressHeight > 0) {
					this.progressBarWidth = progressWidth;
					this.progressBarHeight = progressHeight;
				}
			} catch (ex:Object) {
			}
			//进度条
			this.progressBar = new ProgressBar();
			this.progressBar.maximum = 100;
			this.stage.addChild(this.progressBar);
			this.progressBar.setSize(this.progressBarWidth, this.progressBarHeight);
			//定位
			this.progressBar.move((this.stage.stageWidth - this.progressBar.width) / 2, (this.stage.stageHeight - this.progressBar.height) / 2);
			//上传中
			this.progressLabel = new TextField();
			this.progressLabel.width = this.progressBarWidth;
			this.progressLabel.text = "上传中0%...";
			this.progressLabel.autoSize = TextFieldAutoSize.CENTER;
			this.stage.addChild(this.progressLabel);
			//纵向居中
			this.progressLabel.height = this.progressLabel.textHeight;
			var posX:Number = (this.stage.stageWidth - this.progressLabel.width) / 2;
			var posY:Number = (this.stage.stageHeight - this.progressLabel.height) / 2;
			this.progressLabel.x = posX;
			this.progressLabel.y = posY;
		}
		/**
		 * 更新进度条
		 */
		private function updateProgressLabel(bytesLoaded:Number, bytesTotal:Number):void {
			var progress:Number = 0;
			if (bytesTotal > 0) {
				progress = bytesLoaded * 100.0 / bytesTotal;
			}
			this.progressLabel.text = "上传中" + progress + "%...";
		}
		/**
		 * 创建上传控制器
		 */
		private function createUploadLoader():void {
			this.uploadLoader = new URLLoader();
			this.uploadLoader.dataFormat = URLLoaderDataFormat.TEXT;
			//添加事件
			this.uploadLoader.addEventListener(ProgressEvent.PROGRESS, this.uploadProgressHandler);
			this.uploadLoader.addEventListener(IOErrorEvent.IO_ERROR, this.uploadIoErrorHandler);
			this.uploadLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.uploadSecurityErrorHandler);
			this.uploadLoader.addEventListener(HTTPStatusEvent.HTTP_STATUS, this.uploadHttpStatusHandler);
			this.uploadLoader.addEventListener(Event.COMPLETE, this.uploadCompleteHandler);
			//图片字节
			var jpgEncoder:JPGEncoder = new JPGEncoder(100);
			var jpgStream:ByteArray = jpgEncoder.encode(this.photoData);
			this.photoByteSize = jpgStream.length;//总长度
			//上传
			var uploadRequest:URLRequest = new URLRequest(this.uploadUrl);
			uploadRequest.requestHeaders.push(new URLRequestHeader ("Content-type", "multipart/form-data; boundary=" + UploadPostHelper.getBoundary()));
			uploadRequest.requestHeaders.push(new URLRequestHeader ("Cache-Control", "no-cache"));
			uploadRequest.method = URLRequestMethod.POST;
			uploadRequest.data = UploadPostHelper.getPostData(this.fileFieldName, "photo.jpg", jpgStream, null);
			this.uploadLoader.load(uploadRequest);
			//绑定进度到进度条
			this.progressBar.source = this.uploadLoader;
		}
		/**
		 * 中断上传
		 */
		private function resetUpload():void {
			this.doUploading = false;//
			try {
				if (this.uploadLoader != null) {
					this.uploadLoader.close();
				}
			}catch (e:Error) {
			}
		}
		/**
		 * 文件上传进度
		 * @param	event
		 */
		private function uploadProgressHandler(event:ProgressEvent):void {
			var bytesLoaded:Number = event.bytesLoaded < 0 ? 0 : event.bytesLoaded;
			var bytesTotal:Number = event.bytesTotal <= 0 ? this.photoByteSize : event.bytesTotal;
			this.updateProgressLabel(bytesLoaded, bytesTotal);
			ExternalCall.uploadProgress(this.uploadProgress_Callback, bytesLoaded, bytesTotal);
		}
		/**
		 * 文件上传IO错误
		 * @param	event
		 */
		private function uploadIoErrorHandler(event:IOErrorEvent):void {
			ExternalCall.uploadError(this.uploadError_Callback, event.errorID, event.text);
			this.resetUpload();
		}
		/**
		 * 文件上传安全错误
		 * @param	event
		 */
		private function uploadSecurityErrorHandler(event:SecurityErrorEvent):void {
			ExternalCall.uploadError(this.uploadError_Callback, event.errorID, event.text);
			this.resetUpload();
		}
		/**
		 * 文件上传状态事件
		 * @param	event
		 */
		private function uploadHttpStatusHandler(event:HTTPStatusEvent):void {
			if (event.status != 200) {
				ExternalCall.uploadError(this.uploadError_Callback, event.status, "服务器返回错误代码" + event.status);
				this.resetUpload();
			}
		}
		/**
		 * 文件上传完成事件
		 * @param	event
		 */
		private function uploadCompleteHandler(event:Event):void {
			this.progressBar.mode = ProgressBarMode.MANUAL;
			this.progressBar.setProgress(this.photoByteSize, this.photoByteSize);
			this.updateProgressLabel(this.photoByteSize, this.photoByteSize);
			ExternalCall.uploadProgress(this.uploadProgress_Callback, this.photoByteSize, this.photoByteSize);
			ExternalCall.uploadSuccess(this.uploadSuccess_Callback, this.uploadLoader.data);
		}
	}
}