`ifdef MODEL_TECH
	`include "../sys_defs.vh"
`endif

module mem_late8(
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
    logic [31:0] mem [`MEM_32BIT_LINES-1:0];
    
    initial begin
        $readmemh("init_file.txt", mem);
    end

    // Internal signals
    logic [31:0] address_reg;
    logic        valid_access_reg;
    logic        address_phase;
    logic [1:0]  reg_trans;
    // logic        reg_HWRITE;

    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        NONSEQ  = 2'b10
    } htrans_type;

    // logic counter_enable;
    logic [3:0] count_wait;

    // Address and valid access registration
    always_ff @(posedge HCLK) begin //or negedge HRESETn
        if (!HRESETn) begin
            address_reg       <= 32'b0; //no address
            valid_access_reg  <= 1'b0; //not valid
            HREADYOUT         <= 1'b1; //ready to take transactions
            reg_trans         <= IDLE;
        end else if (HREADY && (HTRANS==NONSEQ)) begin
            address_reg       <= HADDR[31:2];
            valid_access_reg  <= (HADDR[1:0]==2'b00) & (HADDR < `MEM_SIZE_IN_BYTES);
            HREADYOUT         <= 1'b0;
            reg_trans         <= NONSEQ;
        end else if ((HREADYOUT==0) && (count_wait==3)) begin
            HREADYOUT         <= 1'b1;
            reg_trans         <= IDLE;
        end
    end

    //if previous address was not valid issue an error, if it was idle issue 0.
    assign HRESP = (reg_trans != IDLE) ? ~valid_access_reg : 0; 

    //count wait cycles until data phase completed
    always_ff @(posedge HCLK) begin
        if (!HRESETn) begin
            count_wait <= 0;
        end
        else begin
            if(HREADYOUT == 0)
                count_wait <= count_wait+1;
            else
                count_wait <= 0;
        end
    end

    // Handle read and write operations during the data phase
    always_ff @(posedge HCLK) begin
        if((HREADYOUT==1'b1) && HWRITE && valid_access_reg && (HTRANS == IDLE)) begin
            mem[address_reg] <= HWDATA;
        end
    end

    // Continuous assignment for read data output
    assign HRDATA = (!HWRITE && valid_access_reg && (HREADYOUT==1)) ? mem[address_reg] : 32'b0;

endmodule