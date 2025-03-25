module micro_control(
    input logic clk,
    input logic rst,
    input logic [4:0] decode_addr,
    input logic id_rf_valid_inst,
    output logic         HWRITE,
    output logic [1:0]   HTRANS,
    output logic [18:0] current_control,
    output logic rf_valid_inst,
    output logic done
);

logic [4:0] current_addr; //uPC like 
//logic [4:0] next_addr;
logic [2:0] cnt;

// always_comb begin
//     if(done) begin
//         next_addr = decode_addr; //next instruction address
//     end
//     else begin
//         next_addr = current_addr + 1;
//     end
// end

// always_ff @(posedge clk) begin
//     if (rst) begin
//         current_addr <= 18; //wait state address
//     end 
//     else begin
//         current_addr <= next_addr;
//     end
// end

always_ff @(posedge clk) begin
    if(rst || done)begin
        cnt <= 0; //reset counter
    end
    else begin
        cnt <= cnt + 1;
    end
end

always_comb begin
    if(id_rf_valid_inst) begin
        current_addr = decode_addr + cnt;
    end
    else current_addr = 18; //wait state
end

//issue HTRANS when lw or sw
always_comb begin
    if (current_addr == 0) begin
        HTRANS = 2'b10;
        HWRITE = 0;
    end
    else if (current_addr == 2) begin
        HTRANS = 2'b10;
        HWRITE = 1;
    end
    else begin
        HTRANS = 2'b00;
        HWRITE = 0;
    end
end


ROM rom(
    current_addr,
    current_control    
);

assign done = current_control[0]; //last bit of the signal

assign rf_valid_inst = id_rf_valid_inst & done; //when the rf stage has control and has completed move control to fetch

endmodule

module ROM(
    input   logic [4:0]  addr,
    output  logic [18:0] out
);

logic [18:0] ROM[23:0];
// br_condition doesn't need to be in memory 
//'b write_en op_enable exp_go_up exp_go_dn data2bus_en dataFM_en 
// pc_plus_en pc_imm_en imm_up_en imm_en op_fa buffer_read buffer_write carry_in inv_en(is_last_signal)

//load
assign ROM[0] = 19'b0_1_10_0_0_0_0_0_1_0001_0000_0; //address phase
assign ROM[1] = 19'b1_0_00_0_1_0_0_0_0_0001_0000_1; //data phase
//store
assign ROM[2] = 19'b0_1_10_0_0_0_0_0_1_0001_0000_0; //address phase
assign ROM[3] = 19'b0_0_10_1_0_0_0_0_0_0001_0000_1; //data phase
//R - types 
assign ROM[4] = 19'b1_1_00_1_0_0_0_0_0_0001_0000_1; //sum
assign ROM[5] = 19'b1_1_00_1_0_0_0_0_0_0010_0000_1; //and
assign ROM[6] = 19'b1_1_00_1_0_0_0_0_0_0100_0000_1; //xor
assign ROM[7] = 19'b1_1_00_1_0_0_0_0_0_1000_0000_1; //or
//I - types
assign ROM[8] = 19'b1_1_00_0_0_0_0_0_1_0001_0000_1; //addi
assign ROM[9] = 19'b1_1_00_0_0_0_0_0_1_0010_0000_1; //andi
assign ROM[10] = 19'b1_1_00_0_0_0_0_0_1_0100_0000_1; //xori
assign ROM[11] = 19'b1_1_00_0_0_0_0_0_1_1000_0000_1; //ori
//U - types
assign ROM[12] = 19'b1_0_00_0_0_0_0_1_0_0001_0000_1; //LUI
assign ROM[13] = 19'b1_0_00_0_0_0_1_0_0_0001_0000_1; //AUIPC
//J - types
assign ROM[14] = 19'b1_0_00_0_0_1_0_0_0_0001_0000_0; //JAL step1 (save PC+4 -> Rd)
assign ROM[15] = 19'b0_0_00_0_0_0_1_0_0_0001_0000_1; //JAL step2 (give back targetPC -> Pc+Imm) target pc available through addr2Mem port.
assign ROM[16] = 19'b1_0_00_0_0_1_0_0_0_0001_0000_0; //JALR step1 (save PC+4 -> Rd)
assign ROM[17] = 19'b0_1_10_0_0_0_0_0_1_0001_0000_1; //JALR step2 (give back targetPC -> Imm+Rs1)
// wait state
assign ROM[18] = 19'b0_0_00_0_0_0_0_0_0_0001_0000_1;
//B - types (BNE/BEQ) same instructions
assign ROM[19] = 19'b0_1_01_1_0_0_0_0_0_0100_0100_0; //BNE step1
assign ROM[20] = 19'b0_0_00_0_0_0_0_0_0_0001_0100_1; //BNE step2
//B - types (BLTU/BGEU) same instructions
assign ROM[21] = 19'b0_1_01_0_0_0_0_0_0_0001_0100_0; //load rs1 into buffer
assign ROM[22] = 19'b0_0_00_0_0_0_0_0_0_0100_0101_0; //xor with 1's and save into buffer
assign ROM[23] = 19'b0_0_01_1_0_0_0_0_0_0001_0010_1; //sum with rs2 and check carry out

//decode the address and get control signals
assign out = ROM[addr];

endmodule
