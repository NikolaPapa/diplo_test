module cell_array #(
    parameter COLS = 32,   // Number of columns (bits per row)
    parameter ROWS = 32    // Number of rows in the array
)(
    input  logic [COLS-1:0] rd_in_up,
    input  logic [COLS-1:0] rd_in_dn,
    input  logic [COLS-1:0] data_in_up,
    input  logic [COLS-1:0] data_in_dn,     // N-bit data input for write operations
    input  logic [ROWS-1:0] wr_en,          // R-bit write enable, one bit per row
    input  logic [ROWS-1:0] rd_addr_up,  
    input  logic [ROWS-1:0] rd_addr_dn,  
    input  logic [ROWS-1:0] wr_addr_up,  
    input  logic [ROWS-1:0] wr_addr_dn, 
    input  logic clk,                       // Clock signal
    input  logic rst,                       // Reset signal
    input  logic [3:0] op_fa, //choose operation for fa //0 sum 1 and 2 xor 3 or (bits to enable for each op)
    input  logic carry_in,
    output logic [COLS-1:0] wr_out_up,      // read channel out
    output logic [COLS-1:0] wr_out_dn,
    output logic [COLS-1:0] rd_out_up,
    output logic [COLS-1:0] rd_out_dn,    // N-bit data output from the selected row
    output logic [ROWS-1:0] overflow        // Overflow flags, one bit per row
);

    // Intermediate wires for read select and write select signals for each row
    logic [COLS-1:0] row_rd_out_up [ROWS-1:0];    // rd_bus output from each row
    logic [COLS-1:0] row_wr_out_up [ROWS-1:0];    //wr_bus output from each row
    logic [COLS-1:0] row_rd_out_dn [ROWS-1:0];
    logic [COLS-1:0] row_wr_out_dn [ROWS-1:0]; 

    //to see content of registers
    logic [ROWS-1:0][COLS-1:0] debug_all_regs;

    //first row initialization
    reg_row #(.N(COLS)) row_inst_0(
                .wr_in_up(row_wr_out_up[ROWS-2]),  
		.wr_in_dn(data_in_dn),            
                .rd_in_up(row_rd_out_up[ROWS-2]),
		.rd_in_dn(rd_in_dn),        
                .wr_en(wr_en[0]),               // Write enable for this row
                .wr_sel_up(wr_addr_up[0]),
        	.wr_sel_dn(wr_addr_dn[0]),
        	.rd_sel_up(rd_addr_up[0]),
        	.rd_sel_dn(rd_addr_dn[0]),
                .clk(clk),
                .rst(rst),
                .op_fa(op_fa),
                .first_carry(carry_in),
                .rd_out_up(row_rd_out_up[ROWS-1]),  // Data output from this row
                .rd_out_dn(row_rd_out_dn[0]), 
		.wr_out_up(row_wr_out_up[ROWS-1]),  // Write data output from this row
                .wr_out_dn(row_wr_out_dn[0]),
		.overflow(overflow[0]) ,         // Overflow for this row
                .debug_row_reg(debug_all_regs[0])  // Connect debug output
            );
    
    //last row initialization
    reg_row #(.N(COLS)) row_inst_last(
                .wr_in_up(data_in_up),  
		.wr_in_dn(row_wr_out_dn[ROWS-2]),            
                .rd_in_up(rd_in_up), 
		.rd_in_dn(row_rd_out_dn[ROWS-2]),      
                .wr_en(wr_en[ROWS-1]),               // Write enable for this row
                .wr_sel_up(wr_addr_up[ROWS-1]),
        	.wr_sel_dn(wr_addr_dn[ROWS-1]),
        	.rd_sel_up(rd_addr_up[ROWS-1]),
        	.rd_sel_dn(rd_addr_dn[ROWS-1]),
                .clk(clk),
                .rst(rst),
                .op_fa(op_fa),
                .first_carry(carry_in),
                .rd_out_up(row_rd_out_up[0]),     // Data output from this row
                .rd_out_dn(row_rd_out_dn[ROWS-1]),
		.wr_out_up(row_wr_out_up[0]),         // Write data output from this row
                .wr_out_dn(row_wr_out_dn[ROWS-1]),
		.overflow(overflow[ROWS-1]),          // Overflow for this row
                .debug_row_reg(debug_all_regs[ROWS-1])  // Connect debug output
            );

    // Instantiate R rows of reg_row
    genvar row;
    generate
        for (row = 1; row < ROWS-1; row++) begin : row_gen
            reg_row #(.N(COLS)) row_inst (
                .wr_in_up(row_wr_out_up[ROWS-2-row]),  
		.wr_in_dn(row_wr_out_dn[row-1]),            
                .rd_in_up(row_rd_out_up[ROWS-2-row]), 
		.rd_in_dn(row_rd_out_dn[row-1]),      
                .wr_en(wr_en[row]),               // Write enable for this row
                .wr_sel_up(wr_addr_up[row]),
        	.wr_sel_dn(wr_addr_dn[row]),
        	.rd_sel_up(rd_addr_up[row]),
        	.rd_sel_dn(rd_addr_dn[row]),
                .clk(clk),
                .rst(rst),
                .op_fa(op_fa),
                .first_carry(carry_in),
                .rd_out_up(row_rd_out_up[ROWS-1-row]),     // Data output from this row
                .rd_out_dn(row_rd_out_dn[row]),
		.wr_out_up(row_wr_out_up[ROWS-1-row]),     // Write data output from this row
                .wr_out_dn(row_wr_out_dn[row]),
		.overflow(overflow[row]),
                .debug_row_reg(debug_all_regs[row])  // Connect debug output
            );
        end
    endgenerate

    // Output the data from the selected read row
    assign wr_out_up = row_wr_out_up[ROWS-1];
    assign wr_out_dn = row_wr_out_dn[ROWS-1];
    assign rd_out_up = row_rd_out_up[ROWS-1];
    assign rd_out_dn = row_rd_out_dn[ROWS-1];
    
endmodule
