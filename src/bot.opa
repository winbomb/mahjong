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

server module Bot {
	
	function call(game,idx){
		match(LowLevelArray.get(game.players,idx)){
		case  {none}: Mahjong.request_action(game.id,idx,{no_act});
		case ~{some}: {
			card = Option.get(game.curr_card);
			deck = LowLevelArray.get(game.board.decks,idx);
			//如果能胡，胡之
			if(Board.can_hoo_card(deck,card)) Mahjong.request_action(game.id,idx,{hoo}) else{
				//如果能杠，则杠之
				if(Board.can_gang(deck,card)) Mahjong.request_action(game.id,idx,{gang}) else {
					//如果能碰，考虑之
					if(Board.can_peng(deck,card)){
						cards = List.sort_with(Card.compare,deck.handcards);
						jong_cnt = jong_cnt(cards);
						if(Card.is_jong(card) && jong_cnt <= 1){
							Mahjong.request_action(game.id,idx,{no_act});
						}else{
							match(in_use(cards,card)){
							case  {true}: Mahjong.request_action(game.id,idx,{no_act});
							case {false}: Mahjong.request_action(game.id,idx,{peng});
							}
						}
					}else Mahjong.request_action(game.id,idx,{no_act});
				}
			}
		}}
	}

	function play(game,idx){
		deck = LowLevelArray.get(game.board.decks,idx);
		//如果能胡，胡之
		if(Board.can_hoo_self(deck)) Mahjong.request_action(game.id,idx,{hoo}) else {
			//如果能杠，杠之
			if(Board.can_gang_self(deck)) Mahjong.request_action(game.id,idx,{gang}) else{
				//否则从handcards里面选一张牌弃掉
				cards = List.sort_with(Card.compare,deck.handcards);
				jong  = select_jong(cards);
				cards = match(jong){
					case  {none}: cards
					case ~{some}: Board.filter_pair(cards,some)
				}
				groups = split(cards);								

				match(find_single(groups,jong)){
				case ~{some}: Mahjong.request_action(game.id,idx,{discard:some}); 
				case  {none}:{
					match(decide(groups,jong)){
					case ~{some}: Mahjong.request_action(game.id,idx,{discard:some});
					case  {none}: {
						jlog("WARN: random selection!");
						idx = Random.int(List.length(cards));
						Mahjong.request_action(game.id,idx,{discard: Option.get(List.get(idx,cards))});
					}}
				}}								
			}
		}
	}

	function in_use(cards,card){
		//TODO
		{false}
	}

	function jong_cnt(cards){
		List.foldi(function(i,c,cnt){
			pp = get_point(cards,i-1);
			np = get_point(cards,i+1);
			if(i <= List.length(cards)-1 && np == c.point && pp != c.point && Card.is_jong(c)){
				cnt + 1;
			}else cnt
		},cards,0);
	}
	
	//从组牌中随机选择一张
	function rand_pick(cards){
		n = List.length(cards);
		if(n == 0) {none} else List.get(Random.int(n),cards);
	}
	
	function get_point(cards,idx){
		if(idx <= -1) -99 else {
			if(idx >= List.length(cards)) 99 else{
				match(List.get(idx,cards)){
					case  {none}: 0
					case ~{some}: some.point
				}
			}
		}
	}

	function get_suit(cards,idx){
		if(idx <= -1 || idx >= List.length(cards)) {none} else{
			match(List.get(idx,cards)){
			case {none}: {none}
			case {some:c}: some(c.suit)
			}
		}
	}

	//  
	function find_shun(cards){
		n = List.length(cards);
		List.foldi(function(i,c,result){
			if(result != {none}) result else {
				nnp = get_point(cards,i+2); //next next point
				np  = get_point(cards,i+1); //next point
				cp  = c.point;				//current point
				if(i <= n-2 && np == cp+1 && nnp == cp+2){
					shun = {card1:c,card2:Option.get(List.get(i+1,cards)),card3:Option.get(List.get(i+2,cards))}
					some(shun)
				}else result
			}
		},cards,{none});
	}

	function find_ke(cards){
		n = List.length(cards);
		List.foldi(function(i,c,result){
			if(result != {none}) result else {
				nnp = get_point(cards,i+2); //next next point
				np  = get_point(cards,i+1); //next point
				cp  = c.point;				//current point
				if(i <= n-2 && np == cp && nnp == cp){
					ke = {card1:c,card2:Option.get(List.get(i+1,cards)),card3:Option.get(List.get(i+2,cards))}
					some(ke)
				}else result
			}
		},cards,{none});
	}

	function find_jong(cards){
		n = List.length(cards);
		List.foldi(function(i,c,jong){
			pp = get_point(cards,i-1);
			np = get_point(cards,i+1);
			if(i <= n-1 && np == c.point && pp != c.point && Card.is_jong(c)){
				some({card1:c,card2:Option.get(List.get(i+1,cards))});
			}else jong
		},cards,{none});
	}

	function select_jong(cards){
		groups = split(cards);
		result = List.fold(function(g,result){
			if( List.length(g) <= 1 || (result.jong != {none} && result.left == 0)) result else {
				match(find_jong(g)){
				case  {none}: result
				case {some:jong}: {
					if(List.length(g) == 2) {jong:some(jong),left:0} else {
						left = find(Board.filter_pair(g,jong));  //
						if(result.jong == {none} || result.left > List.length(left)){
							{jong:some(jong),left:List.length(left)}
						}else result
					}
				}}				
			}
		},groups,{jong:{none},left:0});
		
		result.jong;
	}

	function find(cards){
		if(List.length(cards) <= 2) cards else {
			best1 = match(find_shun(cards)){
				case  {none}: cards
				case ~{some}: find(Board.filter_group(cards,some))
			}

			best2 = match(find_ke(cards)){
				case  {none}: cards
				case ~{some}: find(Board.filter_group(cards,some))
			}

			if(List.length(best1) <= List.length(best2)) best1 else best2
		}
	}
	
	function choose(cards,jong){
		if(List.length(cards) == 0) {none} else {
			match(jong){
			case {some:_}: rand_pick(cards);
			case {none}:{
				n = List.length(cards);
				List.foldi(function(i,c,card){
					if(card != {none}) card else{
						if(not(Card.is_jong(c)) || (i == n-1 && card == {none})) some(c) else card
					}
				},cards,{none});	
			}}
		}					
	}

	function decide(groups,jong){
		tg1 = List.filter(function(g){mod(List.length(g)-1,3) == 0},groups); //4,7,10,13
		cands1 = List.fold(function(g,c){
			List.append(find(g),c);			
		},tg1,[]);

		if(List.length(cands1) >= 1) choose(cands1,jong) else {	
			tg2 = List.filter(function(g){mod(List.length(g),3) == 0},groups); //3,6,9,12
			cands2 = List.fold(function(g,c){
				left = find(g);
				if(List.length(left) == 0) c else List.append(left,c);
			},tg2,[]);

			if(List.length(cands2) >= 1) choose(cands2,jong) else {
				tg3 = List.filter(function(g){mod(List.length(g)+1,3) == 0},groups);
				cands3 = List.fold(function(g,c){
					List.append(find(g),c);
				},tg3,[]);
				choose(cands3,jong);
			}			
		}
	}

	function split(cards){
		result = List.foldi(function(i,c,result){
			same_suit = match(get_suit(cards,i+1)){
				case  {none}: {false}
				case ~{some}: some == c.suit
			}
			if(i >= List.length(cards)-1 || get_point(cards,i+1) - c.point > 1 || not(same_suit)){
				group = List.filteri(function(j,c){j >= result.last_idx && j <= i},cards); 
				{result with groups: group +> result.groups, last_idx: i+1}
			}else result
		},cards,{groups:[],last_idx:0});
		result.groups;
	}

	//寻找孤立的牌（与左右其他牌点数相差2以上）
	function find_single(groups,jong){
		cands = List.fold(function(g,s){
			if(List.length(g) != 1) s else List.head(g) +> s
		},groups,[]);

		if(List.length(cands) == 0) {none} else choose(cands,jong)
	}
}

module TestBot {
	suits = {
		//test_find_single();
		//test_split();
		//test_decide();
		//test_find();
		//test_select_jong();
	}

	function test_find_single(){
		
		HANDS = ["3W","3W","4W","5W","7W","4B","5B","6B","1T","2T","4T","5T","8T","8T"];
		deck  = List.fold(function(p,c){ TestUtil.trans_card(p) +> c },HANDS, []);
		cards = List.sort_with(Card.compare,deck);
		groups = Bot.split(cards);	

		result = Bot.find_single(groups,{none});
		jlog("result = {result}");
	}

	function test_split(){
		jlog("test split tiles");
		TILES = ["1W","2W","4W","5W","6W","8W","9W","4B","5B","6B","6B","7T","8T"];
		cards = List.fold(function(p,c){ TestUtil.trans_card(p) +> c },TILES, []);
		cards = List.sort_with(Card.compare,cards);	
			
		result = Bot.split(cards);
		jlog("result count = {List.length(result)}");
		List.iter(function(part){
			jlog("Part: {part}");
		},result);
	}

	function test_decide(){
		jlog("test decide");
		GROUPS = [["2W","2W","3W","4W","5W","6W","7W","8W","9W"],["2T","3T","4T","4T","5T"]];
		input = List.fold(function(g,input){
			cards = List.fold(function(p,c){ TestUtil.trans_card(p) +> c },g, []);
			cards = List.sort_with(Card.compare,cards);
			cards +> input
		},GROUPS,[]);

		result = Bot.decide(input,{none});
		jlog("result = {result}");
	}

	function test_find(){
		jlog("test find");
		TILES = ["2W","2W","3W","4W","5W","6W","7W"];
		cards = List.fold(function(p,c){ TestUtil.trans_card(p) +> c },TILES, []);
		cards = List.sort_with(Card.compare,cards);	

		result = Bot.find(cards);
		jlog("result = {result}");
	}

	function test_select_jong(){
		jlog("test select jong");
		TILES = ["5B","6B","7B","2T","2T","3T","4T","2W","3W","5W","5W","6W","8W","8W"];
		cards = List.fold(function(p,c){ TestUtil.trans_card(p) +> c },TILES, []);
		cards = List.sort_with(Card.compare,cards);	

		result = Bot.select_jong(cards);
		jlog("result = {result}");
	}
}
