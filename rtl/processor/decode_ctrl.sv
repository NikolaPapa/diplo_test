module decode_ctrl(
    input logic [4:0] index,     // 5-bit index to select one of the 32 outputs
    input logic ctrl,           // Control signal
    output logic [31:0] out    // 32-bit output
);

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin
            assign out[i] = ctrl & (index == i); // AND gate for each output bit
        end
    endgenerate

endmodule