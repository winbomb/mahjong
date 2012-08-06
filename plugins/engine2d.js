##opa-type list('a)
##opa-type Game.obj
##extern-type Image.image

var IMG_CACHE = {}   //图像的缓存
var AUD_CACHE = {}   //声音的缓存

var game;
##register set_game: opa[Game.obj] -> void
##args(gm)
{
	game = gm; 
}

##register get_game: -> opa[Game.obj]
##args()
{
	return game;
}

##register preload: opa[list(string)],opa[list(string)],( -> void) -> void
##args(imgIdents,audIdents,callback)
{
   AUD_CACHE = {};
   var images = list2js(imgIdents);
   var audios = list2js(audIdents);
   var countLoaded = 0;
   var countTotal = 0; 
	
   function incrementLoaded() {
      countLoaded++;
	  info = document.getElementById("loading_info");
	  if(!!info){
	  	info.innerHTML = "loading game resource... [ "+countLoaded+" / "+countTotal+" ]"
	  }
	  if (countLoaded >= countTotal) {
		callback();
      }
   }

   function getProgress() {
      return countTotal > 0 ? countLoaded / countTotal : 1;
   }

   function imgSuccessHandler() {
	  IMG_CACHE[this.key] = this;
      incrementLoaded();
   }
	
   function audSuccessHandler() {
	  //不知到为什么Firefox会触发两次canplay事件，
	  //如果不做判断，会出现countLoaded大于countTotal的事情。
	  if(!AUD_CACHE[this.key]){
		  AUD_CACHE[this.key] = this;
	  	  incrementLoaded();
	  }
   }

   function errorHandler() {
	  incrementLoaded();
      throw new Error('Error loading ' + this.src);
   }
	
    for (var i=0;i<images.length;i++) {
	  var key = images[i]
	  if (key.indexOf('png') == -1 &&
          key.indexOf('jpg') == -1 &&
          key.indexOf('gif') == -1) {
          continue;
      }
	 
	  var img = new Image();
	  countTotal++;
      img.addEventListener('load', imgSuccessHandler, true);
      img.addEventListener('error', errorHandler, true);
      img.src = key;
      img.key = key;
   }	
	
   if(window.HTMLAudioElement){
   		try{
			var audio = document.createElement("audio");
			if(audio != null && audio.canPlayType && audio.canPlayType("audio/wav")){
				for( var i=0;i<audios.length;i++){
	  				var key = audios[i]
	  				if(key.indexOf('wav') == -1) continue;
	  
					var audio = new Audio();
	  				audio.addEventListener('canplaythrough', audSuccessHandler, true);
      				audio.addEventListener('error', errorHandler, true);
      				audio.src = key;
      				audio.key = key;
	  				audio.load();
					
					countTotal++;
   				}
			}
   		}catch(e){
			alert("Error: "+e);
			window.console.error("Error"+e);
   		}
   }
}

##register get: string -> Image.image
##args(key)
{
	var img = IMG_CACHE[key];
    if (!img) {
		throw new Error('Missing "' + key + '", preload() all images before trying to load them.');
    }
    return img;
}

var counter;

##register start_timer:  -> void
##args()
{
	var ctx = document.getElementById("gmcanvas").getContext("2d");
	counter = 11;	
	var loop = function(){
		return function(){
			if(counter > 0){
				counter = counter - 1;
				ctx.clearRect(330+28,237+28,24,24);
				ctx.restore();
				ctx.save(ctx);
				ctx.fillStyle = "#efea3a";
				ctx.fillRect(330+28,237+28,24,24);
				ctx.fillStyle = "red";
				ctx.font = "normal bold 24px serif";
				ctx.textAlign = "center";
				ctx.textBaseline = "middle";
				ctx.fillText(counter,370,277);
				ctx.restore();

				window.setTimeout(arguments.callee,1000);
			}
		}
	}
	loop.call(this)();
}

##register stop_timer: -> void
##args()
{
	counter = 0;
}

##register show_menu: int -> void
##args(opt_flag)
{
	var ctx = document.getElementById("gmcanvas").getContext("2d");
	var arr = [8,4,2,1]
	var arr2 = new Array(4);
	for(var i = 0; i < arr.length; i++){
		if(opt_flag >= arr[i]){
			arr2[i] = true;
			opt_flag = opt_flag - arr[i];
		}else {
			arr2[i] = false;
		}
	}
	
	/** 这是带动画的方式，现在先使用不带动画的
	var frame = 0;
	var img = get_img("menu_bar.png");
	var loop = function(){
		return function(){
			if(frame < 25){
				ctx.clearRect(540,481,210,50);
				ctx.restore();
				for(var i = 0,x = 730-8*frame; i < arr2.length; i++){
					if(arr2[i]){
						ctx.drawImage(img,50*i,0,50,50,x+50*i,481,50,50);
					}else{
						ctx.drawImage(img,50*i,50,50,50,x+50*i,481,50,50);
					}					
				}
				frame++;

				window.setTimeout(arguments.callee,40);
			}
		}
	}
	loop.call(this)(); */
	
	var img = get_img("menu_bar.png");
	for(var i=0, x=490; i<arr2.length; i++){
		if(arr2[i]){
			ctx.drawImage(img,60*i,0,60,60,x+60*i,475,60,60);
		}else{
			ctx.drawImage(img,60*i,60,60,60,x+60*i,475,60,60);
		}
	}
}

##register hide_menu: -> void
##args()
{
	var ctx = document.getElementById("gmcanvas").getContext("2d");
	ctx.clearRect(540,481,210,50);
}

var get_img = function(key){
	var img = IMG_CACHE["/resources/"+key];
    if (!img) {
		throw new Error('Missing "' + key + '", preload() all images before trying to load them.');
    }
    return img;
}

##register play_sound: string -> void
##args(key)
{
	var snd = AUD_CACHE[key];
	if(snd){
		//注：如果不加snd.reload()，chrome好像无法重新播放声音，即只播放一次
		//之后再不会播放，不知道啥原因，自从升级了chrome(18onlinux,21onwindows)
		//就有这个问题。但不晓得这样每次播放都reload会不会带来系统负担。
		//关注此问题！
		snd.load();
		snd.play();
	}	
}

//两个参数，一个是cookie的名子，一个是值
##register set_cookie: string,string -> void
##args(name,value)
{
    var Days = 30; //此 cookie 将被保存 30 天
    var exp  = new Date();    //new Date("December 31, 9998");
    exp.setTime(exp.getTime() + Days*24*60*60*1000);
    document.cookie = name + "="+ escape (value) + ";expires=" + exp.toGMTString();
}

//取cookies函数    
##register get_cookie: string -> string
##args(name)    
{
    var arr = document.cookie.match(new RegExp("(^| )"+name+"=([^;]*)(;|$)"));
    if(arr != null) return unescape(arr[2]);
	return "";
}

//删除cookie
##register del_cookie: string -> void
##args(name)
{
    var exp = new Date();
    exp.setTime(exp.getTime() - 1);
    var cval=getCookie(name);
    if(cval!=null) document.cookie= name + "="+cval+";expires="+exp.toGMTString();
}
