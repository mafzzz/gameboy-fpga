/**************************************************************************
 *	"memoryunit.sv"
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

`include "constants.sv"
`define synthesis

module memoryunit 
  (
   // CPU MEMORY OPERATIONS
   inout       [7:0]		data,
   input logic [15:0]		cpu_address,
   input logic 			OE,
   input logic 			WE,
  
   // CONTROL REGISTERS
   input control_reg_t 	regin, 
   output control_reg_t	regout,
  
   // DISPLAY MEMORY
   input logic [7:0] disp_address_oam,
   input logic [12:0] disp_address_vram,
   input logic oe_oam,
   input logic oe_vram,
   input logic ld_disp_address_oam,
   input logic ld_disp_address_vram,
   output logic [7:0] disp_data_oam,
   output logic [7:0] disp_data_vram,
  
   input logic	clk,
   input logic 	rst);
   
   logic 	CS_dmg, CS_rom0, CS_rom1, CS_vram, CS_ram0, CS_ram1, CS_oam, CS_io, CS_ramh;
   logic [8:0] 	CS_decoder;
   assign {CS_ramh, CS_io, CS_oam, CS_ram1, CS_ram0, CS_vram, CS_rom1, CS_rom0, CS_dmg} = CS_decoder;
   
   logic [7:0] 	data_out_oam, data_out_vram, data_in_oam, data_in_vram;
   
   assign data_in_oam = (CS_oam & WE) ? data : 8'bx;
   assign data_in_vram = (CS_vram & WE) ? data : 8'bx;
   assign disp_data_oam = (oe_oam) ? data_out_oam : 8'bx;
   assign disp_data_vram = (oe_vram) ? data_out_vram : 8'bx;

   tri [7:0] 	databus;

   reg [15:0] 	address, address_vram, address_oam;
   
   reg 		dmg_rom_disable;
   
   /*** DMA PORTS ***/
   logic 	dma_read, dma_write, ld_address_dma, ld_address_dma_oam;
   logic [15:0] address_dma, address_dma_in, address_dma_oam;
   logic [7:0] 	data_dma;
   tri [7:0] 	data_out_dma;
   
   always_ff @(posedge clk, posedge rst) begin
      if (rst) 
	dmg_rom_disable <= `FALSE;
      else
	dmg_rom_disable <= dmg_rom_disable | regout.dmg_disable;
   end
   
   always_ff @(posedge clk, posedge rst) begin
      if (rst) begin
	 address <= 16'b0;
	 address_vram <= 16'b0;
	 address_dma <= 16'b0;
      end else begin
	 address <= cpu_address;
	 address_oam <= (ld_address_dma_oam) ? address_dma_oam : (ld_disp_address_oam) ? disp_address_oam : cpu_address;
	 address_vram <= (ld_disp_address_vram) ? disp_address_vram : cpu_address;
	 address_dma <= (ld_address_dma) ? address_dma_in : cpu_address;
      end
   end
   
   // DMA State machine
   dma_state_t dma_state;
   always_ff @(posedge clk, posedge rst) begin
      if (rst) begin
	 dma_state <= s_DMA_WAIT;
      end else begin
	 case (dma_state)
	   s_DMA_WAIT: begin
	      dma_read <= `FALSE;
	      dma_write <= `FALSE;
	      ld_address_dma <= `FALSE;
	      ld_address_dma_oam <= `FALSE;
	      
	      address_dma_in <= 16'bx;
	      address_dma_oam <= 16'bx;
	      data_dma <= 8'bx;
	      dma_state <= s_DMA_WAIT;
	      
	      //dma_state <= (address == 16'hFF46 && WE) ? s_DMA_ADDRESS_INIT : s_DMA_WAIT;
	   end
	   
	   s_DMA_ADDRESS_INIT: begin
	      dma_read <= `FALSE;
	      dma_write <= `FALSE;
	      ld_address_dma <= `TRUE;
	      ld_address_dma_oam <= `TRUE;
	      
	      address_dma_in <= {regout.dma, 8'b00};
	      address_dma_oam <= 16'hFDFF;
	      
	      dma_state <= s_DMA_DATA_READ;
	   end
	   
	   s_DMA_DATA_READ: begin
	      dma_read <= `TRUE;
	      dma_write <= `FALSE;
	      ld_address_dma <= `TRUE;
	      ld_address_dma_oam <= `TRUE;
	      
	      dma_state <= s_DMA_ADDRESS_WRITE;
	   end

	   s_DMA_ADDRESS_WRITE: begin
	      dma_read <= `FALSE;
	      dma_write <= `FALSE;
	      ld_address_dma <= `TRUE;
	      ld_address_dma_oam <= `TRUE;

	      address_dma_oam <= address_dma_oam + 1'b1;
	      data_dma <= data_out_dma;
	      dma_state <= s_DMA_DATA_WRITE;
	   end
	   
	   s_DMA_DATA_WRITE: begin
	      dma_read <= `FALSE;
	      dma_write <= `TRUE;
	      ld_address_dma <= `TRUE;
	      ld_address_dma_oam <= `TRUE;
	      
	      address_dma_in <= address_dma_in + 1'b1;
	      
	      dma_state <= (address_dma_oam == 16'hFE9F) ? s_DMA_WAIT : s_DMA_DATA_READ;
	   end
	 endcase
      end
   end
   
   // Chip select decoder
   always_comb begin
      // 0x0000 <= address < 0x0100  [DMG_ROM] (When enabled)
      if (address < 16'h0100 && ~dmg_rom_disable) 
	CS_decoder = 9'b0000_00001;

      // 0x0000 <= address < 0x4000  [ROM_BANK_0]
      else if (address < 16'h4000)
	CS_decoder = 9'b0000_00010;
      
      // 0x4000 <= address < 0x8000  [ROM_BANK_1]
      else if (address < 16'h8000)
	CS_decoder = 9'b0000_00100;
      
      // 0x8000 <= address < 0xA000  [VRAM]
      else if (address < 16'hA000)
	CS_decoder = 9'b0000_01000;
      
      // 0xA000 <= address < 0xC000  [RAM_BANK_0]
      else if (address < 16'hC000)
	CS_decoder = 9'b0000_10000;
      
      // 0xC000 <= address < 0xE000  [RAM_BANK_1]  0xE000 <= address < 0xFE00  [RAM_BANK_1_ECHO]
      else if (address < 16'hE000 || address < 16'hFE00)
	CS_decoder = 9'b0001_00000;
      
      // 0xFE00 <= address < 0xFEA0  [OAM]
      else if (address >= 16'hFE00 && address < 16'hFEA0)
	CS_decoder = 9'b0010_00000;
      
      // 0xFF00 <= address < 0xFF4C  [CONTROL_REGS]  0xFF50 [Disable DMG_ROM]    0xFFFF  [Interrupt enables]
      else if ((address >= 16'hFF00 && address < 16'hFF4C) || address == 16'hFF50 || address == 16'hFFFF)
	CS_decoder = 9'b0100_00000;
      
      // 0xFF80 <= address < 0xFFFF  [HIGH_RAM]
      else if (address >= 16'hFF80 && address < 16'hFFFF)
	CS_decoder = 9'b1000_00000;
      
      // UNUSABLE MEMORY LOCATIONS
      else
	CS_decoder = 9'b0000_00000;
   end
   
`ifndef synthesis
   always @(posedge clk) begin
      if ((CS_rom0 || CS_rom1 || CS_dmg) && WE) begin
	 $display("********************************************");
	 $display("Current time: %d", $time);
	 $display("State: %s			Iter: %d	| 	PC: %h 	IR: 0x%h		SP: %h	| \n	Registers {A B C D E H L} : {%h %h %h %h %h %h %h}   MAR: %h		MDR: %h	\n	Condition codes {Z N H C} : {%b %b %b %b}\n\n", 
		  DUT.dp.cp.curr_state.name, DUT.dp.cp.iteration, DUT.dp.PC, DUT.dp.IR, DUT.dp.SP,
		  DUT.dp.regA, DUT.dp.regB, DUT.dp.regC, DUT.dp.regD, DUT.dp.regE, DUT.dp.regH, DUT.dp.regL, DUT.dp.MAR, DUT.dp.MDR,
		  DUT.dp.regF[3], DUT.dp.regF[2], DUT.dp.regF[1], DUT.dp.regF[0]); 
	 $display("********************************************\n");
      end
   end
`endif
   
   /*** MEMORY BANKS ***/
   
   // ROM
   SRAM_BANK #(.start (16'h0000), .size (16'h0100), .init ("bootstrap.hex")) dmg(.databus (databus), .address (address[7:0]), .CS (CS_dmg), 
										 .dma_read (`FALSE), .data_out_dma (data_out_dma), .OE (OE), .WE (WE), .clk (clk));
   SRAM_BANK #(.start (16'h0000), .size (16'h4000), .init ("ROM0.hex")) romb0(.databus (databus), .address (address_dma[13:0]), .CS (CS_rom0), 
									      .dma_read (dma_read && address_dma[15:14] == 2'b00), .data_out_dma (data_out_dma), .OE (OE), .WE (WE), .clk (clk));
   SRAM_BANK #(.start (16'h4000), .size (16'h4000), .init ("ROM1.hex")) romb1(.databus (databus), .address (address_dma[13:0]), .CS (CS_rom1), 
									      .dma_read (dma_read && address_dma[15:14] == 2'b01), .data_out_dma (data_out_dma), .OE (OE), .WE (WE), .clk (clk));

   // VRAM
   SRAM_DUAL_BANK #(.start (16'h8000), .size (16'h2000), .init ("")) vram(.address (address_vram[12:0]), .write_data (data_in_vram),
									  .dma_write (`FALSE), .data_in_dma (), .CS (CS_vram), .read_data (data_out_vram), .OE (oe_vram | OE), .WE (WE), .clk (clk));

   // INTERNAL RAM
   SRAM_BANK #(.start (16'hA000), .size (16'h2000), .init ("")) ramb0(.databus (databus), .address (address_dma[12:0]), .CS (CS_ram0), 
								      .dma_read (dma_read && address_dma[15:13] == 3'b101), .data_out_dma (data_out_dma), .OE (OE), .WE (WE), .clk (clk));
   SRAM_BANK #(.start (16'hC000), .size (16'h2000), .init ("")) ramb1(.databus (databus), .address (address_dma[12:0]), .CS (CS_ram1), 
								      .dma_read (dma_read && address_dma[15:13] == 3'b110), .data_out_dma (data_out_dma), .OE (OE), .WE (WE), .clk (clk));

   // OAM
   SRAM_DUAL_BANK #(.start (16'hFE00), .size (16'h0100), .init ("")) oam(.address (address_oam[7:0]), .write_data (data_in_oam),
									 .dma_write (dma_write), .data_in_dma (data_dma), .CS (CS_oam), .read_data (data_out_oam), .OE (oe_oam | OE), .WE (WE), .clk (clk));

   // HIGH RAM
   SRAM_BANK #(.start (16'hFF80), .size (16'h0080), .init ("")) ramh(.databus (databus), .address (address[6:0]), .CS (CS_ramh), 
								     .dma_read (`FALSE), .data_out_dma (databus), .OE (OE), .WE (WE), .clk (clk));
   
   /*** CONTROL REGISTER BANK ***/
   IO_CONTROL_REGS #(.start (16'hFF00), .size (16'h0100)) io(.databus (databus), .address (address[7:0]), .regout (regout), .regin (regin),
							     .CS (CS_io), .OE (OE), .WE (WE), .clk (clk), .rst (rst));

   assign data = (OE) ? (CS_oam) ? data_out_oam : (CS_vram) ? data_out_vram : (CS_decoder[0] | CS_decoder[1] | CS_decoder[2] | CS_decoder[4] 
									       | CS_decoder[5]) ? data_out_dma : databus : 8'bz;
   
   assign databus = (~OE && WE) ? data : 8'bz;	
   
endmodule: memoryunit

module SRAM_BANK
  #(parameter start  = 16'h0000,
    parameter size   = 16'h4000,
    parameter init   = "")
   
   (inout tri	[7:0]				databus,
    output logic [7:0]				data_out_dma,
    input logic [$clog2(size)-1:0]	address,
    input logic						dma_read,
    input logic						CS,
    input logic						OE,
    input logic						WE,
    input logic						clk);
   
   reg [7:0] 						mem [16'h0000 : size - 1];
   
   always @(posedge clk) begin
      if (WE && CS && ~(start == 16'h0000 && address == 14'h2000))
	mem[address] <= databus;
   end
   
   assign data_out_dma = ((OE && CS && ~WE) || dma_read) ? mem[address] : 8'bz;

   initial
     if (init != "")
       $readmemh(init, mem);

endmodule: SRAM_BANK

module SRAM_DUAL_BANK
  #(parameter start  = 16'h0000,
    parameter size   = 16'h4000,
    parameter init   = "")
   
   (input logic [7:0]				write_data,
    output logic [7:0]				read_data,
    input logic [$clog2(size)-1:0]	address,
    input logic						dma_write,
    input logic [7:0]				data_in_dma,
    input logic						CS,
    input logic						OE,
    input logic						WE,
    input logic						clk);
   
   reg [7:0] 						mem [16'h0000 : size - 1];
   
   always @(posedge clk) begin
      if (dma_write)
	mem[address] <= data_in_dma;
      else if (WE && CS)
	mem[address] <= write_data;
   end
   
   assign read_data = (OE && ~(WE && CS) && ~dma_write) ? mem[address] : 8'bx;
   
endmodule: SRAM_DUAL_BANK

module IO_CONTROL_REGS
  #(parameter start  = 16'hFF00,
    parameter size   = 16'h0100)

   (inout tri [7:0]				databus,
    input logic [$clog2(size)-1:0]	address,
    input control_reg_t				regin,
    output control_reg_t			regout,
    input logic						CS,
    input logic						OE,
    input logic						WE,
    input logic						clk,
    input logic						rst);

   control_reg_t	control_regs;
   logic [7:0] 						data;
   
   // Output register window
   assign regout = control_regs;
   
   // Address decoder for writes
   always_ff @(posedge clk, posedge rst) begin
      if (rst)
	control_regs <= '0;
      
      else if (WE && CS) begin
	 // Update registers not being written
	 control_regs <= regin;

	 // Next value by default is regin, set from peripheral components outside CPU
	 // For CPU controlled regs, set by address MUX:
	 case (address)
	   
	   8'h00: 
	     control_regs.joypad <= {2'b0, databus[5:4], regin[3:0]};
	   8'h01: 
	     control_regs.serial_data <= databus;
	   8'h02: 
	     control_regs.serial_control <= databus;
	   8'h04: 
	     control_regs.timer_divide <= 8'b0;
	   8'h05: 
	     control_regs.timer_count <= 8'b0;
	   8'h06: 
	     control_regs.timer_modulo <= databus;
	   8'h07: 
	     control_regs.timer_control <= {5'b0, databus[2:0]};
	   8'h0F: 
	     control_regs.interrupt_st <= regin;
	   8'h40: 
	     control_regs.lcd_control <= databus;
	   8'h41: 
	     control_regs.lcd_status <= {1'b0, databus[6:3], regin[2:0]};
	   8'h42: 
	     control_regs.scroll_y <= databus;
	   8'h43: 
	     control_regs.scroll_x <= databus;
	   8'h44: 
	     control_regs.lcd_v <= regin;
	   8'h45: 
	     control_regs.lcd_v_cp <= databus;
	   8'h46: 
	     control_regs.dma <= databus;
	   8'h47: 
	     control_regs.bg_pal <= databus;
	   8'h48: 
	     control_regs.obj_pal0 <= databus;
	   8'h49: 
	     control_regs.obj_pal1 <= databus;
	   8'h4A: 
	     control_regs.win_y <= databus;
	   8'h4B: 
	     control_regs.win_x <= databus;
	   8'h50:
	     control_regs.dmg_disable <= `TRUE;
	   8'hFF:
	     control_regs.interrupt_en <= databus;
	   
	   default: begin
	      control_regs <= regin;
	   end
	 endcase
	 
      end else begin
	 // If not writing, use regin values.
	 control_regs <= regin;
      end	
   end

   // Address decoder for reads
   always_comb begin
      if (CS) begin
	 case (address)
	   8'h00: 
	     data = control_regs.joypad;
	   8'h01: 
	     data = control_regs.serial_data;
	   8'h02: 
	     data = control_regs.serial_control;				
	   8'h04: 
	     data = control_regs.timer_divide;				
	   8'h05: 
	     data = control_regs.timer_count;				
	   8'h06: 
	     data = control_regs.timer_modulo;				
	   8'h07: 
	     data = control_regs.timer_control;
	   8'h0F: 
	     data = control_regs.interrupt_st;		
	   8'h40: 
	     data = control_regs.lcd_control;
	   8'h41: 
	     data = control_regs.lcd_status;
	   8'h42: 
	     data = control_regs.scroll_y;				
	   8'h43: 
	     data = control_regs.scroll_x;	
	   8'h44: 
	     data = control_regs.lcd_v;
	   8'h45: 
	     data = control_regs.lcd_v_cp;				
	   8'h46: 
	     data = 8'b0;			
	   8'h47: 
	     data = control_regs.bg_pal;	
	   8'h48: 
	     data = control_regs.obj_pal0;
	   8'h49: 
	     data = control_regs.obj_pal1;			
	   8'h4A: 
	     data = control_regs.win_y;			
	   8'h4B: 
	     data = control_regs.win_x;				
	   8'hFF: 
	     data = control_regs.interrupt_en;
	   
	   default: begin
	      data = 8'bx;
	   end
	 endcase
      end else begin
	 data = 8'bx;
      end
   end
   
   assign databus = (~WE && OE && CS) ? data : 8'bz;
   
endmodule: IO_CONTROL_REGS