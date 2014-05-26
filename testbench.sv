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

/* 	Module Testbench: Testing environment for the design on completion
*
*	WIP
*
*/
module testbench();

	logic	clk;
	logic	rst;
	
	datapath DUT (.*);
	
	initial begin
		rst <= '1;
		clk <= '0;
		#10;
		rst <= '0;
	end

	initial
		forever #5 clk <= ~clk;
	
	initial begin
		$monitor("State: %s 			| 	PC: %h 	IR: %h		|	Reset: %b", DUT.cp.curr_state.name, DUT.PC, DUT.IR, rst);
		#500;
		$stop;
	end
	
endmodule: testbench