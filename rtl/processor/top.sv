module top#(
    parameter COLS = 32,   
    parameter ROWS = 33 
)(
    input logic clk,
    input logic rst,
    input logic [4:0] decode_addr,
    input logic id_rf_valid_inst,

    //-- signals for register file --
    input logic [4:0] rd_index,  //save the result
    input logic [4:0] rs1_index, //computes the op
    input logic [4:0] rs2_index, //moves to rs1
    input logic [COLS-1:0] immediate, // immediate and offset
    input logic [COLS-1:0] pc_plus4, //jal and jalr
    input logic [COLS-1:0] pc_reg, //for pc_plus_imm U_AUIPC_TYPE
    input logic [COLS-1:0] dataFromMem, 
    output logic [COLS-1:0] data2Mem,
    output logic [COLS-1:0] addr2Mem,
    output logic rf_valid_inst,
    output logic [COLS-1:0] rf_pc_plus_imm,
    output logic buffer_carry_out,
    output logic [1:0] HTRANS,
    output logic HWRITE,
    output logic done
);

//-- signals for RF --
logic data2bus_en;
logic imm_en;
logic op_enable;
logic write_en;
logic [3:0] op_fa;
logic pc_plus_en;
logic pc_imm_en;
logic imm_up_en;
logic dataFM_en;
logic buffer_read, buffer_write;
logic carry_in, inv_en;
logic [COLS-1:0] rd_out_dn; //needs to be used

//-- signals for micro_control --
logic [18:0] current_control;



micro_control controller(
    .clk(clk),
    .rst(rst),
    .id_rf_valid_inst(id_rf_valid_inst),
    .decode_addr(decode_addr),
    .current_control(current_control),
    .rf_valid_inst(rf_valid_inst),
    .HTRANS(HTRANS),
    .HWRITE(HWRITE),
    .done(done)
);

 
//'b write_en op_enable exp_go_up exp_go_dn data2bus_en dataFM_en pc_plus_en pc_imm_en imm_up_en imm_en op_fa (is_last_signal)
assign {write_en, op_enable, exp_go_up,
        exp_go_dn, data2bus_en, dataFM_en,
        pc_plus_en, pc_imm_en, imm_up_en, imm_en, op_fa, buffer_read, buffer_write, carry_in, inv_en} = current_control[18:1];




reg_file #(
        .COLS(COLS),
        .ROWS(ROWS)
    ) RF (
        .rd_index(rd_index),
        .write_en(write_en),
        .rs1_index(rs1_index),
        .rs2_index(rs2_index),
        .data2bus_en(data2bus_en),
        .op_enable(op_enable),
        .exp_go_up(exp_go_up),
        .exp_go_dn(exp_go_dn),
        .buffer_write(buffer_write),
        .buffer_read(buffer_read),
        .inv_en(inv_en),
        .immediate(immediate),
        .imm_en(imm_en),
        .pc_plus4(pc_plus4),
        .pc_reg(pc_reg),
        .dataFromMem(dataFromMem),
        .dataFM_en(dataFM_en),
        .clk(clk),
        .rst(rst),
        .op_fa(op_fa),
        .carry_in(carry_in),
        .pc_plus_en(pc_plus_en),
        .pc_imm_en(pc_imm_en),
        .imm_up_en(imm_up_en),
        .pc_plus_imm(rf_pc_plus_imm),
        .data2Mem(data2Mem),
        .addr2Mem(addr2Mem),
        .rd_out_dn(rd_out_dn),
        .buffer_carry_out(buffer_carry_out)
    );

endmodule