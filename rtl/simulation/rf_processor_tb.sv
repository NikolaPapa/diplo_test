`ifdef MODEL_TECH
	`include "../sys_defs.vh"
`endif

module rf_processor_tb;

////
//Data Memory AHB
////
// // Parameters
//   localparam MEM_DEPTH = 32768;
//   localparam MEM_32BIT_LINES = (MEM_DEPTH/4);

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
    

logic [31:0] 	instruction;
logic [31:0] 	pc_addr;
logic [1:0]   im_command;



// Outputs from IF-Stage 
logic [31:0] 	if_PC_out;
logic [31:0] 	if_NPC_out;
logic [31:0] 	if_IR_out;
logic         if_valid_inst_out;

// Outputs from IF/ID Pipeline Register
logic [31:0] 	if_id_PC;
logic [31:0] 	if_id_NPC;
logic [31:0] 	if_id_IR;
logic         if_id_valid_inst;

// Outputs from ID/RF Pipeline Register
logic [31:0] 	id_rf_PC;
logic [31:0] 	id_rf_NPC;
logic [31:0] 	id_rf_IR;
logic   		  id_rf_valid_inst;


rf_processor proc_module(
                      .HCLK(HCLK),
                      .HRESETn(HRESETn),
                      .instruction(instruction),
                      .pc_addr(pc_addr),
                      .im_command(im_command),

                      //AHB connnections
                      .HRDATA(HRDATA),     
                      .HREADY(HREADYOUT),  	 
                      .HRESP(HRESP),      
                      .HADDR(HADDR),
                      .HSIZE(HSIZE),
                      .HWRITE(HWRITE),
                      .HWDATA(HWDATA),   
                      .HTRANS(HTRANS),  

                      .if_PC_out(if_PC_out),
                      .if_NPC_out(if_NPC_out),
                      .if_IR_out(if_IR_out),
                      .if_valid_inst_out(if_valid_inst_out),
                      .if_id_PC(if_id_PC),
                      .if_id_NPC(if_id_NPC),
                      .if_id_IR(if_id_IR),
                      .if_id_valid_inst(if_id_valid_inst),
                      .id_rf_PC(id_rf_PC),
                      .id_rf_NPC(id_rf_NPC),
                      .id_rf_IR(id_rf_IR),
                      .id_rf_valid_inst(id_rf_valid_inst));

logic [3:0] mem2proc_response_im;
logic [3:0] mem2proc_tag_im;

logic [31:0] im_data;
assign im_data=0;

mem IM(
       .clk(HCLK),
       .proc2mem_addr(pc_addr),
       .proc2mem_data(im_data),
       .proc2mem_command(im_command),
       .mem2proc_response(mem2proc_response_im),
       .mem2proc_data(instruction),
       .mem2proc_tag(mem2proc_tag_im));


  
  assign HREADY = 1;//no other subordinates

  // Instantiate the DataMemory
  ahb_memory DM (
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

initial begin
	HCLK=0;
	forever #5 HCLK=~HCLK;
end

initial begin
    $readmemh("bb_sortH.txt",IM.unified_memory);
    // $readmemh("test5H.txt",IM.unified_memory);
    // $readmemh("mem_hex.txt",DM.mem);
    $readmemh("init_file.txt",DM.mem);
end

initial begin
    HRESETn=0;
    @(posedge HCLK);
    HRESETn=1;
    for(int i=0;i<50000;i++) begin
        @(posedge HCLK);    
    end
    $stop;
end


endmodule