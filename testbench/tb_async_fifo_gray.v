`timescale 1ns/1ps

module tb_async_fifo_gray;

    //========================================================
    // Testbench signals
    //========================================================

    reg        wclk;
    reg        rclk;
    reg        rst;

    reg        wr_en;
    reg        rd_en;

    reg [7:0]  din;
    wire [7:0] dout;

    wire       fifo_full;
    wire       fifo_empty;


    //========================================================
    // DUT - Approach 2
    //========================================================

    async_fifo_gray DUT (

        .wclk       (wclk),
        .rclk       (rclk),
        .rst        (rst),

        .wr_en      (wr_en),
        .rd_en      (rd_en),

        .din        (din),
        .dout       (dout),

        .fifo_full  (fifo_full),
        .fifo_empty (fifo_empty)
    );


    //========================================================
    // Write Clock
    // Period = 20 ns
    //========================================================

    always #10 wclk = ~wclk;


    //========================================================
    // Read Clock
    // Period = 30 ns
    //========================================================

    always #15 rclk = ~rclk;


    //========================================================
    // Test Sequence
    //========================================================

    initial begin

        // Initial values
        wclk  = 1'b0;
        rclk  = 1'b0;

        rst   = 1'b1;

        wr_en = 1'b0;
        rd_en = 1'b0;

        din   = 8'h00;


        //====================================================
        // RESET
        //====================================================

        #50;

        rst = 1'b0;

        $display("======================================");
        $display(" RESET RELEASED ");
        $display("======================================");


        //====================================================
        // WRITE 8 DATA VALUES
        //====================================================

        @(negedge wclk);
        wr_en = 1'b1;
        din = 8'h0A;

        @(negedge wclk);
        din = 8'h0B;

        @(negedge wclk);
        din = 8'h0C;

        @(negedge wclk);
        din = 8'h0D;

        @(negedge wclk);
        din = 8'h0E;

        @(negedge wclk);
        din = 8'h0F;

        @(negedge wclk);
        din = 8'hA0;

        @(negedge wclk);
        din = 8'hBA;


        // Stop writing
        @(negedge wclk);
        wr_en = 1'b0;
        din   = 8'h00;


        $display("======================================");
        $display(" 8 DATA VALUES WRITTEN ");
        $display("======================================");


        //====================================================
        // WAIT FOR FIFO FULL
        //====================================================

        wait(fifo_full == 1'b1);

        $display("FIFO FULL = 1");
        $display("FIFO is FULL");


        //====================================================
        // TRY EXTRA WRITE
        // This write should NOT be accepted
        //====================================================

        @(negedge wclk);

        wr_en = 1'b1;
        din   = 8'hFF;

        @(negedge wclk);

        wr_en = 1'b0;
        din   = 8'h00;

        $display("Extra write 0xFF attempted");
        $display("It should NOT be stored because FIFO is FULL");


        //====================================================
        // WAIT BEFORE READING
        //====================================================

        #50;


        //====================================================
        // READ 8 DATA VALUES
        //====================================================

        @(negedge rclk);
        rd_en = 1'b1;

        @(negedge rclk);
        rd_en = 1'b1;

        @(negedge rclk);
        rd_en = 1'b1;

        @(negedge rclk);
        rd_en = 1'b1;

        @(negedge rclk);
        rd_en = 1'b1;

        @(negedge rclk);
        rd_en = 1'b1;

        @(negedge rclk);
        rd_en = 1'b1;

        @(negedge rclk);
        rd_en = 1'b1;


        // Stop reading
        @(negedge rclk);
        rd_en = 1'b0;


        $display("======================================");
        $display(" 8 DATA VALUES READ ");
        $display("======================================");


        //====================================================
        // WAIT FOR FIFO EMPTY
        //====================================================

        wait(fifo_empty == 1'b1);

        $display("FIFO EMPTY = 1");
        $display("FIFO is EMPTY");


        //====================================================
        // TRY EXTRA READ
        // This read should NOT be accepted
        //====================================================

        @(negedge rclk);

        rd_en = 1'b1;

        @(negedge rclk);

        rd_en = 1'b0;

        $display("Extra read attempted");
        $display("It should NOT be accepted because FIFO is EMPTY");


        //====================================================
        // END SIMULATION
        //====================================================

        #50;

        $display("======================================");
        $display(" TEST COMPLETED ");
        $display("======================================");

        $finish;

    end

endmodule
