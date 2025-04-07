module reg_row #(
    parameter N = 32  // Number of columns (bits per row)
)(
    input  logic [N-1:0] rd_in_up,    // N-bit data input for the row
    input  logic [N-1:0] rd_in_dn,
    input  logic [N-1:0] wr_in_up,
    input  logic [N-1:0] wr_in_dn,      
    input  logic wr_en,              // Write enable for the row
    input  logic rd_sel_up,             // Read bus select for the row
    input  logic rd_sel_dn,
    input  logic wr_sel_up,
    input  logic wr_sel_dn,             // Write bus select for the row
    input  logic clk,                // Clock signal
    input  logic rst,                // Reset signal
    input  logic [3:0] op_fa, //choose operation for fa //0 sum 1 and 2 xor 3 or (bits to enable for each op)
    input  logic first_carry,
    output logic [N-1:0] rd_out_up,   // N-bit data output from the row
    output logic [N-1:0] rd_out_dn,
    output logic [N-1:0] wr_out_up,
    output logic [N-1:0] wr_out_dn,   // out of write
    output logic overflow,            // Overflow from the last column
    output logic [N-1:0] debug_row_reg, //content of register for debugging
    output logic last_carry_in // in order to determine real overflow in signed numbers
);

    // Internal carry signals between cells in the row
    logic [N-1:0] carry_in;          // Carry input for each column
    logic [N-1:0] carry_out;         // Carry output for each column
    

    // Set the carry-in of the first column to 0
    assign carry_in[0] = first_carry;

    // First Column Instantiation - Carry_in is set to 0
    reg_cell cell_0 (
        .c_in(carry_in[0]),           // First column, carry_in = 0
        .rd_in_up(rd_in_up[0]),          // Data output for read
        .rd_in_dn(rd_in_dn[0]),
	    .wr_in_up(wr_in_up[0]),           // Data input for write
        .wr_in_dn(wr_in_dn[0]),
	    .clk(clk),
        .rst(rst),
        .wr_sel_up(wr_sel_up),
        .wr_sel_dn(wr_sel_dn),
        .rd_sel_up(rd_sel_up),
        .rd_sel_dn(rd_sel_dn),
        .wr_en(wr_en),                // Write enable for the row
        .op_fa(op_fa),
        .c_out(carry_out[0]),         // Carry output from this cell
        .rd_out_up(rd_out_up[0]),         // Data output from this cell
        .rd_out_dn(rd_out_dn[0]),
	    .wr_out_up(wr_out_up[0]),
	    .wr_out_dn(wr_out_dn[0]),       // Write data output from this cell
        .debug_bit_reg(debug_row_reg[0])  // Connect debug output
    );

    // Remaining Columns Instantiation
    genvar col;
    generate
        for (col = 1; col < N; col++) begin : columns
            reg_cell bit_cell (
                .c_in(carry_out[col-1]),  // Carry in from the previous column
                .rd_in_up(rd_in_up[col]),          // Data output for read
        	    .rd_in_dn(rd_in_dn[col]),
                .wr_in_up(wr_in_up[col]),           // Data input for write
        	    .wr_in_dn(wr_in_dn[col]),
                .clk(clk),
                .rst(rst),
                .wr_sel_up(wr_sel_up),
        	    .wr_sel_dn(wr_sel_dn),
        	    .rd_sel_up(rd_sel_up),
        	    .rd_sel_dn(rd_sel_dn),
                .wr_en(wr_en),            // Write enable for the row
                .op_fa(op_fa),
                .c_out(carry_out[col]),   // Carry output from this cell
                .rd_out_up(rd_out_up[col]),     // Data output from this cell
        	    .rd_out_dn(rd_out_dn[col]),
		        .wr_out_up(wr_out_up[col]),
		        .wr_out_dn(wr_out_dn[col]),      // Write data output from this cell
                .debug_bit_reg(debug_row_reg[col])  // Connect debug output
            );
        end
    endgenerate

    // Connect the final carry_out of the last column to the overflow output
    assign overflow = carry_out[N-1];
    assign last_carry_in = carry_out[N-2];

endmodule
