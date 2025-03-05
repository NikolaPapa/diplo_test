`ifdef MODEL_TECH
	`include "../sys_defs.vh"
`endif

//Decoder

module inst_decoder(
input [31:0] 		inst,
input logic valid_inst_in,  // ignore inst when low, outputs will
					        // reflect noop (except valid_inst)

output logic        dest_reg, // mux selects

output logic [4:0]  decode_addr, //address for micro operation memory


output logic		cond_branch, uncond_branch,
output logic 		illegal,    // non-zero on an illegal instruction
output logic 		valid_inst  // for counting valid instructions executed
);

assign valid_inst =valid_inst_in & ~illegal;

always_comb begin
	// - invalid instructions should clear valid_inst.
	// - These defaults are equivalent to a noop
	// * see sys_defs.vh for the constants used here

	decode_addr = 18; //wait state address
	dest_reg = `DEST_NONE;
	
	cond_branch = `FALSE;
	uncond_branch = `FALSE;
	illegal = `FALSE;

	case (inst[6:0])
		`R_TYPE: begin
			
			dest_reg = `DEST_IS_REGC;

			case({inst[14:12], inst[31:25]})
				`ADD_INST  : decode_addr = 4;   
				`SUB_INST  : decode_addr = 18;//needs to change  
				`XOR_INST  : decode_addr = 6;   
				`OR_INST   : decode_addr = 7;   
				`AND_INST  : decode_addr = 5;
				default: illegal = `TRUE;
			endcase 
		end //R-TYPE

		`I_ARITH_TYPE: begin
			
			dest_reg = `DEST_IS_REGC;

			case(inst[14:12])
				`ADDI_INST : decode_addr = 8;   
				`XORI_INST : decode_addr = 10;
				`ORI_INST  : decode_addr = 11;
				`ANDI_INST : decode_addr = 9;
				
				default: illegal = `TRUE;
			endcase 
		end //I_ARITH_TYPE

		`I_LD_TYPE: begin
			
			dest_reg = `DEST_IS_REGC;
			decode_addr = 0;//load address
			illegal=(inst[14:12]!=2)?`TRUE:`FALSE;			
		end //I_LD_TYPE

		`S_TYPE: begin
			
			decode_addr = 2;//store address
			
			case(inst[14:12])
				`SW_INST:   illegal = `FALSE;
				default: illegal = `TRUE;
			endcase
		end //S_TYPE
		
		`B_TYPE: begin
			
			cond_branch = `TRUE;
			
			case(inst[14:12])
				3'd2, 3'd3: illegal = `TRUE;
				default: decode_addr = 18;
			endcase
		end //B_TYPE
		
		`J_TYPE: begin
			
			dest_reg = `DEST_IS_REGC;
			decode_addr = 14;//jal
			uncond_branch = `TRUE;
		end //J-TYPE
		
		`I_JAL_TYPE: begin
			
			dest_reg = `DEST_IS_REGC;
			decode_addr = 16;//jalr
			uncond_branch = `TRUE;
			
			illegal = (inst[14:12] != 3'h0) ? `TRUE : `FALSE;
		end //I_JAL_TYPE
		
		`U_LD_TYPE: begin
			
			dest_reg = `DEST_IS_REGC;
			decode_addr = 12;
		end //U_LD_TYPE
		
		`U_AUIPC_TYPE: begin
			
			dest_reg = `DEST_IS_REGC;
			decode_addr = 13;
		end //U_AUIPC_TYPE
		
		`I_BREAK_TYPE: begin
			illegal = (inst[31:20] != 12'h1); //if imm=0x1 it is a ebreak (environmental break)
		end
		
		default: illegal = `TRUE;
	endcase 
end 
endmodule // inst_decoder



//Instruction Decode Stage 
module id_stage(
input logic 		clk,              		// system clk
input logic 		rst,              		// system rst
input logic [31:0] 	if_id_IR,            	// incoming instruction
input logic         if_id_valid_inst,

output logic [31:0]	id_immediate_out,		// sign-extended 32-bit immediate //stays the same


output logic [4:0] 	id_rs1_idx_out,    	// rs1 index
output logic [4:0] 	id_rs2_idx_out,    	// rs2 index out 


output logic [2:0] 	id_funct3_out,   //to determine branches

output logic [4:0] 	id_dest_reg_idx_out,  	// destination (writeback) register index (ZERO_REG if no writeback) //rd index out

output logic [4:0]  id_decode_addr,        // decode address


output logic 		cond_branch,
output logic        uncond_branch,

output logic       	id_illegal_out,
output logic       	id_valid_inst_out	  	// is inst a valid instruction to be counted for CPI calculations?
);
   
logic dest_reg_select;

//instruction fields read from IF/ID pipeline register 
logic[4:0] rc_idx; 

assign id_rs1_idx_out=if_id_IR[19:15];	// inst operand A register index
assign id_rs2_idx_out=if_id_IR[24:20];	// inst operand B register index

assign rc_idx=if_id_IR[11:7];  // inst operand C register index //used in decoder



// instantiate the instruction inst_decoder
inst_decoder inst_decoder_0(.inst	        (if_id_IR),
							.valid_inst_in  (if_id_valid_inst),
							.dest_reg		(dest_reg_select),
							.decode_addr	(id_decode_addr),
							.cond_branch	(cond_branch),
							.uncond_branch	(uncond_branch),
							.illegal		(id_illegal_out),
							.valid_inst		(id_valid_inst_out));



// mux to generate dest_reg_idx based on
// the dest_reg_select output from inst_decoder
always_comb begin
	if(dest_reg_select==`DEST_IS_REGC)
		id_dest_reg_idx_out = rc_idx;
	else
		id_dest_reg_idx_out = `ZERO_REG;
end

//ultimate "take branch" signal: unconditional, or conditional and the condition is true


//set up possible immediates:
//jmp_disp: 20-bit sign-extended immediate for jump displacement;
//up_imm: 20-bit immediate << 12;
//br_disp: sign-extended 12-bit immediate * 2 for branch displacement 
//mem_disp: sign-extended 12-bit immediate for memory displacement 
//alu_imm: sign-extended 12-bit immediate for ALU ops
logic[31:0] jmp_disp;
logic[31:0] up_imm;	
logic[31:0] br_disp; 	
logic[31:0] mem_disp; 
logic[31:0] alu_imm;	

assign jmp_disp={{12{if_id_IR[31]}}, if_id_IR[19:12], if_id_IR[20], if_id_IR[30:21], 1'b0};
assign up_imm = {if_id_IR[31:12], 12'b0};
assign br_disp = {{20{if_id_IR[31]}}, if_id_IR[7], if_id_IR[30:25], if_id_IR[11:8], 1'b0};
assign mem_disp = {{20{if_id_IR[31]}}, if_id_IR[31:25], if_id_IR[11:7]};
assign alu_imm = {{20{if_id_IR[31]}}, if_id_IR[31:20]};


always_comb begin : immediate_mux
	case(if_id_IR[6:0])
		`S_TYPE: id_immediate_out = mem_disp;
		`B_TYPE: id_immediate_out = br_disp;
		`J_TYPE: id_immediate_out = jmp_disp;
		`U_LD_TYPE, `U_AUIPC_TYPE: id_immediate_out = up_imm;
		default:id_immediate_out = alu_imm;
	endcase
end



assign id_funct3_out = if_id_IR[14:12];

endmodule // module id_stage