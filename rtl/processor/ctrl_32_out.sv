module ctrl_32_out(
    input logic [31:0] in_sig,
    input logic ctrl,           // Control signal
    output logic [31:0] out    // 32-bit output
);

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin
            assign out[i] = ctrl & in_sig[i]; // AND gate for each output bit
        end
    endgenerate

endmodule