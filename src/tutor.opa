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

 module Tutor {
	OK_POS = [{x:500,y:455},{x:530,y:485},{x:505,y:408},{x:465,y:175},{x:420,y:295},
			  {x:545,y:425},{x:590,y:410},{x:470,y:280}]
	
	TIPS = ["t1_1","t1_2","t2_1","t2_2","t2_3","t3_1","t4_1","t4_2"];

	g_step = Mutable.make(int 0);

	client function refresh(){
		ctx = get_ctx(#ttcanvas);
		Canvas.clear_rect(ctx,0,0,760,650);
		
		step = g_step.get();
		draw_bg(ctx,step);
		draw_tip(ctx,step);
		draw_ok(ctx,step);
	}
	
	function draw_bg(ctx,step){
		img = if(step <= 1) "t1_0" else {
			if(step <= 4) "t2_0" else{
				if(step <= 5) "t3_0" else "t4_0";
			}
		}
		Canvas.draw_image(ctx,get("tutor/" ^ img ^ ".png"),0,0);
	}

	function draw_tip(ctx,step){
		if(step <= -1 || step >= List.length(TIPS)) void else {
			tip = Option.get(List.get(step,TIPS));
			Canvas.draw_image(ctx,get("tutor/" ^ tip ^ ".png"),0,0);
		}
	}

	function draw_ok(ctx,step){
		if(step <= -1 || step >= List.length(OK_POS)) void else {
			pos = Option.get(List.get(step,OK_POS));
			Canvas.draw_image(ctx,get("tutor/btn_ok.png"),pos.x,pos.y);
		}
	}
	
	function handle(event){
		step = g_step.get();
		if(step <= -1 || step >= List.length(OK_POS) - 1) void else{
			// 获得鼠标点击事件在画布上的坐标 
			canvas_pos = Dom.get_position(#ttcanvas);
			mouse_pos = event.mouse_position_on_page;	
			x = mouse_pos.x_px - canvas_pos.x_px;
			y = mouse_pos.y_px - canvas_pos.y_px;
			
			tg = Option.get(List.get(step,OK_POS));
			if(Button.bound(~{x,y},tg.x,tg.y,72,42)){
				g_step.set(step+1);
			}
		}
		refresh();
	}

	function page_ready(){
		imgs = ["tutor/t1_0.png","tutor/t1_1.png","tutor/t1_2.png","tutor/t2_0.png","tutor/t2_1.png","tutor/t2_2.png",
				"tutor/t2_3.png","tutor/t3_0.png","tutor/t3_1.png","tutor/t4_0.png","tutor/t4_1.png","tutor/t4_2.png",
				"tutor/btn_ok.png"];
		preload(imgs,[],function(){
			g_step.set(0);
			refresh();	
			Dom.remove(#gmloader);
		});
	}

	function page_view(){
		Resource.styled_page("China Mahjong Tutorial",["/resources/style.css"],
			<>
			<div style="margin-top:20px" onready={function(_){page_ready()}}>
				<div class="canvas">
			  		<div id=#gmloader >
						<p id=#loading_info>loading</p>
					</div>
			  		<canvas id=#ttcanvas width="757" height="647"
						onmousedown={function(event){ handle(event) }}>
						"Your browser does not support html5 canvas element."
					</canvas>
				</div>
			</div>
			</>
		);
	}

	function show_tutor(){
		ignore(Client.winopen("/tutor",{_blank},[],{true}));		
	}
 }
