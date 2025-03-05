`timescale 1ns/1ps

module top_tb;

  // Parameters for the top module
  parameter COLS = 32;
  parameter ROWS = 32;

  // Testbench signals
  logic clk;
  logic rst;
  logic [4:0] decode_addr;
  logic done;

  logic [4:0] rd_index;
  logic [4:0] rs1_index;
  logic [4:0] rs2_index;
  logic [COLS-1:0] immediate;
  logic [COLS-1:0] pc_plus4;
  logic [COLS-1:0] pc_reg;
  logic [COLS-1:0] dataFromMem;
  logic [COLS-1:0] data2Mem;
  logic [COLS-1:0] addr2Mem;
  logic [COLS-1:0] rd_out_dn;
  logic [ROWS-1:0] ovf_Check;

  // Instantiate the DUT (Device Under Test)
  top #(
    .COLS(COLS),
    .ROWS(ROWS)
  ) dut (
    .clk(clk),
    .rst(rst),
    .decode_addr(decode_addr),
    .done(done),
    .rd_index(rd_index),
    .rs1_index(rs1_index),
    .rs2_index(rs2_index),
    .immediate(immediate),
    .pc_plus4(pc_plus4),
    .pc_reg(pc_reg),
    .dataFromMem(dataFromMem),
    .data2Mem(data2Mem),
    .addr2Mem(addr2Mem),
    .rd_out_dn(rd_out_dn),
    .ovf_Check(ovf_Check)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 10 ns clock period
  end

  // Test stimulus
  initial begin
    $display("START of Test!");
    // Reset the design
    rst = 1;
    decode_addr = 0;
    rd_index = 5'd0;
    rs1_index = 5'd1;
    rs2_index = 5'd2;
    immediate = 32'h0000_0010;
    pc_plus4 = 32'h0000_0004;
    pc_reg = 32'h0000_0000;
    dataFromMem = 32'hABCD_1234;

    #10 rst = 0; // Release reset after 10 ns

    // Sample operation: load r1, r2(imm)
    rd_index = 1; 
    rs1_index = 2; // is 0
    pc_plus4 = 8;
    pc_reg = 4;
    immediate = 20;// so addr2 memory should be 20
    dataFromMem = 24; // shouuld write 24 -> r1
    decode_addr = 0;//load operation
    //observe addr2mem
    #10;
    //observe loading 
    //next decode address store
    decode_addr = 2; //store operation

    //observe addr2mem 
    #10;
    
    //done = 1
    #10;



    //store the data to mem s
    // store r1, r2(imm)
    rs2_index = 1;
    rs1_index = 2;
    immediate = 20;
    #10;

    // observe data2mem
    decode_addr = 18; //wait state
    #10;
    
    $display("END of Test!");

    #50;
    $stop;
  end

  // Monitor outputs
  initial begin
    $monitor($time, " done=%b, data2Mem=%h, addr2Mem=%h, rd_out_dn=%h", 
             done, data2Mem, addr2Mem, rd_out_dn);
  end

endmodule
