/**************************************************************************
*	"testbench.sv"
*	GameBoy SystemVerilog reverse engineering project.
*   Copyright (C) 2014 Sohil Shah
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU General Public License as published by
*   the Free Software Foundation, either version 3 of the License, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program.
*	
*	Contact Sohil Shah at sohils@cmu.edu with all questions. 
**************************************************************************/

`include "top.sv"

`timescale 1ns/100ps

/* 	Module Testbench: Testing environment for the design
*
*	Generates clock, reset, peripheral signals. Testing for any individual modules. 
*
*/
module testbench();

	logic	clk;
	logic	rst;
		
	logic joypad_up, joypad_down, joypad_right, joypad_left, joypad_a, joypad_b, joypad_start, joypad_select;
		
	top DUT (.*);
	vars	v ();
	
	initial begin
		rst <= '1;
		clk <= '0;
		#10;
		rst <= '0;
	end

	initial
		//	4.19 MHz clock
		forever #119.2 clk <= ~clk;
	
	initial
		forever @(posedge clk) $cast(v.instruc, DUT.dp.IR);
	
	initial
		forever @(posedge clk) v.cycles++;
	
	initial begin
		joypad_up = 1'b1;
		joypad_down = 1'b1;
		joypad_left = 1'b1;
		joypad_right = 1'b1;
		joypad_start = 1'b1;
		joypad_select = 1'b1;
		joypad_a = 1'b1;
		joypad_b = 1'b1;
		
		if ($test$plusargs("debug"))
			$monitor("State: %s			Iter: %d	| 	PC: %h 	IR: %s		(0x%h)	SP: %h	|Reset: %b \n	Registers {A B C D E H L} : {%h %h %h %h %h %h %h}   MAR: %h		MDR: %h	\n	Clock cycle (dec): %d    Condition codes {Z N H C} : {%b %b %b %b}\n\n", 
			DUT.dp.cp.curr_state.name, DUT.dp.cp.iteration, DUT.dp.PC, v.instruc.name, DUT.dp.IR, DUT.dp.SP, rst,
			DUT.dp.regA, DUT.dp.regB, DUT.dp.regC, DUT.dp.regD, DUT.dp.regE, DUT.dp.regH, DUT.dp.regL, DUT.dp.MAR, DUT.dp.MDR, v.cycles,
			DUT.dp.regF[3], DUT.dp.regF[2], DUT.dp.regF[1], DUT.dp.regF[0]);

	end
	
endmodule: testbench

// To be accessible from anywhere in design for debugging
module vars();
	std_instruction_t	instruc;
	int cycles;
endmodule: vars