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

function login_required(  -> resource page){
	match(is_logged_in()){
		case {true}:  page();
		case {false}: Login.login_view();
	}
}

function is_logged_in(){
	match(Login.get_user()){
			case {unlogged}: {false}
			case {user:_}:   {true}
		}
	}


function with_user((Login.user -> 'a) f, 'a otherwise){
	match(Login.get_user()){
		case ~{user}:    f(user);
		case {unlogged}: otherwise;
	}
}

function game_view(game_id){
	match(Login.get_user()){
	case {unlogged}: Login.login_view();
	case {user:player}: {
		match(Game.get(game_id)){
		case {none}: Page.game_list_view();
		case {some:game}: {
			match(Game.assign_place(game,player)){
			case {none}: Page.game_list_view()
			case {some:idx}:{
				match(ThreadContext.get({current}).key){
					case {`client`:c}: {
						player = {player with idx: idx}
						player = {player with status: {online}}
						LowLevelArray.set(game.players,idx,some(player))
						LowLevelArray.set(game.clients,idx,some(c));
						game = {game with change_flag:{true}} |> Game.update(_)
						Game.game_view(game,idx);						
					}
					default: Page.game_list_view()
				}
				
			}}
		}}
	}}
}

function start(url){ 
	match(url) {
		case {path:[] ... }             	: Login.login_view()
        case {path:["login"] ... }      	: Login.login_view()
        case {path:["game",x|_] ...}    	: game_view(x); 
        case {path:["how_to_play.html"] ...}: @static_resource("resources/how_to_play.html");
		case {path:["admin"] ...}			: Main.admin_page()
        case {path:["hall"] ...}        	: login_required(function(){Page.game_list_view()})
        case {path: _ ...}                	: Main.fourOffour()
	}
	
}

Server.start(Server.http,
	[{register: { doctype : { html5 }}},
	 {resources: @static_include_directory("resources")},
	 {dispatch: start}
	]
);

module Main {

	function fourOffour(){
		Resource.styled_page("404", ["style.css"],
    	   <><h1>404</h1></>
    	);
	}

	//这种处理方式似乎不好，应该在查询的时候只查询出需要的结果
	exposed function get_access_list(){
		access_list = /mahjong/access_list
		len = List.length(access_list);
		result = if(len > 200) List.drop(len-200,access_list) else access_list;
		List.rev(result);
	}

	function admin_page(){
		Resource.page("login list",
			<h2>访问次数：{/mahjong/view_count}</h2>
			<h2>登录次数：{/mahjong/login_count}</h2>
			<h2>访问列表：</h2>
			<table border="1px">
				<tr>
					<th>用户ID</th>
					<th>用户名</th>
					<th>登录时间</th>
					<th>IP</th>
					<th>LANG</th>
					<th>AGENT</th>
					<th>Render</th>
				</tr>
				{List.map(function(access){
					<tr>
						<td width="100px"> {access.id} </td>
						<td width="150px"> {access.name}</td>
						<td width="200px"> {access.time}</td>
						<td width="200px"> {access.ip}</td>
						<td width="100px"> {access.lang}</td>
						<td width="100px"> {access.agent}</td>
						<td width="100px"> {access.render}</td>
					</tr>
				},get_access_list())}	
			</table>
		);
	}
 }
