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
import stdlib.web.canvas
import-plugin engine2d

/**
* 客户端游戏展示所用到的对象，这个和服务端Game.t的定义是有区别的。
* 因为不能直接把服务端游戏对象发给客户端，因为这样不仅浪费网络流量，
* 而且玩家还可以获得一些不该知道的信息（例如别的玩家的牌）
* Game.obj定义了作为客户端视图应该能够看到的所有信息，用于绘制牌面。
*/
type Game.obj = {
	/** 游戏相关信息 */
	string id,                    			//游戏id 
	Status.t status,             			//游戏状态
	int curr_turn,               			//当前玩家
	int ready_flags,						//玩家的准备好标志
	option(Card.t) curr_card,               //当前牌面上的牌 
	llarray(option(Player.t)) players,    	//玩家列表
	llarray(Deck.t) decks,		 			//所有玩家牌面 
	llarray(Discard.t) discards,   			//所有玩家的弃牌 
	llarray(string) pile_info, 				//所有玩家的牌堆情况

	/** 本玩家相关信息 */
	Player.t player,						//当前玩家对应的对象
	int idx,								//当前玩家在游戏中的坐标
	Deck.t deck,							//当前玩家的牌面
	bool is_ting,							//当前玩家是否听了
	bool is_ok,								//是否点击了积分的确定按钮
}

set_game = %%engine2d.set_game%%;
get_game = %%engine2d.get_game%%;

/**
* 游戏的绘制引擎 
*/
client module Render {
	bool DEBUG = {true}
	bool SHOW_TILE = {true}

	//常用颜色的定义
	BLACK = {color:Color.rgb(0,0,0)};
	RED = {color: Color.rgb(255,0,0)};
	BLUE = {color: Color.rgb(0,0,255)};

	PREFIX = "/resources/"
	
	//等待时间 
	WAIT_TIME = 10

	Button.t btn_peng   = Button.simple(490,475,60,60,"碰");   //碰
	Button.t btn_gang   = Button.simple(550,475,60,60,"杠");   //杠 
	Button.t btn_hoo    = Button.simple(610,475,60,60,"胡");   //胡
	Button.t btn_cancel = Button.simple(670,475,60,60,"放弃");   //放弃
	Button.t btn_ready  = Button.simple(330,555,150,57,"准备"); //准备
	Button.t btn_hide_result = Button.simple(333,423,75,45,"确定"); //关闭结算
	
	/** 是否在麻将牌上显示数字 */
	g_show_number = Mutable.make(bool {false});
	function show_or_hide_number(){
		g_show_number.set(not(g_show_number.get()));
		refresh();
	}

	/** 是否显示传统的牌面 */
	g_show_classic_tile = Mutable.make(bool {false});
	function change_tile_style(){
		g_show_classic_tile.set(not(g_show_classic_tile.get()));
		refresh();
	}

	function get_ctx(id){
		canvas = Canvas.get(id);
		Option.get(Canvas.get_context_2d(Option.get(canvas)));
	}
	
	/** 获得图片资源 */
	function get(key){
		{image: %%engine2d.get%%(PREFIX ^ key)}
	}

	/** 预加载图片和声音资源 */
	function preload(imgs,auds,f){
		imgs = List.map(function(img){
			PREFIX ^ img
		},imgs);
		auds = List.map(function(aud){
			PREFIX ^ aud
		},auds);
		%%engine2d.preload%%(imgs,auds,f);
	}

	function play_sound(key){
		%%engine2d.play_sound%%(PREFIX ^ key);
	}

	start_timer = %%engine2d.start_timer%%
	stop_timer = %%engine2d.stop_timer%%
	show_menu = %%engine2d.show_menu%%
	
	/** 获取card所对应的图案在png文件中的坐标 */
	function get_x(card){ (card.point - 1) * 40}
	function get_y(card){
		 match(card.suit){
			case {Bing}: 0
			case {Tiao}: 50
			case {Wan}: if(g_show_classic_tile.get()) 100 else 150
		}
	}
	
	function refresh(){
		ctx = get_ctx(#gmcanvas);
		game = get_game();
		
		//清除背景
		clear_bg(ctx,game);

		//绘制玩家信息
		draw_player_info(ctx,game.players,game.idx);
		
		if(game.status == {prepare} || ( game.status == {show_result} && game.is_ok)){	
			draw_prepare(ctx,game,game.idx);				//绘制牌堆
			if(not(test_flag(game.ready_flags,game.idx))) Canvas.draw_image(ctx,get("start.png"),330,555);  //绘制“准备”按钮
		}else{
			draw_discards(ctx,game.discards,game.idx);	 	//绘制玩家弃牌
			draw_handcards(ctx,game);						//绘制玩家手牌（不包括自己）
			draw_self_cards(ctx,game);						//绘制自己的手牌
			draw_pileinfo(ctx,game.pile_info,game.idx);  	//绘制牌堆信息
			draw_board_info(ctx,game,game.player);			//指示当前玩家
		}

		//绘制调试信息
		if(DEBUG) show_game_info(ctx,game);
	}

	function clear_bg(ctx,game){
		Canvas.clear_rect(ctx,0,0,740,625);
		if(Game.in_process(game)) draw_left_time(ctx,0);
	}

	function show_game_info(ctx,game){
		Canvas.save(ctx);
		Canvas.set_fill_style(ctx,BLUE);
		Canvas.set_font(ctx,"12px serif");
		Canvas.fill_text(ctx,"游戏ID：{game.id}",5,10);
		Canvas.fill_text(ctx,"状态：{game.status}",5,25);
		Canvas.fill_text(ctx,"当前玩家: {game.curr_turn}",5,40);
		match(game.curr_card){
			case {some:card}: Canvas.fill_text(ctx,"当前牌：{Card.to_string(card)}",5,55);
			case {none}: Canvas.fill_text(ctx,"当前牌：none",5,55);
		}
		Canvas.fill_text(ctx,"玩家坐标: {game.idx}",5,70);
		Canvas.fill_text(ctx,"准备状态: {game.ready_flags}",5,85);
		Canvas.fill_text(ctx,"OK Flag: {game.is_ok}",5,100);
		Canvas.restore(ctx);
	}
	
	/**
	* 绘制玩家信息
	*/
	function draw_player_info(ctx,players,idx){
		INFO_POS = [{x:110,y:498},{x:50,y:298},{x:680,y:25},{x:685,y:298}]
		Canvas.save(ctx)
		Canvas.set_fill_style(ctx,{color:Color.rgb(13,30,40)})
		Canvas.set_font(ctx,"normal bold 14px serif");
		Canvas.set_text_align(ctx,{align_center});
		LowLevelArray.iteri(function(i,p){
			rel_pos = Board.get_rel_pos(idx,i);
			pos = Option.get(List.get(rel_pos,INFO_POS));
			match(p){
				case ~{some}:{
					match(rel_pos){
						case 3: {
							Canvas.draw_image(ctx,get("player_frame_v.png"),640,215);
							Canvas.draw_image(ctx,get("portrait.jpg"),659,227);
							Canvas.draw_image_full(ctx,get("eswn.png"),30*i,0,30,30,pos.x+10,pos.y+40,30,30);
							if(some.status != {online}) Canvas.draw_image(ctx,get("offline.png"),645,220)
						}
						case 2: {
							Canvas.draw_image(ctx,get("player_frame_h.png"),575,0);
							Canvas.draw_image(ctx,get("portrait.jpg"),587,10);
							Canvas.draw_image_full(ctx,get("eswn.png"),30*i,0,30,30,pos.x+20,pos.y+45,30,30);
							if(some.status != {online}) Canvas.draw_image(ctx,get("offline.png"),580,5)
						}
						case 1: {
							Canvas.draw_image(ctx,get("player_frame_v.png"),5,215);
							Canvas.draw_image(ctx,get("portrait.jpg"),24,227);
							Canvas.draw_image_full(ctx,get("eswn.png"),30*i,0,30,30,pos.x-40,pos.y+40,30,30);
							if(some.status != {online}) Canvas.draw_image(ctx,get("offline.png"),10,220)
						}
						default: {
							Canvas.draw_image(ctx,get("player_frame_h.png"),5,470);
							Canvas.draw_image(ctx,get("portrait.jpg"),17,480);
							Canvas.draw_image_full(ctx,get("eswn.png"),30*i,0,30,30,pos.x+55,pos.y+10,30,30);
							if(some.status != {online}) Canvas.draw_image(ctx,get("offline.png"),10,475)
						}
					}
					
					name = if(String.length(some.name) <= 10) some.name else {
						String.drop_right(String.length(some.name) - 10,some.name);
					}
					Canvas.fill_text(ctx,name,pos.x,pos.y);
					Canvas.fill_text(ctx,"{some.coins}",pos.x,pos.y+25);						
				}
				case {none}: void
			}
		},players);
		Canvas.restore(ctx);
	}
	
	/**
	* 游戏等待的界面
	*/
	function draw_prepare(ctx,game,idx){
		Canvas.save(ctx)		
		//绘制牌堆
		LowLevelArray.iter(function(p){
			match(p){
				case {none}: void
				case ~{some}:{
					rel_pos = Board.get_rel_pos(idx,some.idx)
					match(rel_pos){
						case 1: ignore(for(0,function(n){ draw_wall(ctx,1,178,146+20*n,{true}); n+1; }, _ <= 13))
						case 2: ignore(for(0,function(n){ draw_wall(ctx,2,223+24*n, 71,{true}); n+1; }, _ <= 13))
						case 3: ignore(for(0,function(n){ draw_wall(ctx,3,585,147+20*n,{true}); n+1; }, _ <= 13))
						case _: ignore(for(0,function(n){ draw_wall(ctx,0,223+24*n,479,{true}); n+1; }, _ <= 13))
					}
					if(test_flag(game.ready_flags,some.idx)){
						Canvas.set_font(ctx,"normal bold 24px serif");
						Canvas.set_fill_style(ctx,RED);
						match(rel_pos){
							case 1: Canvas.fill_text(ctx,"Ready",220,295)
							case 2: Canvas.fill_text(ctx,"Ready",360,150)
							case 3: Canvas.fill_text(ctx,"Ready",500,295)
							case _: Canvas.fill_text(ctx,"Ready",360,445)
						}
					}
				}
			}
		},game.players);
		
		//绘制等待信息
		Canvas.set_fill_style(ctx,BLACK);
		Canvas.set_font(ctx,"normal bold 11pt serif");
		Canvas.set_text_align(ctx,{align_center});
		Canvas.fill_text(ctx,"Waiting for players to set ready",400,360);
		Canvas.fill_text(ctx,"Game will start when four players are",400,385);
		Canvas.fill_text(ctx,"all ready",400,410);
		Canvas.restore(ctx);
	}


	/**
	* 绘制本局游戏结果 
	*/
	function show_result(game,result,x,y){
		ctx = get_ctx(#gmcanvas)
		Canvas.draw_image(ctx,get("result.png"),x,y)
		Canvas.save(ctx);
		LowLevelArray.iteri(function(i,items){
			r = List.foldi(function(_,it,r){
				item = match(it.n){
					case 1: Mahjong.item_to_name(it.name)
					case _: Mahjong.item_to_name(it.name) ^ " x {it.n}"
				}
				point = it.point * it.n
				{item: r.item ^ " {item} : {point} ", score: r.score + point}
			},List.rev(items),{item:"",score:0});

			//绘制玩家名称
			player_name = match(LowLevelArray.get(game.players,i)){
				case {none}:  "anonymous"
				case ~{some}: some.name
			}

			draw_item(ctx,x,y,i,game.idx,player_name,"{r.item}","{r.score}");
		},result);
		Canvas.restore(ctx);
	}

	/** 显示平局 */
	function show_draw_play(game,x,y){
		ctx = get_ctx(#gmcanvas)
		refresh();

		Canvas.draw_image(ctx,get("result.png"),x,y)
		Canvas.save(ctx);
		LowLevelArray.iteri(function(i,p){
			//绘制玩家名称
			player_name = match(p){
				case {none}:  "anonymous"
				case ~{some}: some.name
			}

			draw_item(ctx,x,y,i,game.idx,player_name,"Draw","0");
		},game.players);
		Canvas.restore(ctx);		
	}

	function draw_item(ctx,x,y,i,idx,player_name,items,score){
		if(idx == i){
			Canvas.set_fill_style(ctx,{color:Color.rgb(255,255,0)});
			Canvas.fill_rect(ctx,x+9,y+104+i*60,332,55);
			Canvas.set_fill_style(ctx,BLACK);
		}else{
			Canvas.set_fill_style(ctx,{color:Color.rgb(255,255,255)});
		}

		Canvas.set_font(ctx,"normal bold 24px serif");
		Canvas.set_text_align(ctx,{align_left});
		Canvas.fill_text(ctx,player_name,x+10,y+130+60*i);

		//绘制胡牌的条目
		Canvas.set_font(ctx,"11px serif");
		Canvas.fill_text(ctx,items,x+10,y+155+60*i);			

		//绘制得分 
		Canvas.set_font(ctx,"normal bold 30px serif");
		Canvas.set_fill_style(ctx,RED);
		Canvas.set_text_align(ctx,{align_right});
		Canvas.fill_text(ctx,score,x+335,y+142+60*i);
	}
	
	/** 当用户点击了OK之后，关闭得分界面 */
	function hide_result(){
		set_game({get_game() with is_ok: {true}});
		refresh();
	}

	/** 绘制指示当前牌的指示器 */
	function draw_board_info(ctx,game,player){
		//指示当前玩家 
		rel_pos = Board.get_rel_pos(player.idx,game.curr_turn)
		rel_pos = if(game.status != {wait_for_resp}) rel_pos else mod(rel_pos+3,4)
		Canvas.save(ctx)
		match(rel_pos){
			case 1: {
				Canvas.rotate(ctx,Math.PI / 2.0)
				Canvas.draw_image(ctx,get("arrow.png"),237,-410);				
			}
			case 2: { 
				Canvas.rotate(ctx,Math.PI);
				Canvas.draw_image(ctx,get("arrow.png"),-330-80,-237-80);
			}
			case 3: { 
				Canvas.rotate(ctx,Math.PI / -2.0)
				Canvas.draw_image(ctx,get("arrow.png"),-237-80,330);			
			}
			default: Canvas.draw_image(ctx,get("arrow.png"),330,237);
		}
		Canvas.restore(ctx);
		
		//绘制当前的牌
		if(game.status == {wait_for_resp}){
			match(game.curr_card){
				case {none}: void
				case ~{some}: {
					match(Board.get_rel_pos(player.idx,game.curr_turn)){
						case 3: {
							draw_dialog(ctx,3);
							draw_card(ctx,some,505,233);
						}
						case 2: {
							draw_dialog(ctx,2);
							draw_card(ctx,some,348,72);
						}
						case 1: {
							draw_dialog(ctx,1);
							draw_card(ctx,some,188,233);
						}
						default:{
							draw_dialog(ctx,0);
							draw_card(ctx,some,348,400);
						}
					}
				}
			}
		}
	}

	/**
	* 绘制玩家的弃牌
	* @discards: 弃牌的数组
	* @idx: 当前玩家的坐标
	*/
	function draw_discards(ctx,d,idx){
		LowLevelArray.iteri(function(pos,discards){
			rel_pos = Board.get_rel_pos(idx,pos);
			match(rel_pos){ 
			case 1:{
				List.iteri(function(i,card){
					if(i <= 9) draw_down_card_left(ctx,card,199,161+i*22,{false}) else{
						draw_down_card_left(ctx,card,235,177+(i-10)*22,{false})
					}
				},List.rev(discards));
			}
			case 2:{
				List.iteri(function(i,card){
					if(i <= 9) draw_down_card_oppt(ctx,card,473-i*25,107,{false}) else{
						draw_down_card_oppt(ctx,card,443-(i-10)*25,137,{false})
					}
				},List.rev(discards));
			}
			case 3:{
				List.iteri(function(i,card){
					match(i){
					case 0:  draw_down_card_right(ctx,card,506,358,{false});
					case 10: draw_down_card_right(ctx,card,470,344,{false});
					case x:  {
						if(x <= 9) draw_down_card_right_half(ctx,card,506,358-i*22) else {
							draw_down_card_right_half(ctx,card,470,344-(i-10)*22);
						}
					}}
				},List.rev(discards));
			}
			case _:{
				List.iteri(function(i,card){
					if(i <= 9) draw_down_card_self(ctx,card,244+25*i,406) else{
						draw_down_card_self_half(ctx,card,270+25*(i-10),376)
					}
				},List.rev(discards));
			}}
		},d);
	}
	
	/**
	* 绘制玩家的手牌（包括已成的牌和手中的牌）
	* @idx : 当前玩家的坐标
	*
	*/
	function draw_handcards(ctx,game){
		LowLevelArray.iteri(function(pos,deck){
			rel_pos = Board.get_rel_pos(game.idx,pos);
			card_cnt = 13 - List.length(deck.donecards)*3;
			card_cnt = if(game.curr_turn == pos) card_cnt+1 else card_cnt;

			match(rel_pos){
			case 1:{
				List.iteri(function(i,pattern){
					rel_pos = Board.get_rel_pos(game.idx,pattern.source);
					rel_pos = mod(rel_pos + 3, 4)
					y = 85 + i*82
					match(pattern.kind){
						case {Soft_Gang}: draw_gang(ctx,1,pattern.cards,100,y,rel_pos, {false});
						case {Hard_Gang}: draw_gang(ctx,1,pattern.cards,100,y,rel_pos, {true});
						default: draw_peng(ctx,1,pattern.cards,100,y,rel_pos);
					}
				},deck.donecards);

				start_y = 85 + 82*List.length(deck.donecards);
				if(SHOW_TILE || game.status == {game_over} || game.status == {show_result}){
					List.iteri(function(n,c){ draw_down_card_left(ctx,c,100,start_y+22*n,{false}); },deck.handcards);
				}else{
					ignore(for(0,function(n){ draw_covered(ctx,rel_pos,120,start_y+22*n); n+1;}, _ <= card_cnt - 1))
				}
			}
			case 2:{
				//绘制成牌
				List.iteri(function(i,pattern){
					rel_pos = Board.get_rel_pos(game.idx,pattern.source);
					rel_pos = match(rel_pos){
						case 0: 2
						case 2: 0
						case x: x
					}
					x = 567 - (i+1)*85
					match(pattern.kind){
						case {Soft_Gang}: draw_gang(ctx,2,pattern.cards,x,5,rel_pos,{false});
						case {Hard_Gang}: draw_gang(ctx,2,pattern.cards,x,5,rel_pos,{true});
						default: draw_peng(ctx,2,pattern.cards,x,12,rel_pos);
					}
				},deck.donecards);

				//绘制手牌
				start_x = 545 - 85*List.length(deck.donecards) - 25*card_cnt;
				if(SHOW_TILE || game.status == {game_over} || game.status == {show_result}){
					List.iteri(function(n,c){ draw_down_card_oppt(ctx,c,start_x+25*n,5,{false}); },deck.handcards);
				}else{
					ignore(for(0,function(n){ draw_covered(ctx,2,start_x+25*n,5); n+1;}, _ <= card_cnt-1))
				}
			}
			case 3:{
				//绘制成牌
				List.iteri(function(i,pattern){
					rel_pos = Board.get_rel_pos(game.idx,pattern.source);
					rel_pos = 3 - rel_pos
					y = 465 - 82*(i+1)
					match(pattern.kind){
						case {Soft_Gang}: draw_gang(ctx,3,pattern.cards,600,y,rel_pos,{false});
						case {Hard_Gang}: draw_gang(ctx,3,pattern.cards,600,y,rel_pos,{true});
						default: draw_peng(ctx,3,pattern.cards,600,y,rel_pos);
					}
				},deck.donecards);

				//绘制手牌
				start_y = 465 - 82*List.length(deck.donecards) - 22*(card_cnt+1)
				if(SHOW_TILE || game.status == {game_over} || game.status == {show_result}){
					List.iteri(function(n,c){ draw_down_card_right(ctx,c,600,start_y+22*n,{false}); },deck.handcards);
				}else{
					ignore(for(0,function(n){ draw_covered(ctx,3,600,start_y+22*n); n+1;}, _ <= card_cnt-1))
				}
			}
			default: void
			}
		},game.decks);
	}

	function draw_self_cards(ctx,game){
		deck = game.deck;
		//绘制成牌
		offset_x = 28 - List.length(deck.donecards)*5;
		y = 545
		List.iteri(function(i,pattern){
			rel_pos = Board.get_rel_pos(game.idx,pattern.source);
			x = offset_x + i*140;
			match(pattern.kind){
				case {Soft_Gang}: draw_gang(ctx,0,pattern.cards,x,y,rel_pos,{false})
				case {Hard_Gang}: draw_gang(ctx,0,pattern.cards,x,y,rel_pos,{true})
				default: draw_peng(ctx,0,pattern.cards,x,y,rel_pos);
			}
		},game.deck.donecards);

		//再绘制手牌
		start_x = offset_x + List.length(deck.donecards) * 140;
		card_cnt = List.length(deck.handcards) + List.length(deck.donecards)*3;
		List.iteri(function(i,card){
			x = if(i == List.length(deck.handcards) - 1 && card_cnt == 14
					&& game.status == {select_action} && game.curr_turn == game.idx){
				start_x + 45*i + 30;
			}else{ start_x + 45*i}
			if(game.status != {game_over} && game.status != {show_result}) draw_card(ctx,card,x,y) else draw_down_card(ctx,card,x,y,{false});
		},deck.handcards);
		
		if(game.is_ting) Canvas.draw_image(ctx,get("ting.png"),303,500);
	}

	/**
	* 绘制牌堆信息
	*/
	function draw_pileinfo(ctx,piles,idx){
		LowLevelArray.iteri(function(n,wall){
			//相对位置,注意是顺时针的
			rel_pos = mod(n + 4 + idx,4)    
			wall = if(rel_pos == 0 || rel_pos == 1) String.rev(wall) else wall
			len = String.length(wall)
			ignore(for(0,function(i){
				match(String.get(i,wall)){
				case "2": {
					match(rel_pos){
						case 1: draw_wall(ctx,rel_pos,164,130+20*i,{true}); 
						case 2: draw_wall(ctx,rel_pos,202+i*24,53 ,{true});
						case 3: draw_wall(ctx,rel_pos,548,130+20*i,{true});
						case _: draw_wall(ctx,rel_pos,202+i*24,453,{true});
					}
				}
				case "1": {
					match(rel_pos){
						case 1: draw_wall(ctx,rel_pos,164,136+20*i,{false}); 
						case 2: draw_wall(ctx,rel_pos,202+i*24,58 ,{false});
						case 3: draw_wall(ctx,rel_pos,548,136+20*i,{false});
						case _: draw_wall(ctx,rel_pos,202+i*24,458,{false});
					}
				}
				default: void
				}
				i+1
			}, _ <= len-1))
		},piles);
	}

	/**
	* 绘制碰出的牌
	*/
	function draw_peng(ctx,rel_pos,cards,x,y,src_idx){
		match(rel_pos){
			case 0: List.iteri(function(i,card){ draw_down_card(ctx,card,x+45*i,y,{false});},cards);
			case 1: List.iteri(function(i,card){ draw_down_card_left(ctx,card,x,y+i*22,{false}) },cards);
			case 2: List.iteri(function(i,card){ draw_down_card_oppt(ctx,card,x+i*25,y-9,{false}) },cards);
			case 3: List.iteri(function(i,card){ draw_down_card_right(ctx,card,x,y+i*22,{false}) },cards);
			default: void
		}
	}

	/**
	* 绘制杠出来的牌 
	*
	*/
	function draw_gang(ctx,rel_pos,cards,x,y,src_idx,is_hard){
		match(rel_pos){
			case 0: {
				List.iteri(function(i,card){
					//如果是暗杠，下面三个蒙上，只留最上面一个 
					if(i != 3) draw_down_card(ctx, card, x+45*i,y,is_hard) else {
						match(is_hard){
							case {true}:  draw_down_card(ctx, card, x+45, y-12, {false})
							case {false}: draw_down_card(ctx, card, x+(src_idx-1)*45, y-12, {false})
						}						
					}					
				},cards)				
			}
			case 1: {
				List.iteri(function(i,card){
					if(i != 3) draw_down_card_left(ctx, card, x, y+i*22, {true}) else {
						match(is_hard){
							case {true}:  draw_down_card_left(ctx, card, x, y+22, {true});
							case {false}: draw_down_card_left(ctx, card, x, y+(src_idx-1)*22, {false});
						}		
					}
				},cards);
			}
			case 2: {
				List.iteri(function(i,card){
					if(i != 3) draw_down_card_oppt(ctx, card, x+i*25,y, {true}) else {
						match(is_hard){
							case {true}:  draw_down_card_oppt(ctx, card, x+25, y-9, {true});
							case {false}: draw_down_card_oppt(ctx, card, x+(src_idx-1)*25, y-9, {false});
						}						
					}
				},cards);
			}
			case 3: {
				List.iteri(function(i,card){
					if(i != 3) draw_down_card_right(ctx, card, x, y+i*22, {true}) else {
						match(is_hard){
							case {true}:  draw_down_card_right(ctx, card, x, y+22, {true});
							case {false}: draw_down_card_right(ctx, card, x, y+(src_idx-1)*22, {false});
						}
					}
				},cards);
			}
			default: void
		}
	}

	function draw_wall(ctx,rel_pos,x,y,is_two){
		is_v = (rel_pos == 0 || rel_pos == 2); //是垂直还是水平的
		match(is_v){
		case {true}:{
			match(is_two){
			case {true}:  Canvas.draw_image_full(ctx,get("board.png"),37,112,24,42,x,y,24,42); //竖直两个
			case {false}: Canvas.draw_image_full(ctx,get("board.png"),62,118,24,36,x,y,24,36); //竖直一个
			}
		}
		case {false}:{
			match(is_two){
			case {true}:  Canvas.draw_image_full(ctx,get("board.png"),0,155,28,32,x,y,28,32);	//水平两个
			case {false}: Canvas.draw_image_full(ctx,get("board.png"),29,155,28,26,x,y,28,26);	//水平一个
			}
		}}
	}

	/**
	* 绘制一个牌（玩家的牌） 
	*/
	function draw_card(ctx,card,x,y){
		Canvas.save(ctx)
		Canvas.draw_image_full(ctx,get("board.png"),0,0,45,71,x,y,45,71)
		Canvas.draw_image_full(ctx,get("tiles.png"),get_x(card),get_y(card),40,50,x+2,y+20,40,50);

		//在牌面上显示数字
		if(g_show_number.get()){
			Canvas.draw_image_full(ctx,get("numbers.png"),(card.point-1)*12,0,12,12,x+3,y+6,12,12);
		}
		Canvas.restore(ctx);
	}
	
	//绘制蒙上的牌（玩家手牌，没胡的时候是看不见的)
	function draw_covered(ctx,rel_pos,x,y){
		match(rel_pos){
		case 1: Canvas.draw_image_full(ctx,get("board.png"),28,70,16,40,x,y,16,40);
		case 2: Canvas.draw_image_full(ctx,get("board.png"),62,74,27,37,x,y,27,37);
		case 3: Canvas.draw_image_full(ctx,get("board.png"),45,70,16,40,x,y,16,40);
		default: void 
		}
	}
	
	/**--绘制亮开的牌
	* 0：自己手牌亮开的牌 
	* 1：自己弃牌亮开的牌 
	* 2: 自己弃牌亮开的牌（一半）
	* 3：左边亮开的牌 
	* 4: 对面亮开的牌 
	* 5：右边亮开的牌 
	* 6：右边弃牌亮开一半的牌
	*/

	/** 绘制自己手牌或成牌中放倒的牌 */
	function draw_down_card(ctx,card,x,y,is_covered){
		match(is_covered){
			case {true}: Canvas.draw_image_full(ctx,get("board.png"),95,0,45,68,x,y,45,68)
			case {false}: {
				Canvas.draw_image_full(ctx,get("board.png"),46,0,45,68,x,y,45,68)
				Canvas.draw_image_full(ctx,get("tiles.png"),get_x(card),get_y(card),40,50,x+3,y+3,40,50);
			}
		}
	}
	
	/** 绘制自己弃牌放倒的牌 */
	function draw_down_card_self(ctx,card,x,y){
		Canvas.draw_image_full(ctx,get("board.png"),0,71,27,40,x,y,27,40);
		draw_card_img(ctx,card,x,y,0);	
	}

	/** 绘制自己弃牌放倒的牌（一半） */
	function draw_down_card_self_half(ctx,card,x,y){
		Canvas.draw_image_full(ctx,get("board.png"),0,71,27,30,x,y,27,30);
		draw_card_img(ctx,card,x,y,0);	
	}

	/** 绘制左侧放到的牌 */
	function draw_down_card_left(ctx,card,x,y,is_covered){
		match(is_covered){
			case {true}: Canvas.draw_image_full(ctx,get("board.png"),60,155,36,33,x,y,36,33);
			case {false}: {
				Canvas.draw_image_full(ctx,get("board.png"),0,112,36,33,x,y,36,33);
				draw_card_img(ctx,card,x,y,1);
			}
		}		
	}

	/** 绘制右边放到的牌 */
	function draw_down_card_right(ctx,card,x,y,is_covered){
		match(is_covered){
			case {true}: Canvas.draw_image_full(ctx,get("board.png"),60,155,36,33,x,y,36,33);
			case {false}: {
				Canvas.draw_image_full(ctx,get("board.png"),0,112,36,33,x,y,36,33);
				draw_card_img(ctx,card,x,y,-1);	
			}
		}		
	}
	
	/** 绘制右边放到的牌(一半）*/
	function draw_down_card_right_half(ctx,card,x,y){
		Canvas.draw_image_full(ctx,get("board.png"),0,112,36,22,x,y,36,22);
		draw_card_img(ctx,card,x,y,-1);
	}
	
	/** 绘制对家放倒的牌 */
	function draw_down_card_oppt(ctx,card,x,y,is_covered){
		match(is_covered){
			case {true}: Canvas.draw_image_full(ctx,get("board.png"),62,118,24,36,x,y,24,36);
			case {false}: {
				Canvas.draw_image_full(ctx,get("board.png"),0,71,27,40,x,y,27,40);
				draw_card_img(ctx,card,x,y,2);
			}
		}		
	}
		
	/**
	* 绘制小的麻将牌的图案
	* rotate： 旋转， 0：不旋转, 1：90度, 2：180度, -1：270度
	*/
	function draw_card_img(ctx,card,x,y,rotate){
		function get_sx(card){ (card.point - 1) * 20}
		function get_sy(card){
			 match(card.suit){
				case {Bing}: 0
				case {Tiao}: 25
				case {Wan}: if(g_show_classic_tile.get()) 50 else 75
			}
		}
		
		Canvas.save(ctx);
		match(rotate){
			case  1: { //90度
				Canvas.rotate(ctx,Math.PI / 2.0)
				Canvas.draw_image_full(ctx,get("tiles_small.png"),get_sx(card),get_sy(card),20,25,y+2,-x-30,20,25);
			}
			case  2: { //180度
				Canvas.rotate(ctx,Math.PI);
				Canvas.draw_image_full(ctx,get("tiles_small.png"),get_sx(card),get_sy(card),20,25,-(x+3)-20,-(y+2)-25,20,25);
			}
			case -1: { //270度
				Canvas.rotate(ctx,Math.PI / -2.0)
				Canvas.draw_image_full(ctx,get("tiles_small.png"),get_sx(card),get_sy(card),20,25,-(y+1)-20,x+3,20,25);				
			}
			default: { //0度
				Canvas.draw_image_full(ctx,get("tiles_small.png"),get_sx(card),get_sy(card),20,25,x+3,y+2,20,25);
			}
		}		
		Canvas.restore(ctx);
	}
	
	/** 绘制对话框 */
	function draw_dialog(ctx,rel_pos){
		match(rel_pos){
			case 3: {
				Canvas.translate(ctx,740,0);
				Canvas.scale(ctx,-1.0,1.0);
				Canvas.draw_image(ctx,get("dialog.png"),160,225);
				Canvas.translate(ctx,740,0);
				Canvas.scale(ctx,-1.0,1.0);
			}
			case 2: {
				Canvas.rotate(ctx,Math.PI);
				Canvas.draw_image(ctx,get("dialog.png"),-420,-150);
				Canvas.rotate(ctx,-Math.PI);
			}
			case 1:  Canvas.draw_image(ctx,get("dialog.png"),160,225);
			default: Canvas.draw_image(ctx,get("dialog.png"),320,390);
		}
	}

	/** 绘制玩家的动作 */
	function draw_act(rel_pos,act){
		ctx = get_ctx(#gmcanvas)
		act_string = match(act){
			case {peng}: "PUNG"
			case {gang}: "KONG"
			case {gang_self}: "KONG"
			case {hoo}: "HOOO"
			default: "----"
		}
		
		Canvas.save(ctx);
		Canvas.set_fill_style(ctx,RED);
		Canvas.set_text_align(ctx,{align_center});
		Canvas.set_font(ctx,"normal bold 24px serif");
		match(rel_pos){
			case 3: {
				draw_dialog(ctx,3);
				Canvas.fill_text(ctx,"{act_string}",530,275) 
			}
			case 2: {
				draw_dialog(ctx,2);
				Canvas.fill_text(ctx,"{act_string}",370,120)
			}
			case 1: {
				draw_dialog(ctx,1);
				Canvas.fill_text(ctx,"{act_string}",210,275)
			}
			default: {
				draw_dialog(ctx,0);
				Canvas.fill_text(ctx,"{act_string}",370,440)
			}
		}		
		Canvas.restore(ctx);
	}

	function draw_win(rel_pos){
		ctx = get_ctx(#gmcanvas);
		match(rel_pos){
			case 3: Canvas.draw_image(ctx,get("win.png"),478,225); 
			case 2: Canvas.draw_image(ctx,get("win.png"),320,50);
			case 1: Canvas.draw_image(ctx,get("win.png"),160,225);
			case _: Canvas.draw_image(ctx,get("win.png"),320,390);
		}
	}

	/** 绘制剩余时间 */
	function draw_left_time(ctx,i){
		Canvas.save(ctx);
		Canvas.set_fill_style(ctx,RED);
		Canvas.set_font(ctx,"normal bold 24px serif");
		Canvas.set_text_align(ctx,{align_center});
		Canvas.set_text_baseline(ctx,{middle});
		Canvas.fill_text(ctx,"{i}",370,277);
		Canvas.restore(ctx);
	}

	/**----------------------------------------------**/
	/**
	* 收到起牌消息后的动作  
	*/
	function recv_discard_msg(msg){
		//如果当前玩家弃的牌与服务器弃的牌不一致，则需要刷新手牌
		game = get_game(); 
		game = if(msg.index == game.idx){
			match(game.curr_card){
				case {none}:  {game with deck: Game.get_player_deck(game.id,game.player)}
				case ~{some}: {
					if(some == msg.card) game else {
						{game with deck: Game.get_player_deck(game.id,game.player)}
					}	
				}
			}
		}else game

		set_game({game with curr_card: some(msg.card), status: {wait_for_resp}})
	}
	
	/**
	* 弃牌
	*/
	function discard(card){
		game = get_game();
		deck = Board.discard_card(game.deck,card);
		is_ting = Board.is_ting(deck.handcards);
		set_game({game with curr_card: some(card), status:{wait_for_resp}, ~deck, ~is_ting});
	}

	/**
	* 根据收到的game_msg更新游戏
	*/
	function update(game_msg){
		game = {get_game() with 
			status: 		decode_status(game_msg.st),
			curr_turn: 		game_msg.ct,
			curr_card: 		game_msg.cc,
			ready_flags:	game_msg.rf,
			players: 		game_msg.pls,
			decks: 			game_msg.dks,
			discards: 		game_msg.dcs,
			pile_info: 		game_msg.pf
		};
		set_game(game);	
	}

	function update_deck(){
		game = get_game();
		game = {game with deck: Game.get_player_deck(game.id,game.player)}
		set_game(game);
	}

	function set_player(player){
		set_game({get_game() with player: player, idx: player.idx});
	}

	function set_deck(deck){
		set_game({get_game() with deck: deck});
	}
		
	/** 玩家起到牌后是否能够有所动作，即杠/胡 */
	function get_action_flag(){
		game = get_game();
		if(game.curr_turn != game.idx) 0 else {
			opt_flag = if(Board.can_gang_self(game.deck)) 4 else 0
			if(Board.can_hoo_self(game.deck)) opt_flag + 2 else opt_flag
		}
	}
	
	/** 能否对所出的牌作出响应，即能碰/杠/胡 */
	function get_resp_flag(){
		game = get_game();
		if(game.curr_turn == game.idx) 0 else {
			match(game.curr_card){
				case {none}: 0
				case ~{some}: {
					opt_flag = if(Board.can_peng(game.deck,some)) 9 else 1
					opt_flag = if(Board.can_gang(game.deck,some)) opt_flag + 4 else opt_flag
					if(Board.can_hoo_card(game.deck,some)) opt_flag + 2 else opt_flag
				}
			}
		}
	}
}
