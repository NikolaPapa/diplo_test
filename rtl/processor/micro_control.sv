module micro_control(
    input logic clk,
    input logic rst,
    input logic [4:0] decode_addr,
    input logic id_rf_valid_inst,
    input logic hready_in,
    output logic transfer_on,
    output logic transfer_done,
    output logic         HWRITE,
    output logic [1:0]   HTRANS,
    output logic [19:0] current_control,
    output logic rf_valid_inst_out,
    output logic done
);

logic [4:0] current_addr; //uPC like 
logic [2:0] cnt;
// logic rf_valid_inst;
// logic transfer_on;
// logic transfer_done;

always_ff @(posedge clk) begin
    if(rst || (done && transfer_done))begin
        cnt <= 0; //reset counter
    end
    else begin
        if (!transfer_on)
            cnt <= cnt + 1;
    end
end

always_comb begin
    if(id_rf_valid_inst) begin
        current_addr = decode_addr + cnt;
    end
    else current_addr = 18; //wait state
end

/////////



//////// wait cycles for the bridge
always_ff @(posedge clk) begin
    if(rst)begin
        transfer_on <=0;
    end
    else begin
    if((current_addr == 0)|| (current_addr ==2)) begin
        transfer_on <= 1;
    end
    else if (transfer_on && hready_in) begin
        transfer_on <= 0;
    end 
    end
end

assign transfer_done = transfer_on ? hready_in : 1'b1;

//issue HTRANS when lw or sw
always_comb begin
    if (current_addr == 0) begin
        HTRANS = 2'b10;
        // HWRITE = 0;
    end
    else if (current_addr == 2) begin
        HTRANS = 2'b10;
        // HWRITE = 1;
    end
    else begin
        HTRANS = 2'b00;
        // HWRITE = 0;
    end
end

always_comb begin
    if((current_addr == 2) || (current_addr == 3))begin
        HWRITE = 1;
    end
    else HWRITE = 0;
end



ROM rom(
    .addr(current_addr),
    .out(current_control)    
);

assign done = current_control[0]; //last bit of the signal

assign rf_valid_inst_out = id_rf_valid_inst & done & transfer_done; 
//when the rf stage has control and has completed move control to fetch

// always_ff @( posedge clk ) begin
//     if (rst) begin
//         rf_valid_inst_out <=0;
//     end
//     else begin
//         rf_valid_inst_out <= rf_valid_inst;
//     end
// end

endmodule

module ROM(
    input   logic [4:0]  addr,
    output  logic [19:0] out
);

logic [19:0] ROM[27:0];
// br_condition doesn't need to be in memory 
//'b write_en op_enable exp_go_up exp_go_dn data2bus_en dataFM_en 
// pc_plus_en pc_imm_en imm_up_en imm_en op_fa shift_en buffer_write buffer_go_up carry_in inv_en(is_last_signal)

//load
assign ROM[0] = 20'b0_1_10_0_0_0_0_0_1_0001_0_00_00_0; //address phase
assign ROM[1] = 20'b1_0_00_0_1_0_0_0_0_0001_0_00_00_1; //data phase
//store
assign ROM[2] = 20'b0_1_10_0_0_0_0_0_1_0001_0_00_00_0; //address phase
assign ROM[3] = 20'b0_0_10_1_0_0_0_0_0_0001_0_00_00_1; //data phase
//R - types 
assign ROM[4] = 20'b1_1_00_1_0_0_0_0_0_0001_0_00_00_1; //sum
assign ROM[5] = 20'b1_1_00_1_0_0_0_0_0_0010_0_00_00_1; //and
assign ROM[6] = 20'b1_1_00_1_0_0_0_0_0_0100_0_00_00_1; //xor
assign ROM[7] = 20'b1_1_00_1_0_0_0_0_0_1000_0_00_00_1; //or
//I - types
assign ROM[8] = 20'b1_1_00_0_0_0_0_0_1_0001_0_00_00_1; //addi
assign ROM[9] = 20'b1_1_00_0_0_0_0_0_1_0010_0_00_00_1; //andi
assign ROM[10] = 20'b1_1_00_0_0_0_0_0_1_0100_0_00_00_1; //xori
assign ROM[11] = 20'b1_1_00_0_0_0_0_0_1_1000_0_00_00_1; //ori
//U - types
assign ROM[12] = 20'b1_0_00_0_0_0_0_1_0_0001_0_00_00_1; //LUI
assign ROM[13] = 20'b1_0_00_0_0_0_1_0_0_0001_0_00_00_1; //AUIPC
//J - types
assign ROM[14] = 20'b1_0_00_0_0_1_0_0_0_0001_0_00_00_0; //JAL step1 (save PC+4 -> Rd)
assign ROM[15] = 20'b0_0_00_0_0_0_1_0_0_0001_0_00_00_1; //JAL step2 (give back targetPC -> Pc+Imm) target pc available through addr2Mem port.
assign ROM[16] = 20'b1_0_00_0_0_1_0_0_0_0001_0_00_00_0; //JALR step1 (save PC+4 -> Rd)
assign ROM[17] = 20'b0_1_10_0_0_0_0_0_1_0001_0_00_00_1; //JALR step2 (give back targetPC -> Imm+Rs1)
// wait state
assign ROM[18] = 20'b0_0_00_0_0_0_0_0_0_0001_0_00_00_1;
//B - types (BNE/BEQ) same instructions
assign ROM[19] = 20'b0_1_01_1_0_0_0_0_0_0100_0_10_00_0; //BNE xor A and B
assign ROM[20] = 20'b0_0_00_0_0_0_0_0_0_0001_0_00_01_1; //BNE sum with 1's and look the carry out
//B - types (BLTU/BGEU) same instructions
assign ROM[21] = 20'b0_1_01_0_0_0_0_0_0_0001_0_10_00_0; //load rs1 into buffer
assign ROM[22] = 20'b0_0_00_0_0_0_0_0_0_0100_0_11_01_0; //xor with 1's and save into buffer
assign ROM[23] = 20'b0_0_01_1_0_0_0_0_0_0001_0_01_10_1; //sum with rs2 and check carry out
//we need to swap rs1 and rs2 beforehand so we have rs1 - rs2 and not the other way around

//SUB instruction
assign ROM[24] = 20'b0_1_01_0_0_0_0_0_0_0001_0_10_00_0; //load rs1 into buffer
assign ROM[25] = 20'b0_0_00_0_0_0_0_0_0_0100_0_11_01_0; //xor with 1's and save into buffer
assign ROM[26] = 20'b1_0_01_1_0_0_0_0_0_0001_0_01_10_1; //sum with rs2 and save into buffer

//shift bit
assign ROM[27] = 20'b1_0_01_1_0_0_0_0_0_0001_1_00_00_1;

//decode the address and get control signals
assign out = ROM[addr];

endmodule
