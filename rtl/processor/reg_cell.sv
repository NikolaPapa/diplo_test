module reg_cell(
    input logic c_in,
    input logic rd_in_up, //read port
    input logic rd_in_dn,
    input logic wr_in_up,
    input logic wr_in_dn, //write port
    input logic clk,
    input logic rst,
    input logic wr_sel_up, //msb 1 means up | lsb 1 means down bus
    input logic wr_sel_dn,
    input logic rd_sel_up,
    input logic rd_sel_dn,
    input logic wr_en,
    input logic [3:0] op_fa, //choose operation for fa //0 sum 1 and 2 xor 3 or (bits to enable for each op)
    output logic c_out,
    output logic rd_out_up,
    output logic rd_out_dn, //read port out down
    output logic wr_out_up, //write port out
    output logic wr_out_dn,
    output logic debug_bit_reg   
);

logic fa_in; //epilogi dromou eisodou gia full_adder
logic fa_out;
logic reg_in;
logic bit_reg;
logic xor_fa_in;

assign reg_in =  wr_out_up | wr_out_dn;
assign fa_in = rd_out_up | rd_out_dn;

 
//manage bus 
assign wr_out_up = (wr_sel_up & fa_out) | wr_in_up ;
assign wr_out_dn = (wr_sel_dn & fa_out) | wr_in_dn ;
assign rd_out_up = (rd_sel_up & bit_reg) | rd_in_up ;
assign rd_out_dn = (rd_sel_dn & bit_reg) | rd_in_dn ;

extend_FA2 FA(
    .Cin (c_in),
    .X1 (bit_reg),
    .X2 (fa_in),
    .op (op_fa),
    .fa_out (fa_out),
    .Cout (c_out)
);

always_ff@(posedge clk) begin 
    if(rst) begin
        bit_reg <= 0;
    end
    else if(wr_en == 1) begin
	    bit_reg <= reg_in;
    end
end

assign debug_bit_reg = bit_reg;

endmodule


module extend_FA2(
    input logic Cin,
    input logic X1,
    input logic X2,
    input [3:0] op, //0 sum 1 and 2 xor 3 or 
    output logic fa_out, 
    output logic Cout
    );

logic XOR, AND, OR, Sum ;
assign OR = X1 | X2; 
assign XOR = X1 ^ X2 ;
assign Sum = Cin ^ XOR;
assign AND = X1 & X2;
assign Cout = (AND) | (XOR & Cin);

logic sum_pass, and_pass, xor_pass, or_pass;

//one hot representation minimizes the gate count used for mux
assign sum_pass = Sum & op[0];
assign and_pass = AND & op[1];
assign xor_pass = XOR & op[2];
assign or_pass = OR & op[3];

assign fa_out = sum_pass | and_pass | xor_pass | or_pass;


endmodule