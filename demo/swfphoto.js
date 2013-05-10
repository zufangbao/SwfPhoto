/**
 * 摄像头拍照上传
 * byshome@gmail.com
 * http://www.zufangbao.com
 * 2013-05-10
 */
var SWFPhoto;
if (SWFPhoto == undefined) {
	SWFPhoto = function (settings) {
		this.initSWFPhoto(settings);
	};
}
SWFPhoto.prototype.initSWFPhoto = function (settings) {
	try {
		this.settings = settings;
		this.movieName = "SWFPhoto_" + SWFPhoto.movieCount++;
		this.movieElement = null;
		// Setup global control tracking
		SWFPhoto.instances[this.movieName] = this;
		// Load the settings.  Load the Flash movie.
		this.initSettings();
		this.loadFlash();
	} catch (ex) {
		delete SWFPhoto.instances[this.movieName];
		throw ex;
	}
};
/* *************** */
/* Static Members  */
/* *************** */
SWFPhoto.instances = {};
SWFPhoto.movieCount = 0;
SWFPhoto.version = "1.0.0";
/* ******************** */
/* Instance Members  */
/* ******************** */
// Private: initSettings ensures that all the
// settings are set, getting a default value if one was not assigned.
SWFPhoto.prototype.initSettings = function () {
	this.ensureDefault = function (settingName, defaultValue) {
		this.settings[settingName] = (this.settings[settingName] == undefined) ? defaultValue : this.settings[settingName];
	};
	this.ensureDefault("width", 480);
	this.ensureDefault("height", 320);
	this.ensureDefault("noCameraText", "");
	// No camera text
	this.ensureDefault("noCameraText", "");
	this.ensureDefault("noCameraTextSize", 0);
	// Upload backend settings
	this.ensureDefault("uploadUrl", "");
	this.ensureDefault("fileFieldName", "file");
	// ProgressBar
	this.ensureDefault("progressWidth", 0);//default 80%
	this.ensureDefault("progressHeight", 0);//default 18

	// Flash Settings
	this.ensureDefault("flash_url", "swfphoto.swf");
	this.ensureDefault("prevent_swf_caching", true);
	// Event Handlers
	this.ensureDefault("noCamera_handler", null);
	this.ensureDefault("snapped_handler", null);
	this.ensureDefault("resetted_handler", null);
	this.ensureDefault("uploadBegin_handler", null);
	this.ensureDefault("uploadProgress_handler", null);
	this.ensureDefault("uploadError_handler", null);
	this.ensureDefault("uploadSuccess_handler", null);
	
	// Update the flash url if needed
	if (!!this.settings.prevent_swf_caching) {
		this.settings.flash_url = this.settings.flash_url + (this.settings.flash_url.indexOf("?") < 0 ? "?" : "&") + "preventswfcaching=" + new Date().getTime();
	}
	delete this.ensureDefault;
};

// Private: loadFlash replaces the button_placeholder element with the flash movie.
SWFPhoto.prototype.loadFlash = function () {
	var targetElement, tempParent;
	// Make sure an element with the ID we are going to use doesn't already exist
	if (document.getElementById(this.movieName) !== null) {
		throw "ID " + this.movieName + " is already in use. The Flash Object could not be added";
	}

	// Get the element where we will be placing the flash movie
	targetElement = document.getElementById(this.settings.placeholder_id) || this.settings.placeholder;
	if (targetElement == undefined) {
		throw "Could not find the placeholder element: " + this.settings.placeholder_id;
	}
	// Append the container and load the flash
	tempParent = document.createElement("div");
	tempParent.innerHTML = this.getFlashHTML();	// Using innerHTML is non-standard but the only sensible way to dynamically add Flash in IE (and maybe other browsers)
	targetElement.parentNode.replaceChild(tempParent.firstChild, targetElement);

	// Fix IE Flash/Form bug
	if (window[this.movieName] == undefined) {
		window[this.movieName] = this.getMovieElement();
	}
};

// Private: getFlashHTML generates the object tag needed to embed the flash in to the document
SWFPhoto.prototype.getFlashHTML = function () {
	// Flash Satay object syntax: http://www.alistapart.com/articles/flashsatay
	return ['<object id="', this.movieName, '" type="application/x-shockwave-flash" data="', this.settings.flash_url, '" width="', this.settings.width, '" height="', this.settings.height, '" class="SWFPhoto">',
				'<param name="wmode" value="window" />',
				'<param name="movie" value="', this.settings.flash_url, '" />',
				'<param name="quality" value="high" />',
				'<param name="menu" value="false" />',
				'<param name="allowScriptAccess" value="always" />',
				'<param name="flashvars" value="' + this.getFlashVars() + '" />',
				'</object>'].join("");
};

// Private: getFlashVars builds the parameter string that will be passed
// to flash in the flashvars param.
SWFPhoto.prototype.getFlashVars = function () {
	// Build the parameter string
	return ["movieName=", encodeURIComponent(this.movieName),
			"&amp;noCameraText=", encodeURIComponent(this.settings.noCameraText),
			"&amp;noCameraTextSize=", encodeURIComponent(this.settings.noCameraTextSize),
			"&amp;uploadUrl=", encodeURIComponent(this.settings.uploadUrl),
			"&amp;fileFieldName=", encodeURIComponent(this.settings.fileFieldName),
			"&amp;progressWidth=", encodeURIComponent(this.settings.progressWidth),
			"&amp;progressHeight=", encodeURIComponent(this.settings.progressHeight)
		].join("");
};

// Public: getMovieElement retrieves the DOM reference to the Flash element added by SWFPhoto
// The element is cached after the first lookup
SWFPhoto.prototype.getMovieElement = function () {
	if (this.movieElement == undefined) {
		this.movieElement = document.getElementById(this.movieName);
	}

	if (this.movieElement === null) {
		throw "Could not find Flash element";
	}
	
	return this.movieElement;
};
/* Note: addSetting and getSetting are no longer used by SWFPhoto but are included
	the maintain v2 API compatibility
*/
// Public: (Deprecated) addSetting adds a setting value. If the value given is undefined or null then the default_value is used.
SWFPhoto.prototype.addSetting = function (name, value, default_value) {
    if (value == undefined) {
        return (this.settings[name] = default_value);
    } else {
        return (this.settings[name] = value);
	}
};

// Public: (Deprecated) getSetting gets a setting. Returns an empty string if the setting was not found.
SWFPhoto.prototype.getSetting = function (name) {
    if (this.settings[name] != undefined) {
        return this.settings[name];
	}
    return "";
};

// Private: callFlash handles function calls made to the Flash element.
// Calls are made with a setTimeout for some functions to work around
// bugs in the ExternalInterface library.
SWFPhoto.prototype.callFlash = function (functionName, argumentArray) {
	argumentArray = argumentArray || [];
	
	var movieElement = this.getMovieElement();
	var returnValue, returnString;

	// Flash's method if calling ExternalInterface methods (code adapted from MooTools).
	try {
		returnString = movieElement.CallFunction('<invoke name="' + functionName + '" returntype="javascript">' + __flash__argumentsToXML(argumentArray, 0) + '</invoke>');
		returnValue = eval(returnString);
	} catch (ex) {
		throw "Call to " + functionName + " failed";
	}
	
	// Unescape file post param values
	if (returnValue != undefined && typeof returnValue.post === "object") {
		returnValue = this.unescapeFilePostParams(returnValue);
	}

	return returnValue;
};

/* *****************************
	-- Flash control methods --
	Your UI should use these
	to operate SWFPhoto
   ***************************** */
/**
 * 执行拍照
 */
SWFPhoto.prototype.doSnap = function () {
	this.callFlash("doSnap");
};
/**
 * 重置为摄像状态
 */
SWFPhoto.prototype.resetCamera = function () {
	this.callFlash("resetCamera");
};
/**
 * 执行上传照片
 */
SWFPhoto.prototype.doUpload = function () {
	this.callFlash("doUpload");
};
// Private: This event is called by Flash when it has finished loading. Don't modify this.
// Use the SWFPhoto_loaded_handler event setting to execute custom code when SWFPhoto has loaded.
SWFPhoto.prototype.flashReady = function () {
	// Check that the movie element is loaded correctly with its ExternalInterface methods defined
	var movieElement = this.getMovieElement();

	if (!movieElement) {
		this.debug("Flash called back ready but the flash movie can't be found.");
		return;
	}

	this.cleanUp(movieElement);
};

// Private: removes Flash added fuctions to the DOM node to prevent memory leaks in IE.
// This function is called by Flash each time the ExternalInterface functions are created.
SWFPhoto.prototype.cleanUp = function (movieElement) {
	// Pro-actively unhook all the Flash functions
	try {
		if (this.movieElement && typeof(movieElement.CallFunction) === "unknown") { // We only want to do this in IE
			this.debug("Removing Flash functions hooks (this should only run in IE and should prevent memory leaks)");
			for (var key in movieElement) {
				try {
					if (typeof(movieElement[key]) === "function") {
						movieElement[key] = null;
					}
				} catch (ex) {
				}
			}
		}
	} catch (ex1) {
	
	}

	// Fix Flashes own cleanup code so if the SWFMovie was removed from the page
	// it doesn't display errors.
	window["__flash__removeCallback"] = function (instance, name) {
		try {
			if (instance) {
				instance[name] = null;
			}
		} catch (flashEx) {
		
		}
	};

};
/**没有摄像头通知*/
SWFPhoto.prototype.noCamera = function () {
	if (typeof this.settings.noCamera_handler === "function") {
		this.settings.noCamera_handler();
	}
};
/**拍照完成*/
SWFPhoto.prototype.snapped = function () {
	if (typeof this.settings.snapped_handler === "function") {
		this.settings.snapped_handler();
	}
};
/**重置为拍照状态*/
SWFPhoto.prototype.resetted = function () {
	if (typeof this.settings.resetted_handler === "function") {
		this.settings.resetted_handler();
	}
};
/**开始上传照片*/
SWFPhoto.prototype.uploadBegin = function () {
	if (typeof this.settings.uploadBegin_handler === "function") {
		this.settings.uploadBegin_handler();
	}
};
/**上传照片进度*/
SWFPhoto.prototype.uploadProgress = function (bytesLoaded, bytesTotal) {
	if (typeof this.settings.uploadProgress_handler === "function") {
		this.settings.uploadProgress_handler(bytesLoaded, bytesTotal);
	}
};
/**上传出错*/
SWFPhoto.prototype.uploadError = function (errorCode, message) {
	if (typeof this.settings.uploadError_handler === "function") {
		this.settings.uploadError_handler(errorCode, message);
	}
};
/**上传成功*/
SWFPhoto.prototype.uploadSuccess = function (serverData) {
	if (typeof this.settings.uploadSuccess_handler === "function") {
		this.settings.uploadSuccess_handler(serverData);
	}
};