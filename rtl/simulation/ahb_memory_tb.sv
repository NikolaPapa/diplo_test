`timescale 1ns/1ps

module ahb_memory_tb;

  // Parameters
  localparam MEM_DEPTH = 256;

  // Signals
  logic           HCLK;
  logic           HRESETn;
  logic [31:0]    HADDR;
  logic [2:0]     HSIZE;
  logic           HWRITE;
  logic [31:0]    HWDATA;
  logic           HREADY;
  logic [31:0]    HRDATA;
  logic           HREADYOUT;
  logic           HRESP;
  logic [1:0]     HTRANS;

  // Instantiate the DUT
  ahb_memory #(MEM_DEPTH) dut (
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .HADDR(HADDR),
    .HSIZE(HSIZE),
    .HWRITE(HWRITE),
    .HWDATA(HWDATA),
    .HREADY(HREADY),
    .HTRANS(HTRANS),
    .HRDATA(HRDATA),
    .HREADYOUT(HREADYOUT),
    .HRESP(HRESP)
  );


  integer i;
  // initialize memory
  initial begin
    $readmemh("mem_AHB_hex.txt",dut.mem);
  end
  // Clock generation
  initial HCLK = 0;
  always #5 HCLK = ~HCLK; // 100 MHz clock

  // Test procedure
  initial begin
    $display("Starting Testbench...");

    // Reset the system
    HRESETn = 0;
    HADDR = 32'h00000000;
    HWRITE = 0;
    HWDATA = 32'h00000000;
    HREADY = 1;
    HTRANS = 2'b00; // IDLE state
    #20;
    HRESETn = 1;

    //start
    @(posedge HCLK);
    HWRITE = 0;
    HADDR = 8;
    HTRANS = 2'b10;
    @(posedge HCLK);

    $display("Trying to read normally");
    $monitor("%0t | %h | %h | %b |",$time , HADDR, HRDATA, HRESP);

    for(i=0; i<8; i++) begin
      @(posedge HCLK);
      HADDR = i;// next address
      @(posedge HCLK);
      HADDR = 16;// rand address
    end

    //test idle
    @(posedge HCLK);
    HTRANS = 2'b00;

    $display("Trying to read during IDLE state");
    for(i=0; i<8; i++) begin
      @(posedge HCLK);
      HADDR = i;// next address
      @(posedge HCLK);
      HADDR = 16;// rand address
    end

    //test address then data then
    $display("Test write 2 IDLE, read");
    for(i=0; i<8; i++) begin
      @(posedge HCLK); // at clk give address
      HADDR = i;// next address
      HWDATA = 0;
      HTRANS = 2'b10;
      HWRITE = 1;
      @(posedge HCLK); // at clk read address and give data
      HWDATA = 16 + i;
      HADDR = 0;
      HTRANS = 2'b00; //idle or the address would be considered the next write address
      @(posedge HCLK); // at clk give 1 idle
      
      @(posedge HCLK); // read idle

      @(posedge HCLK); // give address for read
      HWRITE = 0;
      HTRANS = 2'b10;
      HADDR = i;

      @(posedge HCLK); // read address and give idle
      HADDR = 0; 
      HTRANS = 2'b00;
      @(posedge HCLK); // read idle and read data
    end



    // // Assert that the write completed successfully
    // assert(HRESP == 0) else $fatal("Write operation failed with error response.");
    
    
    // // Assert read data matches written data
    // assert(HRDATA == 32'hDEADBEEF) else $fatal("Read operation returned incorrect data: %h", HRDATA);
    
    // // Assert error response for invalid access
    // assert(HRESP == 1) else $fatal("Expected error response for invalid access but got OKAY.");

    $display("Testbench completed successfully.");
    $stop;
  end

endmodule
