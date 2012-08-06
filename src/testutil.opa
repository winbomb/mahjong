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

server module TestUtil {
	//四位玩家起到手的牌 (测试杠) 
	HANDCARDS_BAK1 =[["1W","1W","1W","2W","2W","2W","3W","3W","3W","4W","4W","4W","5W","6W"],
				["1B","1B","1B","1B","2B","2B","2B","2B","3B","3B","3B","3B","4B"],
				["1T","1T","1T","1T","2T","2T","2T","2T","3T","3T","3T","3T","4T"],
				["5W","8W","5W","5B","5B","5B","5T","5T","5T","6B","6B","6B","6B"]]
	
	//测试一炮多响
	HANDCARDS = [["1W","1W","1W","2W","2W","2W","3W","3W","3W","4W","4W","4W","5W","5W"],
				["1B","1B","1B","2B","2B","2B","3B","3B","3B","6W","7W","8B","8B"],
				["1T","1T","1T","2T","2T","2T","3T","3T","3T","6W","7W","8T","8T"],
				["1W","2W","3W","1B","2B","3B","1T","2T","3T","9B","9B","5W","5W"]]
	
	//测试听牌的bug
	HANDCARDS_BAK3 = [["8W","8W","8W","9B","9B","9B","6B","7B","8B","1T","2T","5T","5T","5T"],
				["1B","1B","1B","2B","2B","2B","3B","3B","3B","6W","7W","8B","8B"],
				["1T","1T","4T","2T","2T","4T","3T","3T","3T","6W","7W","8T","8T"],
				["1W","2W","3W","1B","2B","3B","1T","2T","3T","4B","4B","5W","5W"]]


	EMPTY_DECK  = {
		suits = [{Bing},{Tiao},{Wan}];
		points = [1,2,3,4,5,6,7,8,9];

		//创建了一个空的108张牌 
		List.foldi(function(i,suit,card_pile){
			base_point = i*36
			List.fold(function(point,card_pile){
				id = base_point + (point - 1) * 4;
				card_pile = {~point,~suit,id:id+1} +> card_pile;
				card_pile = {~point,~suit,id:id+2} +> card_pile;
				card_pile = {~point,~suit,id:id+3} +> card_pile;
				{~point,~suit,id:id+4} +> card_pile;
			},points,card_pile);
		},suits,[]);
	}

	RANDOM_PILE = {true} //是否使用随机牌堆

	CARD_PILE = ["9W","9W","9W","9W"];
	
	//记录转换了多少张某个牌，以确定id
	card_pile = Mutable.make(list(Card.t) EMPTY_DECK)

	//牌堆里的牌
	function prepare(board){
		card_pile.set(EMPTY_DECK)

		decks = LowLevelArray.mapi(board.decks)(function(i,deck){
			handcards = List.fold(function(c,cards){
				//c为类似"1W"这样的表示
				card = trans_card(c)
				card +> cards
			},Option.get(List.get(i,HANDCARDS)),[]);

			{deck with handcards: handcards}
		});

		left_cards = List.fold(function(p,c){
			trans_card(p) +> c
		},CARD_PILE,[]);
		//{board with ~decks, card_pile: left_cards}; //用CARD_PILE作为剩下的牌(用于快速结束游戏)
		{board with ~decks, card_pile: card_pile.get()}
	}
	
	/**
	*  将“1W”/“2T”这样的表示转换为card对象
	*/
	function trans_card(card_str){
		point = String.get(0,card_str) |> String.to_int(_);
		suit_str = String.get(1,card_str)
		suit = match(suit_str){
			case "W": {Wan}
			case "T": {Tiao}
			case "B": {Bing}
			default: {Wan}
		}
		
		card = List.find(function(c){
			c.point == point && c.suit == suit
		},card_pile.get())
		card = Option.get(card);

		card_pile.set(List.filter(function(c){
			c.id != card.id
		},card_pile.get()));

		card		
	}

	function show_cards(cards){
		List.fold(function(c,s){
			Card.to_string(c) +> s
		},cards,[]);
	}
}

/** module TestSuit {
	suits = {
		test_ting();
	}

	function test_ting(){
		pattern = ["8W","8W","8W","9B","9B","9B","6B","7B","8B","1T","2T","5T","5T"];
		cards = List.fold(function(p,c){
			TestUtil.trans_card(p) +> c
		},pattern,[]);
		jlog("{Board.is_ting(cards)}")
		//jlog("{Board.can_hoo({id:-1,point:3,suit:{Tiao}} +> cards)}")
	}
} */
