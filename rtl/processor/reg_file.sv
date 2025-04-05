module reg_file#(
    parameter COLS = 32,   // Number of columns (bits per row)
    parameter ROWS = 33    // Number of rows in the array
)(
    input logic [4:0] rd_index,  //save the result
    input logic write_en, //when needs to store a register
    input logic [4:0] rs1_index, //computes the op
    input logic [4:0] rs2_index, //moves to rs1
    input logic data2bus_en, // move data to rd bus
    input logic op_enable, // to choose fa_out up or down
    input logic exp_go_up, //for load and store handling
    input logic exp_go_dn, //for BNE and BEQ
    input logic buffer_read,
    input logic buffer_write,
    input logic buffer_go_up,
    input logic inv_en, // when subtracting
    input logic [COLS-1:0] immediate, // immediate and offset
    input logic imm_en,
    input logic [COLS-1:0] pc_plus4, //jal and jalr
    input logic [COLS-1:0] pc_reg, //for pc_plus_imm U_AUIPC_TYPE
    input logic [COLS-1:0] dataFromMem, //data to load
    input logic dataFM_en,
    input logic clk,
    input logic rst,
    input logic [3:0] op_fa, //choose operation for fa //0 sum 1 and 2 xor 3 or (bits to enable for each op)
    input logic carry_in,
    input logic pc_plus_en, //enable the pc_plus4 to be on the data_downstream
    input logic pc_imm_en,
    input logic imm_up_en,

    output logic [COLS-1:0] pc_plus_imm,
    output logic [COLS-1:0] data2Mem,
    output logic [COLS-1:0] addr2Mem,
    output logic [COLS-1:0] rd_out_dn, //needs to be used

    //output logic [COLS-1:0] wr_out_dn, // used for branches later
    // output logic [ROWS-1:0] ovf_Check
    output logic buffer_carry_out,
    output logic buffer_msb

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
//wires 32bit without buffer
logic [31:0] write_addr_32;
logic [31:0] rd_addr_up_32;
logic [31:0] fa_addr_up_32;
logic [31:0] rd_addr_dn_32;
logic [31:0] fa_addr_dn_32;


//logic [COLS-1:0] wr_out_up;
//logic [COLS-1:0] rd_out_up; //data out
logic [COLS-1:0] wr_out_dn; //used to check if equal
//logic [COLS-1:0] rd_out_dn;
logic [ROWS-1:0] ovf_Check;

//inputs handling
//needs change for lui
//assign data_in_up = 0;
// assign rd_in_up = 0;
logic [COLS-1:0] imm_inverse;

assign imm_inverse = 32'hFFFF_FFFF; //xor with 1 inverts the bits

ctrl_32_out ctrl_inverse(
        .in_sig(imm_inverse),
        .ctrl(inv_en),
        .out(rd_in_up)
    );

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
        .out(write_addr_32)
    );

logic [1:0] ctrl_rs1;
logic [1:0] ctrl_rs2;
logic comp_rs1;
logic comp_rs2;

assign comp_rs1 = (rs1_index > rd_index) ? 1'b1 : 1'b0;
always_comb begin
    if (op_enable) begin
        if (exp_go_up) begin
            ctrl_rs1 = 2'b01;
        end
        else if (exp_go_dn) begin //check for bne/beq
            ctrl_rs1 = 2'b10;
        end
        else begin
            ctrl_rs1[0] = comp_rs1;
            ctrl_rs1[1] = ~comp_rs1;
        end
    end
    else begin
        ctrl_rs1 = 2'b00;
    end
end

assign comp_rs2 = (rs2_index > rs1_index) ? 1'b1 : 1'b0;

always_comb begin
    if (data2bus_en) begin
        if (exp_go_up) begin
            ctrl_rs2 = 2'b01;
        end
        else if (exp_go_dn && (op_enable == 0)) begin //temporary fix for bne/beq
            ctrl_rs2 = 2'b10;
        end
        else begin
            ctrl_rs2[0] = comp_rs2;
            ctrl_rs2[1] = ~comp_rs2;
        end
    end
    else begin
        ctrl_rs2 = 2'b00;
    end
end

decoder_2ctrl rs1_dec(
        .index(rs1_index),
        .ctrl(ctrl_rs1), //ctrl 01 up, 10 dn, 00 none
        .out1(fa_addr_up_32),
        .out2(fa_addr_dn_32)
    );

decoder_2ctrl rs2_dec(
        .index(rs2_index),
        .ctrl(ctrl_rs2),
        .out1(rd_addr_up_32),
        .out2(rd_addr_dn_32)
    );

//buffer signals assignment
assign write_addr[31:0] = write_addr_32;
assign write_addr[32] = buffer_write;

assign rd_addr_dn[31:0] = rd_addr_dn_32 ;
assign rd_addr_dn[32] = 1'b0;

assign rd_addr_up[31:0] = rd_addr_up_32;
assign rd_addr_up[32] = buffer_read;

assign fa_addr_dn[31:0] = fa_addr_dn_32;
assign fa_addr_dn[32] = 1'b0;
assign fa_addr_up[31:0] = fa_addr_up_32;
// assign fa_addr_up[32] = 1'b0;
assign fa_addr_up[32] = buffer_go_up;

cell_array #(
        .COLS(COLS),
        .ROWS(ROWS) // last row used as a buffer
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
        .carry_in(carry_in),
        .wr_out_up(addr2Mem),
        .wr_out_dn(wr_out_dn), 
	    .rd_out_up(data2Mem),
	    .rd_out_dn(rd_out_dn),
        .overflow(ovf_Check),
        .last_row_msb(buffer_msb)
    );

assign buffer_carry_out = ovf_Check[32];
// //for branch prediction



endmodule