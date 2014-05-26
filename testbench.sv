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

	tri 	[7:0]	databus;
	logic 	[15:0]	address;
	logic			RE;
	logic			WE;
	logic			clk;
	
	sram	mem(.*);
	
	initial begin
		clk <= '0
		forever #2 clk = ~clk;
	end

	initial begin
		$monitor("Address: %h  |  Databus: %h  |  RE: %b  WE: %b", address, databus, RE, WE);
		
		address <= '0;
		databus <= 'z;
		RE <= '0;
		WE <= '0
		#10;
		
		RE <= '1;
		#10;
		address <= 16'h01;
		#10;
		address <= 16'h02;
		#10;
		address <= 16'h03;
		#10;
		address <= 16'h04;
		#10;
		address <= 16'h05;
		#10;
		address <= 16'h06;
		#10;
		address <= 16'h07;
		#10;
		address <= 16'h08;
		#10;
		address <= 16'h09;
		#10;
		address <= 16'h0A;
		#10;
		$stop;
		
	end
	
endmodule: testbench