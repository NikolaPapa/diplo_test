`ifdef MODEL_TECH
	`include "../sys_defs.vh"
`endif

module rf_processor(
    input logic 		HCLK,         // System clk
    input logic 		HRESETn,         // System rst
	
	input  logic [31:0] instruction,
	output logic [31:0] pc_addr,
	output logic [1:0]  im_command,

	//AHB connnections
	input  logic [31:0]  HRDATA,     // Read data bus
    input  logic         HREADY,  	 // Proceed with Transfer (comes from slaves hready out)
    input  logic         HRESP,      // Transfer response (OKAY = 0, ERROR = 1)
	output logic [31:0]  HADDR,
	output logic [2:0]   HSIZE,
	output logic         HWRITE,
    output logic [31:0]  HWDATA,   // Write data bus
    output logic [1:0]   HTRANS,   // Transfer type (IDLE, BUSY, NONSEQ, SEQ)

	
	// Outputs from IF-Stage 
	output logic [31:0] if_PC_out,
	output logic [31:0] if_NPC_out,
	output logic [31:0] if_IR_out,
	output logic        if_valid_inst_out,

	// Outputs from IF/ID Pipeline Register
	output logic [31:0] if_id_PC,
	output logic [31:0] if_id_NPC,
	output logic [31:0] if_id_IR,
	output logic        if_id_valid_inst,

	// Outputs from ID/RF Pipeline Register
	output logic [31:0] id_rf_PC,
	output logic [31:0] id_rf_NPC,
	output logic [31:0] id_rf_IR,
	output logic   		id_rf_valid_inst


	);

// Pipeline register enables
logic 			if_id_enable, id_rf_enable;


// Outputs from ID stage
logic [2:0]		id_funct3_out;
logic [4:0]   	id_rs1_idx_out;
logic [4:0]   	id_rs2_idx_out;
logic [31:0]	id_immediate_out;
logic [4:0]   	id_dest_reg_idx_out;
logic [4:0]     id_decode_addr;
logic         	id_illegal_out;
logic         	id_valid_inst_out;
logic 			id_uncond_branch;
logic 			id_cond_branch;

// Outputs from ID/EX Pipeline Register
logic 			id_rf_reg_wr;
logic [2:0]		id_rf_funct3;
logic [4:0]   	id_rf_rs1_idx;
logic [4:0]   	id_rf_rs2_idx;
logic [31:0] 	id_rf_imm;
logic [4:0]   	id_rf_dest_reg_idx;
logic [4:0]     id_rf_decode_addr;
logic           id_rf_illegal;
logic 			id_rf_uncond_branch;
logic 			id_rf_cond_branch;

// Outputs from rf-Stage
logic [31:0] 	rf_target_PC_out;
logic 			rf_take_branch_out;
logic			rf_valid_inst;
logic [31:0]	rf_addr2Mem;
logic [31:0] 	rf_pc_plus_imm;


logic rst;
logic clk;
logic done; //when rf is finished 
logic push_pal_inst;
logic condition_met;
logic buffer_msb;

assign rst = ~HRESETn;
assign clk = HCLK;


//Output Memory


assign im_command=`BUS_LOAD;
assign HSIZE = 3'b010; //word 32bits


//////////////////////////////////////////////////
//                                              //
//                  IF-Stage                    //
//                                              //
//////////////////////////////////////////////////
//temporarily no branches
// assign rf_take_branch_out = 0;
// assign rf_target_PC_out = 0;

if_stage if_stage_0 (
// Inputs
.clk 				(clk),
.rst 				(rst),
.rf_valid_inst		(rf_valid_inst),
.rf_take_branch_out	(rf_take_branch_out),
.rf_target_PC_out	(rf_target_PC_out),
.Imem2proc_data		(instruction),


// Outputs
.if_NPC_out			(if_NPC_out),
.if_PC_out			(if_PC_out), 
.if_IR_out			(if_IR_out),
.proc2Imem_addr		(pc_addr),
.if_valid_inst_out  (if_valid_inst_out)
);

//////////////////////////////////////////////////
//                                              //
//            IF/ID Pipeline Register           //
//                                              //
//////////////////////////////////////////////////
assign if_id_enable = 1;

always_ff @(posedge clk or posedge rst) begin
	if(rst || push_pal_inst) begin
		if_id_PC         <=  0;
		if_id_IR         <=  `NOOP_INST;
		if_id_NPC        <=  0;
        if_id_valid_inst <=  0;
    end 
    else if (if_id_enable && done) begin
		if_id_PC         <=  if_PC_out;
		if_id_NPC        <=  if_NPC_out;
		if_id_IR         <=  if_IR_out; 
        if_id_valid_inst <=	 if_valid_inst_out;
    end 
end 

   
//////////////////////////////////////////////////
//                                              //
//                  ID-Stage                    //
//                                              //
//////////////////////////////////////////////////
id_stage id_stage_0 (
// Inputs
.clk     				(clk),
.rst   					(rst),
.if_id_IR   			(if_id_IR),  	
.if_id_valid_inst       (if_id_valid_inst),

// Outputs
.id_funct3_out			(id_funct3_out),
.id_rs1_idx_out			(id_rs1_idx_out),
.id_rs2_idx_out			(id_rs2_idx_out),
.id_immediate_out		(id_immediate_out),
.id_dest_reg_idx_out	(id_dest_reg_idx_out),
.id_decode_addr			(id_decode_addr),
.cond_branch			(id_cond_branch),
.uncond_branch			(id_uncond_branch),
.id_illegal_out			(id_illegal_out),
.id_valid_inst_out		(id_valid_inst_out)
);

//////////////////////////////////////////////////
//                                              //
//            ID/RF Pipeline Register           //
//                                              //
//////////////////////////////////////////////////
assign id_rf_enable =1; // disabled when HzDU initiates a stall
// synopsys sync_set_rst "rst"
always_ff @(posedge clk or posedge rst) begin
	if (rst) begin //sys_rst
		//Control
		id_rf_funct3		<=  0;
		id_rf_decode_addr   <=  18;
		id_rf_illegal       <=  0;
		id_rf_valid_inst    <=  `FALSE;
		
		//Data
		id_rf_PC            <=  0;
		id_rf_IR            <=  `NOOP_INST;
		id_rf_rs1_idx       <=  0;
		id_rf_rs2_idx       <=  0;
		id_rf_imm			<=  0;
		id_rf_dest_reg_idx  <=  `ZERO_REG;
		id_rf_uncond_branch <=  0;
		id_rf_cond_branch	<=  0;
		
		//Debug
		id_rf_NPC           <=  0;
    end else begin 
		if (id_rf_enable && done) begin
			id_rf_funct3		<=  id_funct3_out;
			id_rf_decode_addr	<=	id_decode_addr;
			id_rf_illegal       <=  id_illegal_out;
			id_rf_valid_inst    <=  id_valid_inst_out;
			
			id_rf_PC            <=  if_id_PC;
			id_rf_IR            <=  if_id_IR;
			id_rf_rs1_idx		<=	id_rs1_idx_out;
			id_rf_rs2_idx		<=	id_rs2_idx_out;
			id_rf_imm			<=  id_immediate_out;
			id_rf_dest_reg_idx  <=  id_dest_reg_idx_out;
			
			id_rf_NPC           <=  if_id_NPC;
			id_rf_uncond_branch <=  id_uncond_branch;
			id_rf_cond_branch	<=  id_cond_branch;
		end // if
    end // else: !if(rst)
end // always

//////////////////////////////////////////////////
//                                              //
//                  RF-Stage                    //
//                                              //
//////////////////////////////////////////////////

top #(
    .COLS(32),
    .ROWS(33) //uses buffer
)  TopRF (
    .clk(clk),
    .rst(rst),
    .decode_addr(id_rf_decode_addr),
	.id_rf_valid_inst(id_rf_valid_inst),
    .rd_index(id_rf_dest_reg_idx),
    .rs1_index(id_rf_rs1_idx),
    .rs2_index(id_rf_rs2_idx),
    .immediate(id_rf_imm),
    .pc_plus4(id_rf_NPC),
    .pc_reg(id_rf_PC),
    .dataFromMem(HRDATA),
    .data2Mem(HWDATA),
    .addr2Mem(rf_addr2Mem),
	.buffer_carry_out(buffer_carry_out),
	.HTRANS(HTRANS),
	.HWRITE(HWRITE),
	.rf_valid_inst(rf_valid_inst),
	.rf_pc_plus_imm(rf_pc_plus_imm),
	.done(done),
	.buffer_msb(buffer_msb)
); 
assign HADDR = rf_addr2Mem;

always_comb begin : branch_decision
    case(id_rf_funct3)
        `BNE_INST:
            condition_met = buffer_carry_out; // carry should be 1 after xor 
        `BEQ_INST: 
            condition_met = ~ buffer_carry_out; // carry should be 0 after xor
        `BLTU_INST:
            condition_met = ~ buffer_carry_out; // carry should be 0 after subtraction (A<B)
        `BGEU_INST:
            condition_met =  buffer_carry_out; // carry should be 1 (A>=B)
		`BLT_INST:
			condition_met =  buffer_carry_out ^ buffer_msb;
		`BGE_INST:
			condition_met = ~(buffer_carry_out ^ buffer_msb);
        default: condition_met = buffer_carry_out;
    endcase
end

always_comb begin
	if(id_rf_uncond_branch) begin
		rf_target_PC_out = rf_addr2Mem;
	end
	else begin
		rf_target_PC_out = rf_pc_plus_imm;
	end
end

always_comb begin
	if (id_rf_uncond_branch && done && id_rf_valid_inst) begin
		rf_take_branch_out = 1;
	end
	else if (id_rf_cond_branch && done && id_rf_valid_inst) begin
		rf_take_branch_out = condition_met;
	end
	else begin
		rf_take_branch_out = 0;
	end
end

assign push_pal_inst = (id_rf_uncond_branch | id_rf_cond_branch) & id_rf_valid_inst;


endmodule  