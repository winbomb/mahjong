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
	Player.status status,          //链路状态 
	int coins,                     //积分
} 

type Player.status = {online}
				  or {offline}
				  or {quit}

type Login.user = {unlogged} or {Player.t user};

type Access.t = {
	string id,
	string name,
	string time,
	string ip,
	string lang,
	string agent,
	string render
}

database mahjong {
	int /view_count				//访问次数
	int /login_count			//登录次数
	int /game_count				//游戏次数
	list(Access.t) /access_list //访问列表
}

exposed function record_access(access_info){
	/mahjong/login_count++
	/mahjong/access_list <+ {access_info with time: Date.to_string(Date.now())}
}

exposed function increase_view(){
	/mahjong/view_count++
}

module Login {
	state = UserContext.make({unlogged})

	function get_user(){
		UserContext.execute(identity,state);
	}

	function set_user(new_user){
		UserContext.change_or_destroy(function(_){some(new_user)},state);
	}

	function logout(){
		UserContext.change(function(_){{unlogged}},state)
	}

	function is_logged_in(){
		match(get_user()){
			case {unlogged}: {false}
			case {user:_}:   {true}
		}
	}
	
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
			user = {~name, idx: -1, status: {online}, coins: DEFAULT_COINS};
			set_cookie("login_name",name);	
			
			req = Option.get(HttpRequest.get_request());
			ip = IPv4.string_of_ip(HttpRequest.Generic.get_ip(req))
			lang = ServerI18n.request_lang(req)
			user_compat = HttpRequest.Generic.get_user_agent(req)
			
			access_info = {
				id:		Random.string(8),
				name:	name, 
				time:	"",
				ip:		ip,
				lang:	lang,
				agent:  get_agent(user_compat),
				render:	get_render(user_compat)
			}
			record_access(access_info);

			UserContext.change(function(_){{user:user}},state);
			Client.goto("/hall");
		}
	}
	
	client function page_ready(){
		login_name = get_cookie("login_name");
		if(not(String.is_empty(login_name))){
			Dom.set_value(#username,login_name);
		}
		increase_view();
	}

	function login_view(){
		Resource.styled_page("Mahjong", ["/resources/main.css"],
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
						<p>Mahjong Rule: <a href="/how_to_play.html" target="_blank">How to play mahjong</a></p>
    	    		</div>
				</div>
				<div id="footer">
					<p>Build with <a target="_blank" href="http://www.opalang.org">Opa</a></p>
					<p>Any Feedback, please mail to: <a href="mailto:li.wenbo@whu.edu.cn">li.wenbo@whu.edu.cn</a></p>
				</div>
			</div>			
			</>
        )
	}
}
