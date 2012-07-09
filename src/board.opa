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

/** 一对牌 */
type Pair.t = {
	Card.t card1,
	Card.t card2
}

/** 一游牌 */
type Group.t = {
	Card.t card1,
	Card.t card2,
	Card.t card3
}

/**
* 牌面的定义 
*/
type Board.t = {
	int start_pos,                     //开始起牌的位置
	int curr_pos,                      //现在牌起到的位置
	list(Card.t) card_pile,            //牌堆 
	llarray(Discard.t) discards,       //玩家的弃牌，依次为东/南/西/北
	llarray(Deck.t) decks,             //玩家的牌，依次为东/南/西/北
	llarray(llarray(int)) pile_info,   //玩家面前牌堆的情况 
}

module Board {
	
	PILE_BASE = [0,28,54,82]
	DEBUG = {false}
	
	/** 将的定义 */
	GENERALS = [{point:2,suit:{Wan}},{point:5,suit: {Wan}},{point:8,suit: {Wan}},
		 	   {point:2,suit:{Tiao}},{point:5,suit:{Tiao}},{point:8,suit:{Tiao}},
			   {point:2,suit:{Bing}},{point:5,suit:{Bing}},{point:8,suit:{Bing}}]
	
	/**
	* 创建一个空的牌面 
	*/
	function Board.t create(){
		suits = [{Bing},{Tiao},{Wan}];
		points = [1,2,3,4,5,6,7,8,9];

		//创建了一个空的108张牌 
		card_pile = List.foldi(function(i,suit,card_pile){
			base_point = i*36
			List.fold(function(point,card_pile){
				id = base_point + (point - 1) * 4;
				card_pile = {~point,~suit,id:id+1} +> card_pile;
				card_pile = {~point,~suit,id:id+2} +> card_pile;
				card_pile = {~point,~suit,id:id+3} +> card_pile;
				{~point,~suit,id:id+4} +> card_pile;
			},points,card_pile);
		},suits,[]);
		
		card_pile = shuffle(card_pile,100);

		{start_pos: 0,
		 curr_pos:  0,
		 card_pile: card_pile,
		 discards:  LowLevelArray.create(4,[]),
		 decks:     LowLevelArray.create(4,Card.EMPTY_DECK),
		 pile_info: init_pile()
		 }	
	}

	function init_pile(){
		LowLevelArray.init(4)(function(n){
			len = if(n == 0 || n == 2) 14 else 13
			LowLevelArray.create(len,2);
		});
	}

	/**
	* 获得某个玩家的牌  
	* @place Place.t
	*/
	function get_player_deck(board,player){
		if(player.idx >= 0 && player.idx <= 3) LowLevelArray.get(board.decks,player.idx) else Card.EMPTY_DECK
	}
	
	/**
	* 准备牌面
	*/
	function prepare(board){
		//先随机选一个开牌的点
		//rand = Random.int(54) * 2;
		rand = 0
		board = {{board with start_pos: rand} with curr_pos: rand}

		//每个人发13张牌，庄家发14张
		if(not(DEBUG)){
			board = deal_round_n(board,13);
			deal_card(board,0) |> sort(_);
		}else{
			TestUtil.prepare(board) |> sort(_)
		}
	}

	/**
	* 判断一副牌能否胡 
	*/
	function can_hoo_card(deck,card){
		cards = List.add(card,deck.handcards);
		can_hoo(cards)
	}

	/**
	* 判断是否听牌 
	*/
	both function is_ting(cards){
		//遍历27张牌，还能不能胡，能胡的话就听了
		points = [1,2,3,4,5,6,7,8,9]
		suits = [{Bing},{Tiao},{Wan}]
		List.fold(function(point,is_ting){
			if(is_ting) {true} else {
				List.fold(function(suit,is_ting){
					if(is_ting) {true} else {
						can_hoo({id: -1, ~point, ~suit} +> cards);
					}
				},suits,is_ting);
			}
		},points,{false});
	}
	
	/**
	* 判断能否碰 
	* 如果自己牌面内有两张和card一样的牌，则返回true
	*/
	function can_peng(deck,card){
		find_card_count(deck,card) >= 2
	}
	
	/**
	* 判断能否杠（杠别人打出的牌,不包括自己摸到牌后的动作）
	*/
	function can_gang(deck,card){
		find_card_count(deck,card) >= 3		 
	}
	
	/** 判断自己摸到牌后是否能杠 */
	function can_gang_self(deck){
		//检查自己的手牌中是否有跟已经做成的牌组成杠的机会
		can_gang = List.fold(function(pattern,can_gang){
			if(can_gang) can_gang else {
				match(pattern.kind){
					case {Peng}: {
						card = List.head(pattern.cards);
						List.exists(function(c){c.point == card.point && c.suit == card.suit},deck.handcards);
					}
					default: {false}
				}
			}
		},deck.donecards,{false});

		//检查自己的手牌中是否有4张一样的牌
		if(can_gang) {true} else {
			List.fold(function(card,self_gang){
				if(self_gang) self_gang else {
					//检查这张牌在牌堆中有几张
					cards = List.filter(function(c){c.point == card.point && c.suit == card.suit},deck.handcards);
					List.length(cards) == 4
				}
			},deck.handcards,{false});
		}
	}
	
	/** 是否自摸 */
	function can_hoo_self(deck){
		can_hoo(deck.handcards);
	}

	/** 检查一副牌的手牌能否胡牌 */
	function can_hoo(handcards){
		//首先检查手牌中是否存在 2/5/8 的将
		if(not(has_general(handcards))) {false} else {
			//找到将 
			generals = find_general(handcards);
			List.fold(function(general,can_hoo){
				if(can_hoo) can_hoo else {
					//cards为去掉两张将牌之后的牌
					cards = filter_pair(handcards,general);
					
					//检查去掉两张将牌之后的牌是否符合胡的模式
					//wans,tiaos,bings本别表示万/条/饼的个数，它们必须为3的倍数才能胡（不胡7对） 
					wans =  List.filter(function(c){c.suit == {Wan}},cards);
					tiaos = List.filter(function(c){c.suit == {Tiao}},cards);
					bings = List.filter(function(c){c.suit == {Bing}},cards);
					if(mod(List.length(wans),3) == 0 
							&& mod(List.length(tiaos),3) == 0 && mod(List.length(bings),3) == 0){
						match_pattern(wans) && match_pattern(tiaos) && match_pattern(bings)
					}else {false}
				}
			},generals,{false});
		}
	}
	
	/** 检查一组牌（不包括将牌和已经成了的牌）是否符合胡的模式 */
	function match_pattern(cards){
		if(List.length(cards) == 0) {true} else {
			cards = List.sort_with(Card.compare,cards);
			min_card = List.head(cards);
			match(find_xxx(min_card,cards)){
				case ~{some}: match_pattern(filter_group(cards,some))
				case {none}: {
					match(find_xyz(min_card,cards)){
						case ~{some}: match_pattern(filter_group(cards,some))
						case {none}:  {false}
					}
				}
			}
		}
	}

	/** 从一组牌中找出一对将牌  */
	function find_general(cards){
		List.fold(function(general,result){
			pair = List.fold(function(c,pair){
				if(List.length(pair) == 2) pair else {
					if(c.point == general.point && c.suit == general.suit) List.add(c,pair) else pair
				}
			},cards,[])

			if(List.length(pair) != 2) result else {
				{card1: Option.get(List.get(0,pair)), card2: Option.get(List.get(1,pair))} +> result
			}
		},GENERALS,[]);
	}
	
	/** 从一组牌cards中找到以card为底的xxx的模式  例如：3万/3万/3万 */
	function find_xxx(card,cards){
		result = List.fold(function(c,result){
			if(c.suit == card.suit && c.point == card.point){
				c +> result
			} else result
		},cards,[]);

		if(List.length(result) <= 2) {none} else {
			group = {card1: Option.get(List.get(0,result)),
			 		 card2: Option.get(List.get(1,result)),
			 		 card3: Option.get(List.get(2,result))}
			some(group);
		}
	}
	
	/** 从一组牌cards中找到以card为底的xyz的模式, 例如: 3万/4万/5万   */
	function find_xyz(card,cards){
		card1 = card
		card2 = List.find(function(c){c.suit == card.suit && c.point == card.point + 1},cards);
		card3 = List.find(function(c){c.suit == card.suit && c.point == card.point + 2},cards);

		match((card2,card3)){
			case ({some:card2},{some:card3}): some(~{card1,card2,card3})
			default: {none}
		}
	}
	
	/**
	* 找到一副手牌中可以杠的选择，返回一个pattern的数组 
	*/
	function find_gangs(deck){
		//首先找到可以与已碰牌组成杠的机会 
		gangs = List.fold(function(done,gangs){
			if(done.kind != {Peng}) gangs else {
				//如果手牌中存在能和已经碰的牌形成杠的牌的话 
				gang_card = List.head(done.cards);
				card = List.find(function(c){
					c.point == gang_card.point && c.suit == gang_card.suit
				},deck.handcards)

				match(card){
					case {none}:  gangs
					case ~{some}: {
						pattern = {
							kind:   {Soft_Gang},
							cards:  some +> done.cards,
							source: done.source
						}
						pattern +> gangs
					}
				}
			}
		},deck.donecards,[]);

		//然后找到手牌中的杠
		List.fold(function(card,gangs){
			cards = List.filter(function(c){
				c.point == card.point && c.suit == card.suit && c.id >= card.id
			},deck.handcards);

			if(List.length(cards) != 4) gangs else {
				pattern = {
					kind:   {Hard_Gang},
					cards:  cards,
					source: -1
				}
				pattern +> gangs
			}
		},deck.handcards,gangs); 
	}

	private function filter_group(cards,group){
		List.filter(function(c){
			c.id != group.card1.id && c.id != group.card2.id && c.id != group.card3.id
		},cards);
	}

	private function filter_pair(cards,pair){
		List.filter(function(c){
			c.id != pair.card1.id && c.id != pair.card2.id
		},cards);
	}

	function has_general(cards){
		List.fold(function(general,has_general){
			if(has_general) has_general else {
				count = List.fold(function(c,count){
					if(c.point == general.point && c.suit == general.suit) count + 1 else count
				},cards,0);
				count >= 2
			}
		},GENERALS,{false});
	}
	
	function find_card_count(deck,card){
		List.fold(function(c,count){
			if(c.point == card.point && c.suit == card.suit) count + 1 else count
		},deck.handcards,0);
	}

	/**
	* 发n圈牌
	*/
	function deal_round_n(board,n){
		match(n){
			case 0: board;
			case x: {
				board = deal_round(board);
				deal_round_n(board,x-1);
			}
		}
	}

	/**
	* 发一圈牌
	*/
	function Board.t deal_round(Board.t board){
		LowLevelArray.foldi(function(i,_,board){
			deal_card(board,i);
		},board.decks,board);
	}

	/**
	* 给某个方位的玩家发一张牌 
	*/
	function deal_card(board,idx){
		deck = LowLevelArray.get(board.decks,idx);
		
		card = List.head(board.card_pile);
		handcards = List.rev(deck.handcards) |> List.add(card,_) |> List.rev(_); //把这张牌添加到牌尾 
		deck = {deck with handcards: handcards}
		LowLevelArray.set(board.decks,idx,deck);
		
		board = {board with pile_info: update_pile(board.pile_info,board.curr_pos)}
		board = {board with curr_pos:  mod(board.curr_pos + 1,108)}
		{board with card_pile: List.drop(1,board.card_pile)}
	}
	
	/**
	* 从杠头取一张牌给某个玩家 
	*/
	function deal_card_backwards(board,idx){
		deck = LowLevelArray.get(board.decks,idx);

		n = List.length(board.card_pile);
		card = Option.get(List.get(n-1,board.card_pile));
		handcards = List.rev(deck.handcards) |> List.add(card,_) |> List.rev(_);
		deck = {deck with handcards: handcards}
		LowLevelArray.set(board.decks,idx,deck);

		board = {board with pile_info: update_pile(board.pile_info,mod(board.curr_pos + n,108))}
		{board with card_pile: List.remove(card,board.card_pile)}
	}

	function update_pile(pile_info,pos){
		//首先获得要更新谁的牌面
		idx = List.fold(function(n,idx){
			if(pos >= n) idx + 1 else idx
		},PILE_BASE,-1);
		
		pile_num = (pos - Option.get(List.get(idx,PILE_BASE))) / 2;

		info = LowLevelArray.get(pile_info,idx);
		new_val = LowLevelArray.get(info,pile_num) - 1;
		LowLevelArray.set(info,pile_num,new_val); 

		pile_info
	}
	
	/**  
	* 从手牌中弃掉一张牌
	*/
	server function discard(board,idx,card){
		deck = discard_card(LowLevelArray.get(board.decks,idx),card)
		LowLevelArray.set(board.decks,idx,deck);
		board
	}
	
	/**
	* 将弃牌加入到玩家的弃牌区
	*/
	server function add_to_discards(board,idx,card){
		discard = LowLevelArray.get(board.discards,idx);
		LowLevelArray.set(board.discards,idx,card +> discard);
		board
	}
	
	/**
	* 从Deck中弃掉一张牌，如果牌不在deck中，则返回原来的deck
	*/
	both function discard_card(deck,card){
		handcards = List.filter(function(c){c.id != card.id},deck.handcards);
		if(List.length(handcards) == List.length(deck.handcards)){
			Log.warning("Board","Try to discard an unexist card {card} from deck {deck.handcards}");
		}
		{deck with handcards: List.sort_with(Card.compare,handcards)}
	}
	
	/**
	* 玩家碰牌 
	*/
	function peng(game,idx,card){
		deck = LowLevelArray.get(game.board.decks,idx);
		peng_cards = List.fold(function(c,peng_cards){
			if(List.length(peng_cards) == 3) peng_cards else {
				if(c.point == card.point && c.suit == card.suit){
					c +> peng_cards
				}else peng_cards
			}
		},deck.handcards,[card]);

		pattern = create_pattern({Peng},peng_cards,game.curr_turn);
		deck = {deck with donecards: pattern +> deck.donecards}

		handcards = List.filter(function(c){ 
			not(List.exists(function(d){d.id == c.id},peng_cards));
		},deck.handcards);
		deck = {deck with handcards: handcards}

		LowLevelArray.set(game.board.decks,idx,deck)
		game.board
	}

	function gang(game,idx,card){
		deck = LowLevelArray.get(game.board.decks,idx);
		gang_cards = List.fold(function(c,gang_cards){
			if(List.length(gang_cards) == 4) gang_cards else {
				if(c.point == card.point && c.suit == card.suit){
					c +> gang_cards
				}else gang_cards
			}
		},deck.handcards,[card]);

		pattern = create_pattern({Soft_Gang},gang_cards,game.curr_turn);
		deck = {deck with donecards: pattern +> deck.donecards}

		handcards = List.filter(function(c){ 
			not(List.exists(function(d){d.id == c.id},gang_cards));
		},deck.handcards);

		//TODO:从杠头上取一张加到handcards中	
		deck = {deck with handcards: handcards}
		LowLevelArray.set(game.board.decks,idx,deck)
		deal_card_backwards(game.board,idx);
	}

	function create_pattern(kind,cards,source){
		~{kind,cards,source}
	}
	
	/**
	* 打乱牌的顺序 
	*/
	function list(Card.t) shuffle(list(Card.t) l,int n)
	{
		match(n){
			case 0: l
			case x: {
				l = s(l);
				shuffle(l,x-1);
			}
		}
	}

	private function list s(list l){
		head = List.head(l);
		l = List.drop(1,l);
		int r = Random.int(List.length(l)+1);
		List.insert_at(head,r,l);	
	}
	
	/**
	* 排序某个牌面所有玩家的手牌 
	*/
	function sort(board){
		LowLevelArray.foldi(function(i,deck,board){
			deck = {deck with handcards: List.sort_with(Card.compare,deck.handcards)}
			LowLevelArray.set(board.decks,i,deck);
			board
		},board.decks,board);
	}

	/** 获得4个玩家以作成的牌 */
	/** function get_donecards(board){
		LowLevelArray.init(4)(function(n){
			deck = LowLevelArray.get(board.decks,n);
			deck.donecards
		});
	}*/
	
	/**
	* 获得
	*/
	function get_decks(board,flag){
		LowLevelArray.init(4)(function(n){
			deck = LowLevelArray.get(board.decks,n);
			if(flag == {true}) deck else{
				{deck with handcards: []}
			}
		});
	}
	
	/**
	* 获得前一个玩家的坐标 
	*/
	function get_prev_idx(idx){
		mod(idx + 3,4)
	}
	
	/**
	* 获得下一个玩家的坐标
	*/
	function get_next_idx(idx){
		mod(idx + 1,4)
	}
	
	/**
	* 获得对家的坐标
	*/
	function get_oppt_idx(idx){
		mod(idx + 2,4)
	}

	/**
	* 获得tg_player相对与src_player的位置
	* 0：自己 1：左边 2：对家 3：右边
	*/
	function get_rel_pos(src_idx,tg_idx){
		mod(src_idx - tg_idx + 4,4)
	}

	function idx_to_place(idx){
		match(idx){
			case 0: "East"
			case 1: "South"
			case 2: "West"
			case 3: "North"
			case _: "Unset"
		}
	}
}


/**
* 花色的定义  
*/
type Suit.t =  {Bing}  //饼
			or {Tiao}  //条
			or {Wan}   //万

/**
* 麻将牌的定义
*/
type Card.t = {
	int    point,   //点数：1 ～ 9 
	Suit.t suit,    //花色
	int id,         //编号，用于排序 
}

/**
* 可以成为一游的模式的定义 
*/
type Pattern.kind =  {Straight}    //顺，  例如 3/4/5万 
				  or {Peng}        //三张，例如 三个3万
				  or {Soft_Gang}   //明杠
				  or {Hard_Gang}   //暗杠

type Pattern.t = {
	Pattern.kind kind,    //所属的模式
	list(Card.t) cards,   //牌
	int source,           //牌的来源（即是碰或杠哪家的牌） 
}

/** 弃牌类型定义：就是一组Card.t */
type Discard.t = list(Card.t)

/** 已成牌的类型定义 */
type Donecard.t = list(Pattern.t)

/** 手牌的类型定义：也是一组Card.t */
type Handcard.t = list(Card.t)

/**
* 玩家手中所拥有的一组牌的定义 
*/
type Deck.t = {
	Handcard.t  handcards, //手牌
	Donecard.t  donecards  //已经成了的牌
}

/**
* 麻将牌模块
*/
module Card {
	/** 空的手牌定义 */
	EMPTY_DECK = {handcards:[],donecards:[]}

	function compare(card1,card2){
		if(card1.id != -1 && card2.id != -1){
			if(card1.id >= card2.id) {gt} else {lt}
		} else {
			if(card1.point >= card2.point) {gt} else {lt}
		}
	}

	function to_string(card){
		point = "{card.point}"
		suit = match(card.suit){
			case {Wan}: "W"
			case {Tiao}: "T"
			case {Bing}: "B"
		}
		point ^ suit ^ "#{card.id}"
	}
}
