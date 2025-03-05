module reg_file#(
    parameter COLS = 32,   // Number of columns (bits per row)
    parameter ROWS = 32    // Number of rows in the array
)(
    input logic [4:0] rd_index,  //save the result
    input logic write_en, //when needs to store a register
    input logic [4:0] rs1_index, //computes the op
    input logic [4:0] rs2_index, //moves to rs1
    input logic data2bus_en, // move data to rd bus
    input logic op_enable, // to choose fa_out up or down
    input logic exp_go_up, //for load and store handling
    input logic exp_go_dn, //for BNE and BEQ
    // input logic buffer_read,
    // input logic buffer_write,
    // input logic buffer_inverse,// not of B when subtracting
    input logic [COLS-1:0] immediate, // immediate and offset
    input logic imm_en,
    input logic [COLS-1:0] pc_plus4, //jal and jalr
    input logic [COLS-1:0] pc_reg, //for pc_plus_imm U_AUIPC_TYPE
    input logic [COLS-1:0] dataFromMem, //data to load
    input logic dataFM_en,
    input logic clk,
    input logic rst,
    input logic [3:0] op_fa, //choose operation for fa //0 sum 1 and 2 xor 3 or (bits to enable for each op)
    //input logic carry_in,
    input logic pc_plus_en, //enable the pc_plus4 to be on the data_downstream
    input logic pc_imm_en,
    input logic imm_up_en,
    //input logic  [1:0] br_cond,
    output logic [COLS-1:0] data2Mem,
    output logic [COLS-1:0] addr2Mem,
    output logic [COLS-1:0] rd_out_dn, //needs to be used
    //output logic condition_met, //1 if condition_met

    //output logic [COLS-1:0] wr_out_dn, // used for branches later
    output logic [ROWS-1:0] ovf_Check

);

// wires to connect cell_array
logic [COLS-1:0] rd_in_up;
logic [COLS-1:0] rd_in_dn;
logic [COLS-1:0] data_in_dn;
logic [COLS-1:0] data_in_up;
logic [ROWS-1:0] write_addr;
logic [ROWS-1:0] rd_addr_up;
logic [ROWS-1:0] fa_addr_up;
logic [ROWS-1:0] rd_addr_dn;
logic [ROWS-1:0] fa_addr_dn;
//logic [COLS-1:0] wr_out_up;
//logic [COLS-1:0] rd_out_up; //data out
logic [COLS-1:0] wr_out_dn; //used to check if equal
//logic [COLS-1:0] rd_out_dn;
//logic [ROWS-1:0] overflow;

//inputs handling
//needs change for lui
//assign data_in_up = 0;
assign rd_in_up = 0;

ctrl_32_out ctrl_imm(
        .in_sig(immediate),
        .ctrl(imm_en),
        .out(rd_in_dn)
    );

//ctrl downstream
logic [COLS-1:0] data_in;
logic [COLS-1:0] pc_in;

ctrl_32_out ctrl_DataFMem(
        .in_sig(dataFromMem),
        .ctrl(dataFM_en),
        .out(data_in)
    );
ctrl_32_out ctrl_pc_plus4(
        .in_sig(pc_plus4),
        .ctrl(pc_plus_en),
        .out(pc_in)
    );

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin
            assign data_in_dn[i] = pc_in[i] | data_in[i]; // pc_plus4 or dataFM
        end
    endgenerate

//ctrl upstream imm and pc_plus_imm
logic [COLS-1:0] imm_up_in;
logic [COLS-1:0] pc_imm_in;
logic [COLS-1:0] pc_plus_imm;

ctrl_32_out ctrl_imm_up(
        .in_sig(immediate),
        .ctrl(imm_up_en),
        .out(imm_up_in)
    );

//like alu does the computation out of the alu
assign pc_plus_imm = pc_reg + immediate;

ctrl_32_out ctrl_plus_imm(
        .in_sig(pc_plus_imm),
        .ctrl(pc_imm_en),
        .out(pc_imm_in)
    );

    generate
        for (i = 0; i < 32; i = i + 1) begin
            assign data_in_up[i] = pc_imm_in[i] | imm_up_in[i]; // pc_plus_imm or immediate
        end
    endgenerate

//index handling
decode_ctrl ctrl_write(
        .index(rd_index),
        .ctrl(write_en),
        .out(write_addr)
    );

logic [1:0] ctrl_rs1;
logic [1:0] ctrl_rs2;
logic comp_rs1;
logic comp_rs2;
logic go_up_fa;
logic go_up_data;

assign comp_rs1 = (rs1_index > rd_index) ? 1'b1 : 1'b0;
assign go_up_fa = comp_rs1 | exp_go_up; //explicit go up on load and store operation
assign ctrl_rs1[0] = go_up_fa & op_enable;
assign ctrl_rs1[1] =  ((~go_up_fa) & op_enable) | exp_go_dn;

assign comp_rs2 = (rs2_index > rs1_index) ? 1'b1 : 1'b0;
assign go_up_data = comp_rs2 | exp_go_up; //exp_go_up on store operation
assign ctrl_rs2[0] = go_up_data & data2bus_en;
assign ctrl_rs2[1] =  (~go_up_data) & data2bus_en;

decoder_2ctrl rs1_dec(
        .index(rs1_index),
        .ctrl(ctrl_rs1), //ctrl 01 up, 10 dn, 00 none
        .out1(fa_addr_up),
        .out2(fa_addr_dn)
    );

decoder_2ctrl rs2_dec(
        .index(rs2_index),
        .ctrl(ctrl_rs2),
        .out1(rd_addr_up),
        .out2(rd_addr_dn)
    );

cell_array #(
        .COLS(COLS),
        .ROWS(ROWS)
    ) dut (
        .rd_in_up(rd_in_up),
	    .rd_in_dn(rd_in_dn),
	    .data_in_up(data_in_up),
        .data_in_dn(data_in_dn),
        .wr_en(write_addr),
        .rd_addr_up(rd_addr_up),
	    .rd_addr_dn(rd_addr_dn),
        .wr_addr_up(fa_addr_up),
	    .wr_addr_dn(fa_addr_dn),
        .clk(clk),
        .rst(rst),
        .op_fa(op_fa),
        .carry_in(1'b0), //.carry_in(carry_in),
        .wr_out_up(addr2Mem),
        .wr_out_dn(wr_out_dn), //check for equal or not branch condition
	    .rd_out_up(data2Mem),
	    .rd_out_dn(rd_out_dn),
        .overflow(ovf_Check)
    );

// //buffer for intermidiate results
// logic [COLS-1:0] buffer;
// always_ff@(posedge clk) begin 
//     if(rst) begin
//         buffer <= 0;
//     end
//     else if(buffer_write == 1) begin
//         if (buffer_inverse) begin // for 1's compliment in sub
//             buffer <= ~ wr_out_dn;
//         end else begin
//             buffer <= wr_out_dn;
//         end
//     end
// end

// ctrl_32_out ctrl_buffer(
//         .in_sig(buffer),
//         .ctrl(buffer_read),
//         .out(rd_in_up)
//     );

// //for branch brediction
// logic condition_check;
// assign condition_check = ovf_Check[rs1_index]; // ston rs1 tha ginei kai to or reduction.

// always_comb begin : branch_decision
//     case(br_cond)
//         2'b00: //BNE
//             condition_met = condition_check; // carry should be 1 after xor 
//         2'b01: //BEQ
//             condition_met = ~ condition_check; // carry should be 0 after xor
//         2'b10: //BLTU
//             condition_met = condition_check; // carry should be 1 after subtraction
//         2'b11: //BGEU
//             condition_met = ~ condition_check;
//         default: condition_met = condition_check;
//     endcase
// end

endmodule