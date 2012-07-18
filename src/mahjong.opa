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

/** 
* 游戏状态的定义 
*/
type Status.t =  {prepare}          //游戏准备
			  or {draw_card}        //起牌
			  or {select_action}    //选择动作
			  or {wait_for_resp}    //等待玩家响应
			  or {game_over}        //如果game.winner == {none}表示流局，否则表示winner胜出 
			  or {show_result}		//展示结算
			  or {unknown}			//未知状态，游戏异常


/** 
* 胡牌计分时的项目  
*/
type Item.t = {
	string name,  //名称
	int point,    //分值
	int n         //数量
}

type Result.t = llarray(list(Item.t))

function encode_status(status){
	match(status){
	case {prepare}: 		0
	case {draw_card}: 		1
	case {select_action}:	2
	case {wait_for_resp}: 	3
	case {game_over}: 		4
	case {show_result}:		5
	case {unknown}: 		99
	}
}

both function decode_status(st_code){
	match(st_code){
	case 0: {prepare}
	case 1: {draw_card}
	case 2: {select_action}
	case 3: {wait_for_resp}
	case 4: {game_over}
	case 5: {show_result}
	case _: {unknown}
	}	
}

/**
*  游戏业务流程的模块 
*/
module Mahjong {

	//预定义的胡牌结果
	ZIMO = {name:"ZM",point:150,n:1} 	//自摸
	HOO = {name:"HOO",point:50,n:1}  	//平胡
	B_ZIMO = {name:"BZM",point:-50,n:1} 	//被自摸
	FANGPAO = {name:"FP",point:-50,n:1} 	//放炮
	S_GANG = {name:"SG",point:50,n:1} 	//明杠
	H_GANG = {name:"HG",point:150,n:1} 	//暗杠
	B_GANG = {name:"BG",point:-50,n:1} 	//被杠

	client function item_to_name(item){
		match(item){
			case "ZM" : "Self-pick"
			case "HOO": "Hoo"
			case "BZM": "Fire"
			case "FP" : "Fire"
			case "SG" : "Soft Kong"
			case "HG" : "Hard Kong"
			case "BG" : "Konged"
			default: "Unknown"
		}
	}
	
	update = Game.update
	
	function with_game(game_id,(Game.t -> void) f){
		match(Game.get(game_id)){
			case {none}: void
			case ~{some}: f(some);
		}
	}

	/**
	* 处理用户的点击事件
	* @pos    点击的坐标
	* @game   游戏对象（Game.obj类型）
	* @return Action.t 要执行的动作
	*/
	client function get_action(pos,game){
		deck = game.deck;
		match(game.status){
			case {prepare}:{
				//准备 
				if(not(test_flag(game.ready_flags,game.idx)) && Button.is_pressed(pos,Render.btn_ready)){
					{set_ready}
				} else {none} 
			} 
			case {select_action}: {
				//选择弃掉的牌
				match(get_clicked_card(deck,pos)){
					case ~{some}: {
						//只有在14张的时候才允许弃牌，否则会出现点击多次，弃掉多张牌的bug
						//（这一点在性能比较好的机器上不会出现，因为在玩家的两次点击之间，响应
						// 已经回来，游戏状态不再是{select_action}，点击无效了）
						card_cnt = List.length(deck.handcards) + List.length(deck.donecards)*3
						if(card_cnt >= 14){
							Render.discard(some);
							{discard:some}
						} else {none} 
					}
					case {none}: {
						//自摸胡牌 
						if(Board.can_hoo_self(deck) && Button.is_pressed(pos,Render.btn_hoo)){
							{hoo}
						}else{
							//杠牌
							if(Board.can_gang_self(deck) && Button.is_pressed(pos,Render.btn_gang)){
								{gang_self}
							}else {none}
						}
					}
				}					
			}
			case {wait_for_resp}: {
				card = Option.get(game.curr_card);
				//碰牌
				if(Board.can_peng(deck,card) && Button.is_pressed(pos,Render.btn_peng)){
					{peng}
				}else{			
					//杠牌
					if(Board.can_gang(deck,card) && Button.is_pressed(pos,Render.btn_gang)){
						{gang}
					}else{
						//胡牌
						if(Board.can_hoo_card(deck,card) && Button.is_pressed(pos,Render.btn_hoo)){
							{hoo}
						}else{
							//放弃
							if(Button.is_pressed(pos,Render.btn_cancel)){
								{no_act}
							}else {none}
						}
					}
				}
			}
			case {show_result}: {
				if(not(game.is_ok) && Button.is_pressed(pos,Render.btn_hide_result)){
					Render.hide_result();
					{set_ok}
				}else{
					if(game.is_ok && not(test_flag(game.ready_flags,game.idx)) 
							&& Button.is_pressed(pos,Render.btn_ready)){
						{set_ready}
					}else {none}
				}
			}
			default: {none}
		}

	}
	
	/**
	* 根据点击屏幕的坐标获得选中的牌
	* 如果没有选中则返回{none}
	*/
   client function get_clicked_card(deck,pos){
		done = List.length(deck.donecards);
		hand = List.length(deck.handcards);
		start_x = 28 + 140*done;
		b_bound = Button.bound(pos,start_x,545,45*hand+30,70);

		if(not(b_bound)) {none} else{
			if((pos.x >= start_x + (hand - 1)*45 + 30) && (pos.x <= start_x + hand*45 + 30)){
				List.get(hand-1,deck.handcards)
			}else{
				n = (pos.x - start_x) / 45;
				List.get(n,deck.handcards);
			}
		}
	}

	/**
	* 弃牌 
	*/
	public function discard(game,idx,card){
		deck = LowLevelArray.get(game.board.decks,idx);
		card_cnt = List.length(deck.handcards) + List.length(deck.donecards)*3
		if(card_cnt <= 13){
			Log.warning("Mahjong","Try to discard card, but only has 13 cards.");
		}else{
			game = {game with board: Board.discard(game.board,idx,card),
					status:{wait_for_resp},
					curr_card: some(card)} |> reset_actions(_) |> update(_);
			Network.broadcast({DISCARD_CARD: {index:idx,~card} },game.game_channel)

			//如果没有人能够动作，则直接进入下一个玩家
			b_done = LowLevelArray.for_all(game.actions)(function(act){act == {no_act}})
			if(b_done) Scheduler.sleep(2000,function(){next_turn(game.id)}) else{
				Scheduler.sleep(1500,function(){
					LowLevelArray.iteri(function(i,act){
						match(LowLevelArray.get(game.players,i)){
						case  {none}: void
						case ~{some}:{
							if(some.is_bot && act == {none}) Bot.call(game,i);
						}}						
					},game.actions);
				});
			}
		}		
	}
	
		
	/**
	* 玩家player碰
	*/
	private function peng(game,idx){
		game = {game with board: Board.peng(game,idx,Option.get(game.curr_card)),
				status: 	{select_action},
				curr_turn: 	idx,
				curr_card: 	{none}} |> update(_);

		Network.broadcast({NEXT_ACTION: Game.game_msg(game),ACT:{peng}},game.game_channel)
		
		match(LowLevelArray.get(game.players,idx)){
		case  {none}: void
		case ~{some}: if(some.is_bot) Scheduler.sleep(1000,function(){Bot.play(game,idx)})
		}
	}
	
	/**
	* 玩家player杠牌
	*/
	private function gang_card(game,idx){
		game = {game with board: Board.gang(game,idx,Option.get(game.curr_card)),
				status: 	{select_action},
				curr_turn: 	idx,
				curr_card: 	{none}} |> update(_)
				
		Network.broadcast({NEXT_ACTION: Game.game_msg(game),ACT:{gang}},game.game_channel)

		match(LowLevelArray.get(game.players,idx)){
		case  {none}: void
		case ~{some}: if(some.is_bot) Scheduler.sleep(1000,function(){Bot.play(game,idx)})
		}
	}

	/**
	* 玩家自己杠牌
	*/
	private function gang_self(game,idx){

		//首先找到可以杠的牌
		deck = LowLevelArray.get(game.board.decks,idx);
		gangs = Board.find_gangs(deck);

		//如果结果长度为1，则杠这个
		gang = List.head(gangs);

		//从手牌中过滤掉这些牌，然后加到donecards中
		gang_card = List.head(gang.cards);
		handcards = List.filter(function(c){
			c.point != gang_card.point || c.suit != gang_card.suit
		},deck.handcards);
					
		deck = {deck with handcards: handcards}
		deck = match(gang.kind){
			case {Hard_Gang}:{deck with donecards: gang +> deck.donecards}
			case {Soft_Gang}:{
				//先去掉原来的那个碰，在加上现在的这个杠
				donecards = List.filter(function(d){
					if(d.kind != {Peng}) {true} else {
						c = List.head(d.cards)
						if(c.point == gang_card.point && c.suit == gang_card.suit) {false} else {true}
					}
				},deck.donecards);
				{deck with donecards: gang +> donecards}
			}
			default: deck
		}
					
		//更新deck
		LowLevelArray.set(game.board.decks,idx,deck)
		game = {game with board: Board.deal_card(game.board,idx), 
				status: 	{select_action},
				curr_turn: 	idx,
				curr_card: 	{none}} |> update(_) 
					
		Network.broadcast({NEXT_ACTION: Game.game_msg(game),ACT:{gang_self}},game.game_channel)

		match(LowLevelArray.get(game.players,idx)){
		case  {none}: void
		case ~{some}: if(some.is_bot) Scheduler.sleep(1000,function(){Bot.play(game,idx)})
		}
	}
	
	/**
	* 玩家player胡牌
	*/
	private function hoo(game,winners){
		//从服务器端再检查一遍能否胡牌
		game = {game with winners: winners, status:{game_over}} |> update(_);
		Network.broadcast({HOO: winners},game.game_channel)
		Scheduler.sleep(5000,function(){
			show_result(game);
		});
	}

	//流局
	private function draw_play(game){
		game = {game with status: {show_result}} |> update(_)
		Network.broadcast({SHOW_RESULT: {none}},game.game_channel);

		Scheduler.sleep(10000,function(){
			match(Game.get(game.id)){
				case {none}: void
				case ~{some}: if(some.status == {show_result}) restart(some);
			}
		});
	}
	
	//显示结算结果
	private function show_result(game){
		//计算玩家的本局的积分
		result = calc_scores(game);	
		
		//更新玩家的积分
		players = update_scores(game.players,result); 

		//把所有机器人的OK状态设置为ready
		ok_flags = LowLevelArray.foldi(function(i,player,result){
			match(player){
				case {none} : result 
				case ~{some}: if(some.is_bot) set_flag(result,i) else result;
			}
		},players,0);

		game = {game with ~players, ~ok_flags, status:{show_result}} |> update(_)	
		
		//广播得分消息
		Network.broadcast({SHOW_RESULT: some(result)},game.game_channel)
		Scheduler.sleep(10000,function(){
			match(Game.get(game.id)){
				case {none}: void
				case ~{some}: if(some.status == {show_result}) restart(some);
			}
		});
	}
	
	/** 重新开始游戏 */
	private function restart(game){
		Log.debug("Mahjong","restart game: {game.id}")
		game = Game.restart(game,{false}) |> update(_)
		Network.broadcast({GAME_RESTART: Game.game_msg(game)},game.game_channel)
	}

	/**
	* 设置用户准备好 
	*/
	private function set_ready(game,idx){
		game = {game with ready_flags: set_flag(game.ready_flags,idx), change_flag: {true}}
		if(game.ready_flags == ALL_IS_READY){
			game = Game.start(game) |> update(_);
			Network.broadcast({GAME_START: Game.game_msg(game)},game.game_channel)
		}else{
			game = update(game);
			Network.broadcast({PLAYER_READY: game.ready_flags},game.game_channel)
		}		
	}
	
	/** 设置用户关闭了结算界面 */
	private function set_ok(game,idx){
		game = {game with ok_flags: set_flag(game.ok_flags,idx)} |> update(_);
		if(game.ok_flags == ALL_IS_OK){
			game = Game.restart(game,{false}) |> update(_)
			Network.broadcast({GAME_RESTART: Game.game_msg(game)},game.game_channel)
		}
	}
	
	/** 
	* 离开游戏
	* 如果游戏在进行中，就把玩家的状态设置为offline
	* 如果游戏在等待阶段，则直接从玩家列表中删除玩家。
	*/
	exposed function quit(game_id,idx){
		with_game(game_id,function(game){
			ctx = LowLevelArray.get(game.clients,idx)?{client:"",page:0}
			clnt = match(ThreadContext.get({current}).key){
				case {`client`:c}:c
				default: {client:"",page:0}
			}
			
			if(ctx.client == clnt.client && ctx.page == clnt.page){
				ready_flags = clear_flag(game.ready_flags,idx);
				game = {game with ~ready_flags, change_flag:{true}}

				if(game.status == {prepare} || game.status == {game_over}){
					LowLevelArray.set(game.players,idx,{none});
					game = update(game);
					Network.broadcast({PLAYER_CHANGE: Game.game_msg(game)},game.game_channel)

					//如果游戏的player都离开了，则结束游戏。
					if(Game.get_online_cnt(game.players) == 0){
						game = {game with ready_flags:0,players: LowLevelArray.create(4,{none})}; //清空玩家
						restart(game);
					}
				} else {
					players = LowLevelArray.mapi(game.players)(function(i,p){
						if(i != idx) p else {
							match(p){
							case {none}:   {none}
							case {some:p}: some({p with status: {offline}})
							}
						}
					});
					game = {game with players: players} |> update(_);

					//如果游戏的player都离开了，则结束游戏。
					if(Game.get_online_cnt(game.players) == 0){
						game = {game with ready_flags:0,players: LowLevelArray.create(4,{none})}; //清空玩家
						restart(game);
					}
				}
			}else{
				jlog("QUIT Canceled.");
			}
		});
	}

	/** 
	* 向服务端请求操作
	* @game_id： 游戏id
	* @index：   玩家的index 
	* @act Action.t: 请求动作
	*/
	@async exposed function request_action(game_id,index,act){
		Log.debug("Mahjong","Player (idx = {index}) request action {act}");
		with_game(game_id,function(game){
			match(act){
				case {discard: card}: discard(game,index,card);
				case {set_ready}: set_ready(game,index);
				case {set_ok}: set_ok(game,index);
				case act: {
					//把第idx个actions设置为act
					LowLevelArray.set(game.actions,index,act);
					//如果game.actions里面没有了{none},说明所有的玩家都已经选择了
					b_done = LowLevelArray.for_all(game.actions)(function(act){act != {none}});
					if(b_done) do_action(game);
				}
			}
		});
	}

	function do_action(game){
		actor = find_actors(game.actions)
		Log.debug("Mahjong","Actor is {actor}");
		match(actor){
			case {none}: {
				//没有人选择动作，即所有人都放弃
				next_turn(game.id);
			}
			case {act: act}: {
				match(act.action){
					case {hoo}:  hoo(game,[act.index]) 
					case {peng}: peng(game,act.index)
					case {gang}: gang_card(game,act.index)
					case {gang_self}: gang_self(game,act.index)
					default: void
				}
			}
			case {hoos: hoos}: {
				winners_idx = List.fold(function(hoo,hoo_idx){
					if(hoo.action != {hoo}) hoo_idx else{
						hoo.index +> hoo_idx
					}
				},hoos,[]);

				hoo(game,winners_idx);
			}
		}
	}
	
	/** 
	* 寻找执行动作的玩家
	* @return {none}: 表示没有玩家执行动作
	* @return {act: act}: 某一个玩家执行动作
	* @return {hoos: hoos}: 某几个玩家执行动作（只有可能是胡）
	*
	*/
	private function find_actors(actions){
		b_noact = LowLevelArray.for_all(actions)(function(act){act == {no_act}});
		if(b_noact) {none} else {
			hoos = LowLevelArray.foldi(function(i,act,hoos){
				if(act != {hoo}) hoos else {
					{index: i, action: {hoo}} +> hoos
				}
			},actions,[]);
			
			match(List.length(hoos)){				
				case 0: {
					act = LowLevelArray.foldi(function(i,act,result){
						if(result.index != -1) result else {
							if(act == {no_act} || act == {none}) result else {
								{index: i, action: act}
							}
						}
					},actions,{index: -1, action: {no_act}});
					if(act.index == -1) {none} else {act: act};
				}
				case 1: {act: List.head(hoos)}
				case _: {hoos:hoos}
			}
		}
	}

	/** 计算得分 */
	function calc_scores(game){
		winners = game.winners
		/** 向链表中加入一个胡的条目，如果已经存在则将他的n加1 */
		function add_item(item,item_list){
			it = List.find(function(it){
				it.name == item.name
			},item_list);

			match(it){
				case {none}: item +> item_list
				case {some: _}: {
					List.map(function(it){
						if(it.name != item.name) it else {
							{it with n: it.n + 1}
						}
					},item_list);
				}
			}
		}

		result = LowLevelArray.create(4,[])
		last_idx = game.curr_turn; //最后出牌玩家的index
		is_zimo = (List.length(winners) == 1 && List.head(winners) == last_idx); //是否是自摸 

		//如果是自摸
		result = if(is_zimo){
			LowLevelArray.mapi(result)(function(i,r){
				if(i == last_idx) List.add(ZIMO,r) else List.add(B_ZIMO,r)
			});
		}else{
			LowLevelArray.mapi(result)(function(i,r){
				//如果第i个玩家是winner，则添加一个胡牌的item 
				if(List.exists(function(idx){ idx == i},winners)){
					List.add(HOO,r)
				}else{
					//如果是放炮
					if(i != last_idx) r else List.add({FANGPAO with n: List.length(winners)},r)
				}
			});
		}

		//检查杠和被杠
		LowLevelArray.foldi(function(i,deck,result){
			List.fold(function(pattern,r){
				match(pattern.kind){
					case {Soft_Gang}:{
						//result的第i个元素将一个S_GANG,第src_idx加一个B_GANG
						LowLevelArray.mapi(r)(function(j,r){
							if(j == i) add_item(S_GANG,r) else {
								if(j == pattern.source) add_item(B_GANG,r) else r
							}
						});
					}
					case {Hard_Gang}:{
						LowLevelArray.mapi(r)(function(j,r){
							if(j == i) add_item(H_GANG,r) else add_item(B_GANG,r)
						});
					}
					default: r
				}
			},deck.donecards,result);				
		},game.board.decks,result);
	}

	/** 更新玩家积分 */
	both function update_scores(players,result){
		LowLevelArray.mapi(players)(function(i,p){
			r = LowLevelArray.get(result,i);
			score = List.fold(function(it,score){
				score + (it.point * it.n)
			},r,0);

			match(p){
				case {none}: p
				case ~{some:p}: some({p with coins: p.coins + score})
			}
		});
	}
	
	/** 下一个玩家 */
	function next_turn(game_id){
		with_game(game_id,function(game){
			//如果已经没有牌了，游戏结束，流局
			if(List.length(game.board.card_pile) == 0) draw_play(game) else {
				//将当前牌加入到弃牌堆
				board = match(game.curr_card){
					case {none}: game.board
					case {some:card}: Board.add_to_discards(game.board,game.curr_turn,card)
				}
				
				//更新游戏状态
				game = {game with ~board, status:{select_action}, curr_turn: Board.get_next_idx(game.curr_turn)}
				game = {game with board: Board.deal_card(game.board,game.curr_turn), curr_card: {none}} |> update(_);
				
				//广播游戏消息				
				Network.broadcast({NEXT_TURN: Game.game_msg(game)},game.game_channel);
				
				//如果当前玩家为状态不为{online},则1s钟之后自动弃牌
				match(LowLevelArray.get(game.players,game.curr_turn)){
					case {none}: Scheduler.sleep(1000,function(){ default_action(game)}); 
					case {some:player}:{
						if(player.is_bot == {false} && player.status != {online}) {
							Scheduler.sleep(1000,function(){ default_action(game)});
						}else{
							if(player.is_bot) Scheduler.sleep(1000,function(){Bot.play(game,game.curr_turn)});
						}
					}
				}
			}
		});
	}
	
	function reset_actions(game){
		actions = LowLevelArray.init(4)(function(i){
			deck = LowLevelArray.get(game.board.decks,i);
			can_act = match(game.curr_card){
				case  {none}: {false}
				case ~{some}: {
					Board.can_peng(deck,some) || Board.can_gang(deck,some) || Board.can_hoo_card(deck,some);
				}
			}

			match(LowLevelArray.get(game.players,i)){
				case  {none}: {no_act}
				case ~{some}: {
					if(some.status != {online}) {no_act} else {
						if(i != game.curr_turn && can_act) {none} else {no_act}
					}
				}
			}	
		});
		{game with ~actions};
	}
	
	/** 
	* 当前玩家的默认动作，即弃掉多余的一张牌 
	*/
	function default_action(game){
		handcards = LowLevelArray.get(game.board.decks,game.curr_turn).handcards;
		card = Option.get(List.get(List.length(handcards)-1,handcards));
		discard(game,game.curr_turn,card);
	}
}
