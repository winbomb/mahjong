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

type pos = {
	int x,
	int y
}

type rect = {
	int x,
	int y,
	int w,
	int h, 
}

type Button.t = {
	rect rect,                      //位置
	option(Image.image) bg_img,     //背景
	string text,                    //文本
	bool is_enable,                 //是否可用 
}

module Button {

	/**
	* 默认按钮，没有背景
	*/
	function Button.t simple(x,y,w,h,text)
	{
		{rect:~{x,y,w,h},bg_img:{none},~text,is_enable:{true}}
	}

	function Button.t create(x,y,w,h,bg_img,text)
	{
		{rect:~{x,y,w,h},bg_img:{some(bg_img)},~text,is_enable:{true}}
	}

	function set(button,is_enable)
	{
		{button with is_enable:is_enable}
	}

	/**
	* 是否点击了
	*/
	function is_pressed(pos,button)
	{
		rect = button.rect;
		bound(pos,rect.x,rect.y,rect.w,rect.h);		
	}

	function bool bound(pos p,int x,int y,int w,int h)
	{
		p.x >= x && p.x <= x+w && p.y >= y && p.y <= y+h;
	}

	function draw(ctx,button){
		Canvas.save(ctx);
		r = button.rect;
		
		border_color = if(button.is_enable) {color: Color.rgb(28,81,128)} else {color:Color.rgb(100,100,100)}
		fill_color = if(button.is_enable) {color: Color.rgb(198,210,162)} else {color:Color.rgb(200,200,200)}
		
		Canvas.set_stroke_style(ctx,border_color);
		Canvas.set_line_width(ctx,3.0);
		Canvas.stroke_rect(ctx,r.x,r.y,r.w,r.h);

		Canvas.set_fill_style(ctx,fill_color);
		Canvas.fill_rect(ctx,r.x,r.y,r.w,r.h);
				
		Canvas.set_fill_style(ctx,Render.BLACK);
		Canvas.set_text_align(ctx,{align_center});
		Canvas.set_text_baseline(ctx,{middle});
		Canvas.set_font(ctx,"normal bold 20px serif");
		Canvas.fill_text(ctx,button.text,r.x+r.w/2,r.y+r.h/2);
		
		Canvas.restore(ctx);
	}
}
