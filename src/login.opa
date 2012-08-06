/*************************************************************************
 *	Mahjong: An html5 mahjong game built with opa. 
 *  Copyright (C) 2012
 *  Author: winbomb
 *  Email:  li.wenbo@whu.edu.cn
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 ************************************************************************/
package mahjong
import stdlib.web.client

/**
* 玩家的定义
*/
type Player.t = {
	string name,                   //用户名
	int idx, 	                   //坐标（0-3）
//	bool is_ready,                 //是否准备好
	bool is_bot,				   //是否是机器人
	Player.status status,          //链路状态 
	int coins,                     //积分
} 

type Player.status = {online}
				  or {offline}
				  or {quit}

type Login.user = {unlogged} or {Player.t user};

state = UserContext.make({unlogged})

function get_user(){
	UserContext.execute(identity,state);
}

function set_user(new_user){
	UserContext.change_or_destroy(function(_){some(new_user)},state);
}

function logout(){
	UserContext.remove(state)
}

function is_logged_in(){
	match(get_user()){
		case {unlogged}: {false}
		case {user:_}:   {true}
	}
}

A = function(user_compat){
	"U"
}



module Login {
	
	function get_agent(user_compat){
		match(user_compat.environment){
			case { X11 }: 			"X11"
			case { Windows }: 		"Windows"
			case { Macintosh }: 	"Mac"
			case { iPhone }:		"iPhone"
			case { Symbian }:		"Symbian"
			case { Unidentified }: 	"Unknown"
		}
	}

	function get_render(user_compat){
		match(user_compat.renderer){
			case {Bot:_}: 				"bot"
			case {Gecko:_}: 			"Gecko"
			case {Trident:_}: 			"Trident"
			case {Webkit:_,variant:_}: 	"Webkit"
			case {Nokia:_}: 			"Nokia"
			case {Presto:_}:			"Presto"
			case {Unidentified}: 		"Other"
		}
	}

	function attempt_login(){
	    name = Dom.get_value(#username);
		if(not(String.is_empty(name))){
			user = {~name, idx: -1, is_bot: {false}, status: {online}, coins: DEFAULT_COINS};
			set_cookie("login_name",name);	
			
			UserContext.change(function(_){{user:user}},state);
			Client.goto("/hall");
		}
	}
	
	client function page_ready(){
		login_name = get_cookie("login_name");
		if(not(String.is_empty(login_name))){
			Dom.set_value(#username,login_name);
		}
		jlog("width = {Client.width()}, height = {Client.height()}");
	}

	function login_view(){
		/** r = Resource.styled_page("China Mahjong", ["/resources/main.css"],
			<>
			<div id="container" onready={function(_){page_ready()}}>
				<div id="content">
					<div id=#login_box>
						<h1> Login </h1>
						<input id=#username type="text" class="input-xlarge" placeholder="Enter a nickname"
						 	   onnewline={function(_){attempt_login()}}/>
						<button class="btn btn-primary btn-large" style="margin-top:10px" onclick={function(_){attempt_login()}}>Play</button>
						<hr style="margin-bottom:5px">
						<p>Note: This game need HTML5 canvas support, please use IE9+, Firefox4+, Chrome10+, Opera11+, Safari5+</p>
						<div style="padding:0px 5px">
							<button class="btn btn-info" style="float:left;width:60px;"
							onclick={function(_){Tutor.show_tutor()}}>Tutorial</button>
							<button class="btn btn-info" style="width:120px">Add to Chrome</button>
							<a class="btn btn-info" style="float:right;width:105px;" 
								href="https://github.com/winbomb/mahjong" target="_blank">Fork on Github</a>
						</div>
    	    		</div>
				</div>
				<div id="footer">
					<p>Build with <a target="_blank" href="http://www.opalang.org">Opa</a></p>
					<p>Any Feedback, please mail to: <a href="mailto:li.wenbo@whu.edu.cn">li.wenbo@whu.edu.cn</a></p>
				</div>
			</div>			
			</>
        ); */
		
		Resource.full_page("China Mahjong",
			<>
			<div id="container" onready={function(_){page_ready()}}>
				<div id="content">
					<div id=#login_box>
						<h1> Login </h1>
						<input id=#username type="text" class="input-xlarge" placeholder="Enter a nickname"
						 	   onnewline={function(_){attempt_login()}}/>
						<button class="btn btn-primary btn-large" style="margin-top:10px" onclick={function(_){attempt_login()}}>Play</button>
						<hr style="margin-bottom:5px">
						<p>Note: This game need HTML5 canvas support, please use IE9+, Firefox4+, Chrome10+, Opera11+, Safari5+</p>
						<div style="padding:0px 5px">
							<button class="btn btn-info" style="float:left;width:60px;"
							onclick={function(_){Tutor.show_tutor()}}>Tutorial</button>
							<button class="btn btn-info" style="width:120px">Add to Chrome</button>
							<a class="btn btn-info" style="float:right;width:105px;" 
								href="https://github.com/winbomb/mahjong" target="_blank">Fork on Github</a>
						</div>
    	    		</div>
				</div>
				<div id="footer">
					<p>Build with <a target="_blank" href="http://www.opalang.org">Opa</a></p>
					<p>Any Feedback, please mail to: <a href="mailto:li.wenbo@whu.edu.cn">li.wenbo@whu.edu.cn</a></p>
				</div>
			</div>
			</>,
			<>
			<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
			<link rel="stylesheet" type="text/css" href="/resources/main.css">
			</>,
			{success},[]
		);
	}
}
