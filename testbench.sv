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
*	Contact Sohil Shah at sohils@cmu.edu for information or questions. 
**************************************************************************/

`include "datapath.sv"

/* 	Module Testbench: Testing environment for the design on completion
*
*	WIP
*
*/
module testbench();

	logic [7:0] 	A, B, result;
	alu_op_t		op_code;
	logic [3:0]		currFlags, newFlags;
	logic [15:0]	addr;
	
	alu DUT(.op_A(A), .op_B(B), .alu_result(result), .curr_flags(currFlags), .next_flags(newFlags), .addr_result(addr), .op_code(op_code));
	
	initial begin
		$monitor("%h	%s		%h	=	%h		flags {Z N H C} = [%b -> %b]", A, op_code.name, B, result, currFlags, newFlags);
		
		A <= '0; op_code <= alu_NOP;
		B <= '0; currFlags <= '0;
		#10;
		
		A <= 8'hff;
		B <= 8'hff;
		op_code <= alu_ADD;
		currFlags <= newFlags;
		#10;
		
		A <= 8'h00;
		B <= 8'hff;
		op_code <= alu_SUB;
		currFlags <= newFlags;
		#10;

		A <= 8'h5;
		B <= 8'hf6;
		op_code <= alu_RRC;
		currFlags <= newFlags;
		#10;

		A <= 8'h7;
		B <= 8'hff;
		op_code <= alu_RL;
		currFlags <= newFlags;
		#10;

		A <= 8'h9;
		B <= 8'h0;
		op_code <= alu_SLA;
		currFlags <= newFlags;
		#10;

		A <= 8'hB;
		B <= 8'hBC;
		op_code <= alu_SRL;
		currFlags <= newFlags;
		#10;

		A <= 8'h12;
		B <= 8'h34;
		op_code <= alu_CPL;
		currFlags <= newFlags;
		#10;

		A <= 8'hAA;
		B <= 8'h5A;
		op_code <= alu_XOR;
		currFlags <= newFlags;
		#10;

		A <= 8'hBB;
		B <= 8'hC2;
		op_code <= alu_NOP;
		currFlags <= newFlags;
		#10;

		A <= 8'hB1;
		B <= 8'h40;
		op_code <= alu_NOP;
		currFlags <= newFlags;
		#10;

		A <= 8'h2B;
		B <= 8'h1C;
		op_code <= alu_ADC;
		currFlags <= newFlags;
		#10;
		
		#20;
		$stop;
	end

endmodule: testbench
















