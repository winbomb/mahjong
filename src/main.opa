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

function game_view(game_id,need_bot){
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
						game = if(need_bot) Game.add_bots(game) else game;
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
        case {path:["game",id|_] ...}    	: game_view(id,{false});
		case {path:["gamex",id|_] ...}    	: game_view(id,{true}); 
        case {path:["how_to_play.html"] ...}: @static_resource("resources/how_to_play.html");
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
 }
