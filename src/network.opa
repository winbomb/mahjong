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

/** 弃牌消息 */ 
type Discard.msg = {
		int index,
		Card.t card
}

type Game.msg = {
	string 			id,                    	//游戏id 
	int 			st,		             	//游戏状态 status
	int 			ct,		               	//当前玩家 curr_turn
	int				rd,						//第几局 round
	int				dl,						//庄家	 dealer
	int				rf,						//玩家准备好标志 ready_flags
	option(Card.t) 	cc,		                //当前牌面上的牌 curr_card
	llarray(option(Player.t)) 	pls,	   	//玩家列表 players
	llarray(Deck.t) 			dks,		//所有玩家牌面 decks
	llarray(Discard.t) 			dcs,		//所有玩家的弃牌 discards
	llarray(string) 			pf,			//所有玩家的牌堆情况 pile_info
}

/** 游戏消息 */
type Game_msg.t =  {Game.msg GAME_REFRESH}
				or {Game.msg GAME_RESTART}
				or {Game.msg GAME_START} 
				or {Game.msg PLAYER_CHANGE}
				or {Discard.msg DISCARD_CARD}
				or {Game.msg NEXT_TURN}
				or {Game.msg NEXT_ACTION,Action.t ACT}     //下一个动作，玩家碰/杠了之后 
				or {option(Result.t) SHOW_RESULT}     //显示结算
				or {Player.t OFFLINE}         //用户离线消息
				or {int PLAYER_READY}			//玩家准备好
				or {list(int) HOO}             //玩家胡牌消息

/** 聊天消息 */
type Chat_msg.t = {
	string author,       //作者
	string text,         //消息
}

//The global network
exposed @async Network.network(list(GameInfo.t)) hall =  Network.cloud("room");

module GameNetwork {

	private server networks = ServerReference.create(stringmap(Network.network(Game_msg.t)) StringMap_empty);

	function Network.network(Game_msg.t) memo(string game_id){    
		map = ServerReference.get(networks);
		match(Map.get(game_id,map)){
			case {some: channel} : channel
			case {none} : {
				channel = Network.empty()
				ServerReference.set(networks, StringMap_add(game_id, channel, map))
				channel
			}
		}
    }
}

module ChatNetwork {

	private server networks = ServerReference.create(stringmap(Network.network(Chat_msg.t)) StringMap_empty);
	
	function Network.network(Chat_msg.t) memo(string game_id){ 
		game_id = game_id ^ "_chat"
		map = ServerReference.get(networks);
		match(Map.get(game_id,map)){
			case {some: channel} : channel
			case {none} : {
				channel = Network.empty()
				ServerReference.set(networks, StringMap_add(game_id, channel, map))
				channel
			}
		}
    }	
}
