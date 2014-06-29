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

`include "datapath.sv"

`timescale 1ns/100ps

/* 	Module Testbench: Testing environment for the design on completion
*
*	WIP
*
*/
module testbench();

	logic	clk;
	logic	rst;
	
	logic [7:0] regA, regB, regC, regD, regE, regF, regH, regL;
	
	datapath DUT (.*);
	vars	v ();
	
	initial begin
		rst <= '1;
		clk <= '0;
		#10;
		rst <= '0;
	end

	initial
		//	4.19 MHz clock for simulation of real time
		forever #119.2 clk <= ~clk;
	
	initial
		forever @(posedge clk) $cast(v.instruc, DUT.IR);
	
	initial
		forever @(posedge clk) v.cycles++;
	
	initial begin

		
				$monitor("State: %s			Iter: %d	| 	PC: %h 	IR: %s		(0x%h)	SP: %h	|Reset: %b \n	Registers {A B C D E H L} : {%h %h %h %h %h %h %h}   MAR: %h		MDR: %h	\n	Clock cycle (dec): %d    Condition codes {Z N H C} : {%b %b %b %b}\n\n", 
				DUT.cp.curr_state.name, DUT.cp.iteration, DUT.PC, v.instruc.name, DUT.IR, DUT.SP, rst,
				regA, regB, regC, regD, regE, regH, regL, DUT.MAR, DUT.MDR, v.cycles,
				regF[3], regF[2], regF[1], regF[0]); 	
		
		#1000000;
		$stop;
	end
	
endmodule: testbench

// To be accessible from anywhere in design for debugging
module vars();
	std_instruction_t	instruc;
	int cycles;
endmodule: vars