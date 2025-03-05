module micro_control(
    input logic clk,
    input logic rst,
    input logic [4:0] decode_addr,
    input logic id_rf_valid_inst,
    output logic         HWRITE,
    output logic [1:0]   HTRANS,
    output logic [14:0] current_control,
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
    output  logic [14:0] out
);

logic [14:0] ROM[18:0];
// br_condition doesn't need to be in memory 
//'b write_en op_enable exp_go_up exp_go_dn data2bus_en dataFM_en pc_plus_en pc_imm_en imm_up_en imm_en op_fa (is_last_signal)

//load
assign ROM[0] = 15'b0_1_10_0_0_0_0_0_1_0001_0; //address phase
assign ROM[1] = 15'b1_0_00_0_1_0_0_0_0_0001_1; //data phase
//store
assign ROM[2] = 15'b0_1_10_0_0_0_0_0_1_0001_0; //address phase
assign ROM[3] = 15'b0_0_10_1_0_0_0_0_0_0001_1; //data phase
//R - types 
assign ROM[4] = 15'b1_1_00_1_0_0_0_0_0_0001_1; //sum
assign ROM[5] = 15'b1_1_00_1_0_0_0_0_0_0010_1; //and
assign ROM[6] = 15'b1_1_00_1_0_0_0_0_0_0100_1; //xor
assign ROM[7] = 15'b1_1_00_1_0_0_0_0_0_1000_1; //or
//I - types
assign ROM[8] = 15'b1_1_00_0_0_0_0_0_1_0001_1; //addi
assign ROM[9] = 15'b1_1_00_0_0_0_0_0_1_0010_1; //andi
assign ROM[10] = 15'b1_1_00_0_0_0_0_0_1_0100_1; //xori
assign ROM[11] = 15'b1_1_00_0_0_0_0_0_1_1000_1; //ori
//U - types
assign ROM[12] = 15'b1_0_00_0_0_0_0_1_0_0001_1; //LUI
assign ROM[13] = 15'b1_0_00_0_0_0_1_0_0_0001_1; //AUIPC
//J - types
assign ROM[14] = 15'b1_0_00_0_0_1_0_0_0_0001_0; //JAL step1 (save PC+4 -> Rd)
assign ROM[15] = 15'b0_0_00_0_0_0_1_0_0_0001_1; //JAL step2 (give back targetPC -> Pc+Imm) target pc available through addr2Mem port.
assign ROM[16] = 15'b1_0_00_0_0_1_0_0_0_0001_0; //JALR step1 (save PC+4 -> Rd)
assign ROM[17] = 15'b0_1_10_0_0_0_0_0_1_0001_1; //JALR step2 (give back targetPC -> Imm+Rs1)
// wait state
assign ROM[18] = 15'b0_0_00_0_0_0_0_0_0_0001_1;


//decode the address and get control signals
assign out = ROM[addr];

endmodule



// input logic exp_go_dn, //for BNE and BEQ
// input logic buffer_read,
// input logic buffer_write,
// input logic buffer_inverse,// not of B when subtracting
// input logic carry_in,
// input logic  [1:0] br_cond,