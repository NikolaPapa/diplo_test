module decoder_2ctrl(
    input logic [4:0] index,     // 5-bit index to select one of the 32 outputs
    input logic [1:0] ctrl,           // Control signal
    output logic [31:0] out1,    // 32-bit output
    output logic [31:0] out2
);

    logic [31:0] decode_out;
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin
            assign decode_out[i] = (index == i); // AND gate for each output bit
        end
    endgenerate

    generate
        for (i = 0; i < 32; i = i + 1) begin
            assign out1[i] = ctrl[0] & decode_out[i]; // AND gate for each output bit
            assign out2[i] = ctrl[1] & decode_out[i];
        end
    endgenerate

endmodule