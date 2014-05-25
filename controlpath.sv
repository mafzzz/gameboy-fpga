`include "constants.sv"

module control_path
	(input op_code_t		op_code,
	output logic			fetch_op_code,
	input logic [3:0]		flags,
	input logic 			rst,
	input logic				clk,
	output control_code_t 	control);
	
	logic				prefix_CB, next_prefix;
	logic [2:0]			iteration, next_iteration;
	control_state_t		curr_state, next_state;
	
	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			curr_state <= s_FETCH;
			iteration <= 3'b0;
			prefix_CB <= `FALSE;
		end
		else begin
			iteration <= next_iteration;
			prefix_CB <= next_prefix;
			curr_state <= next_state;
		end
	end
			
	always_comb begin
	
		fetch_op_code 	= `FALSE;
		next_prefix	  	= `FALSE;
		next_iteration	= iteration;
	
		case (curr_state)
			s_FETCH: begin
				if (iteration == 3'b000)
					fetch_op_code 		= `TRUE;
			
				control.reg_selA 		= reg_UNK;
				control.reg_selB 		= reg_UNK;
				control.alu_op   		= alu_UNK;
				control.alu_srcA		= src_UNK;
				control.alu_srcB		= src_UNK;	
				control.alu_dest		= dest_UNK;
				control.reg_ld			= `FALSE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.flags_loaded	= {`FALSE, `FALSE, `FALSE, `FALSE};
			end
			
			s_DECODE: begin
			
			end
			
			s_EXECUTE: begin
				control.reg_selA 		= reg_UNK;
				control.reg_selB 		= reg_UNK;
				control.alu_op   		= alu_UNK;
				control.alu_srcA		= src_UNK;
				control.alu_srcB		= src_UNK;	
				control.alu_dest		= dest_UNK;
				control.reg_ld			= `FALSE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.flags_loaded	= {`FALSE, `FALSE, `FALSE, `FALSE};
				
				case (op_code)
					default: ;
				endcase
				
			end
				
			s_WRITE: begin
				control.reg_selA 		= reg_UNK;
				control.reg_selB 		= reg_UNK;
				control.alu_op   		= alu_UNK;
				control.alu_srcA		= src_UNK;
				control.alu_srcB		= src_UNK;	
				control.alu_dest		= dest_UNK;
				control.reg_ld			= `FALSE;
				control.read_en			= `FALSE;
				control.write_en		= `FALSE;
				control.flags_loaded	= {`FALSE, `FALSE, `FALSE, `FALSE};
			end
		endcase
	
	end
	
endmodule: control_path