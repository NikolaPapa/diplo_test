module ahb_memory #(parameter MEM_DEPTH = 256) (
    input  logic           HCLK,       // System clock
    input  logic           HRESETn,    // Active-low reset
    input  logic  [31:0]   HADDR,      // AHB address bus
    input  logic  [2:0]    HSIZE,      // Transfer size //not used
    input  logic           HWRITE,     // Write enable
    input  logic  [31:0]   HWDATA,     // Write data bus
    input  logic           HREADY,     // Transfer ready input from master
    input  logic  [1:0]    HTRANS,     // Transfer type (IDLE, BUSY, NONSEQ, SEQ)
    output logic  [31:0]   HRDATA,     // Read data bus
    output logic           HREADYOUT,  // Transfer done
    output logic           HRESP       // Transfer response (OKAY = 0, ERROR = 1)
);

    // Memory storage
    logic [31:0] mem [MEM_DEPTH-1:0];

    // Internal signals
    logic [31:0] address_reg;
    logic        valid_access_reg;
    logic        address_phase;
    logic [1:0]  reg_trans;
    logic        reg_HWRITE;

    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        NONSEQ  = 2'b10
    } htrans_type;

    // Address and valid access registration
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            address_reg       <= 32'b0; //no address
            valid_access_reg  <= 1'b0; //not valid
            reg_trans    <= 2'b00; //idle
            reg_HWRITE        <= 1'b0;
        end else if (HREADY && reg_trans==IDLE) begin //when previous transfer ended so HREADY is 1. We keep the address and the transaction
            address_reg       <= HADDR;
            valid_access_reg  <= (HADDR[31:2] < MEM_DEPTH);
            reg_trans    <= HTRANS;
            reg_HWRITE   <= HWRITE;
        end else begin
            reg_trans    <= IDLE; //push idle transfer
        end
    end

    //if previous address was not valid issue an error, if it was idle issue 0.
    assign HRESP = (reg_trans != IDLE) ? ~valid_access_reg : 0; 

    // Handle read and write operations during the data phase
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HREADYOUT  <= 1'b1;
        end else begin
            if(reg_trans != IDLE && reg_HWRITE && valid_access_reg) begin
                    mem[address_reg] <= HWDATA;
            end
        end
    end

    //Hreadyout is to tell master if to sample the data for simplicity no wait cycles

    // Continuous assignment for read data output
    assign HRDATA = (!reg_HWRITE && valid_access_reg && reg_trans != IDLE) ? mem[address_reg] : 32'b0;

    // Initialize memory
    initial begin
        for(int i=0; i<MEM_DEPTH; i=i+1) begin
            mem[i] = 32'h0;
        end
    end
endmodule