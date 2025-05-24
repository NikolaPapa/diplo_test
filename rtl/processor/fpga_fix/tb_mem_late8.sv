module tb_mem_late8;

    // Clock and reset
    logic HCLK;
    logic HRESETn;

    // AHB-Lite signals
    logic [31:0] HADDR;
    logic [2:0]  HSIZE = 3'b010;  // Word size (ignored)
    logic        HWRITE;
    logic [31:0] HWDATA;
    logic        HREADY;
    logic [1:0]  HTRANS;
    logic [31:0] HRDATA;
    logic        HREADYOUT;
    logic        HRESP;

    // Clock generation
    always #5 HCLK = ~HCLK; // 100MHz clock

    // Instantiate DUT
    mem_late8 dut (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HADDR(HADDR),
        .HSIZE(HSIZE),
        .HWRITE(HWRITE),
        .HWDATA(HWDATA),
        .HREADY(HREADY),
        .HTRANS(HTRANS),
        .HRDATA(HRDATA),
        .HREADYOUT(HREADYOUT),
        .HRESP(HRESP)
    );

    // HREADY feedback logic (slave-to-master loop)
    assign HREADY = HREADYOUT;

    // Test sequence task
    task ahb_write(input [31:0] addr, input [31:0] data);
        begin
            wait(HREADY);
            @(posedge HCLK);
            HADDR  <= addr;
            HWRITE <= 1;
            HWDATA <= data;
            HTRANS <= 2'b10; // NONSEQ
            $display("WRITE REQUEST: addr=0x%08X data=0x%08X @ time=%0t", addr, data, $time);
            wait(HREADYOUT == 1);
            @(posedge HCLK);
            HTRANS <= 2'b00; // IDLE
            HWRITE <= 0;
            HADDR  <= 0;
            HWDATA <= 0;
        end
    endtask

    task ahb_read(input [31:0] addr);
        begin
            wait(HREADY);
            @(posedge HCLK);
            HADDR  <= addr;
            HWRITE <= 0;
            HTRANS <= 2'b10; // NONSEQ
            $display("READ REQUEST: addr=0x%08X @ time=%0t", addr, $time);
            wait(HREADYOUT == 1);
            @(posedge HCLK);
            $display("READ RESPONSE: addr=0x%08X data=0x%08X HRESP=%0b @ time=%0t", addr, HRDATA, HRESP, $time);
            HTRANS <= 2'b00; // IDLE
            HADDR  <= 0;
        end
    endtask

    // Reset logic
    initial begin
        HCLK = 0;
        HRESETn = 0;
        HADDR = 0;
        HWRITE = 0;
        HWDATA = 0;
        HTRANS = 2'b00;
        #10;
        HRESETn = 1;
        #10;
        $display("RESET DEASSERTED @ time=%0t", $time);

        // Begin test sequence
        #10;

        // --- Test: Two Writes ---
        // ahb_write(32'h00000000, 32'hDEADBEEF);
        HADDR = 32'h00000004;
        HTRANS = 2'b10;
        HWRITE = 1;
        #10; //should capture address and HREADYOUT go low
        HADDR = 0;
        HTRANS = 2'b00;
        #40;
        HWDATA = 32'hDEADBEEF;
        #10;// should be captured

        // ahb_write(32'h00000004, 32'hCAFEBABE);
        HADDR = 32'h00000008;
        HTRANS = 2'b10;
        HWRITE = 1;
        #10; //should capture address and HREADYOUT go low
        HADDR = 0;
        HTRANS = 2'b00;
        #40;
        HWDATA = 32'hCAFEBABE;
        #10;// should be captured

        // --- Test: Two Reads ---
        // ahb_read(32'h00000000);
        HADDR = 32'h00000004;
        HTRANS = 2'b10;
        HWRITE = 0;
        #10; //should capture address and HREADYOUT go low
        HADDR = 0;
        HTRANS = 2'b00;
        #40;
        $display("READ RESPONSE: data=0x%08X HRESP=%0b @ time=%0t", HRDATA, HRESP, $time);
        #10;// should be done



        // ahb_read(32'h00000004);
        HADDR = 32'h00000008;
        HTRANS = 2'b10;
        HWRITE = 0;
        #10; //should capture address and HREADYOUT go low
        HADDR = 0;
        HTRANS = 2'b00;
        #40;
        $display("READ RESPONSE: data=0x%08X HRESP=%0b @ time=%0t", HRDATA, HRESP, $time);
        #10;// should be done

        // --- Test: Invalid Address ---
        // ahb_read(32'h00010000); // Out of range
        HADDR = 32'h00010000;
        HTRANS = 2'b10;
        HWRITE = 0;
        #10; //should capture address and HREADYOUT go low
        HADDR = 0;
        HTRANS = 2'b00;
        #40;
        $display("READ RESPONSE: data=0x%08X HRESP=%0b @ time=%0t", HRDATA, HRESP, $time);
        #10;// should be done


        // --- Test: Unaligned Address ---
        // ahb_write(32'h00000002, 32'hBADF00D0); // Should be ignored or error
        HADDR = 32'h00000002;
        HTRANS = 2'b10;
        HWRITE = 1;
        #10; //should capture address and HREADYOUT go low
        HADDR = 0;
        HTRANS = 2'b00;
        #40;
        HWDATA = 32'hBADF00D0;
        #10;

        // ahb_read(32'h00000002);
        HADDR = 32'h00000002;
        HTRANS = 2'b10;
        HWRITE = 0;
        #10; //should capture address and HREADYOUT go low
        HADDR = 0;
        HTRANS = 2'b00;
        #40;
        $display("READ RESPONSE: data=0x%08X HRESP=%0b @ time=%0t", HRDATA, HRESP, $time);
        #10;// should be done


        $display("Check unaligned address access handling.");

        // Stop simulation
        #10;
        $display("TESTBENCH COMPLETED @ time=%0t", $time);
        $stop;
    end

endmodule
