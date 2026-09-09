`timescale 1ns / 1ps

module async_fifo_binary #(
    parameter PTR_WIDTH  = 4,
    parameter ADDR_WIDTH = 3
)(
    input        wclk,
    input        rclk,
    input        rst,

    input  [3:0] din,
    input        wr_en,
    input        rd_en,

    output reg [3:0] dout,
    output reg       fifo_full,
    output reg       fifo_empty
);

    //==========================================================
    // FIFO MEMORY
    //==========================================================
    reg [7:0] mem [0:7];


    //==========================================================
    // WRITE POINTER
    //==========================================================
    reg [PTR_WIDTH-1:0] wr_ptr_bin;
    reg [PTR_WIDTH-1:0] wr_ptr_bin_next;

    reg [PTR_WIDTH-1:0] wr_ptr_gray;
    reg [PTR_WIDTH-1:0] wr_ptr_gray_next;


    //==========================================================
    // READ POINTER
    //==========================================================
    reg [PTR_WIDTH-1:0] rd_ptr_bin;
    reg [PTR_WIDTH-1:0] rd_ptr_bin_next;

    reg [PTR_WIDTH-1:0] rd_ptr_gray;
    reg [PTR_WIDTH-1:0] rd_ptr_gray_next;


    //==========================================================
    // WRITE POINTER SYNCHRONIZED INTO READ CLOCK DOMAIN
    //==========================================================
    reg [PTR_WIDTH-1:0] wr_ptr_gray_sync_1;
    reg [PTR_WIDTH-1:0] wr_ptr_gray_sync;


    //==========================================================
    // READ POINTER SYNCHRONIZED INTO WRITE CLOCK DOMAIN
    //==========================================================
    reg [PTR_WIDTH-1:0] rd_ptr_gray_sync_1;
    reg [PTR_WIDTH-1:0] rd_ptr_gray_sync;


    //==========================================================
    // GRAY -> BINARY CONVERSION
    // Used only in Approach 1
    //==========================================================
    reg [PTR_WIDTH-1:0] wr_ptr_bin_sync;
    reg [PTR_WIDTH-1:0] rd_ptr_bin_sync;

    integer i;


    //==========================================================
    // WRITE NEXT POINTER
    //==========================================================
    always @(*) begin

        if (wr_en && !fifo_full)
            wr_ptr_bin_next = wr_ptr_bin + 1'b1;
        else
            wr_ptr_bin_next = wr_ptr_bin;

    end


    //==========================================================
    // WRITE BINARY -> GRAY
    //==========================================================
    always @(*) begin

        wr_ptr_gray_next =
            wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    end


    //==========================================================
    // WRITE POINTER REGISTER
    //==========================================================
    always @(posedge wclk or posedge rst) begin

        if (rst) begin
            wr_ptr_bin  <= {PTR_WIDTH{1'b0}};
            wr_ptr_gray <= {PTR_WIDTH{1'b0}};
        end

        else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end

    end


    //==========================================================
    // WRITE DATA INTO MEMORY
    //==========================================================
    always @(posedge wclk or posedge rst) begin

        if (rst) begin
            // No memory reset required
        end

        else if (wr_en && !fifo_full) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= din;
        end

    end


    //==========================================================
    // WRITE POINTER -> READ CLOCK DOMAIN
    // 2-FLOP SYNCHRONIZER
    //==========================================================
    always @(posedge rclk or posedge rst) begin

        if (rst) begin
            wr_ptr_gray_sync_1 <= {PTR_WIDTH{1'b0}};
            wr_ptr_gray_sync   <= {PTR_WIDTH{1'b0}};
        end

        else begin
            wr_ptr_gray_sync_1 <= wr_ptr_gray;
            wr_ptr_gray_sync   <= wr_ptr_gray_sync_1;
        end

    end


    //==========================================================
    // READ NEXT POINTER
    //==========================================================
    always @(*) begin

        if (rd_en && !fifo_empty)
            rd_ptr_bin_next = rd_ptr_bin + 1'b1;
        else
            rd_ptr_bin_next = rd_ptr_bin;

    end


    //==========================================================
    // READ BINARY -> GRAY
    //==========================================================
    always @(*) begin

        rd_ptr_gray_next =
            rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);

    end


    //==========================================================
    // READ POINTER REGISTER
    //==========================================================
    always @(posedge rclk or posedge rst) begin

        if (rst) begin
            rd_ptr_bin  <= {PTR_WIDTH{1'b0}};
            rd_ptr_gray <= {PTR_WIDTH{1'b0}};
        end

        else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end

    end


    //==========================================================
    // READ DATA FROM MEMORY
    //==========================================================
    always @(posedge rclk or posedge rst) begin

        if (rst) begin
            dout <= 8'b0;
        end

        else if (rd_en && !fifo_empty) begin
            dout <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
        end

    end


    //==========================================================
    // READ POINTER -> WRITE CLOCK DOMAIN
    // 2-FLOP SYNCHRONIZER
    //==========================================================
    always @(posedge wclk or posedge rst) begin

        if (rst) begin
            rd_ptr_gray_sync_1 <= {PTR_WIDTH{1'b0}};
            rd_ptr_gray_sync   <= {PTR_WIDTH{1'b0}};
        end

        else begin
            rd_ptr_gray_sync_1 <= rd_ptr_gray;
            rd_ptr_gray_sync   <= rd_ptr_gray_sync_1;
        end

    end


    //==========================================================
    // GRAY -> BINARY
    // SYNCHRONIZED WRITE POINTER
    //
    // Approach 1:
    // Convert wr_ptr_gray_sync back to binary
    //==========================================================
    always @(*) begin

        wr_ptr_bin_sync[PTR_WIDTH-1] =
            wr_ptr_gray_sync[PTR_WIDTH-1];

        for (i = PTR_WIDTH-2; i >= 0; i = i-1) begin

            wr_ptr_bin_sync[i] =
                wr_ptr_bin_sync[i+1] ^
                wr_ptr_gray_sync[i];

        end

    end


    //==========================================================
    // GRAY -> BINARY
    // SYNCHRONIZED READ POINTER
    //
    // Approach 1:
    // Convert rd_ptr_gray_sync back to binary
    //==========================================================
    always @(*) begin

        rd_ptr_bin_sync[PTR_WIDTH-1] =
            rd_ptr_gray_sync[PTR_WIDTH-1];

        for (i = PTR_WIDTH-2; i >= 0; i = i-1) begin

            rd_ptr_bin_sync[i] =
                rd_ptr_bin_sync[i+1] ^
                rd_ptr_gray_sync[i];

        end

    end


    //==========================================================
    // FIFO FULL
    //
    // Binary comparison:
    //
    // Lower ADDR_WIDTH bits are equal
    // MSB/wrap bit is different
    //
    // Example:
    // rd_ptr = 0000
    // wr_ptr = 1000
    //          ^^^
    //          FIFO full after 8 writes
    //==========================================================
    always @(posedge wclk or posedge rst) begin

        if (rst) begin
            fifo_full <= 1'b0;
        end

        else begin

            if ((wr_ptr_bin_next[ADDR_WIDTH-1:0] ==
                 rd_ptr_bin_sync[ADDR_WIDTH-1:0]) &&
                (wr_ptr_bin_next[PTR_WIDTH-1] !=
                 rd_ptr_bin_sync[PTR_WIDTH-1]))

                fifo_full <= 1'b1;

            else
                fifo_full <= 1'b0;

        end

    end


    //==========================================================
    // FIFO EMPTY
    //
    // Binary comparison:
    //
    // Read pointer == synchronized write pointer
    //==========================================================
    always @(posedge rclk or posedge rst) begin

        if (rst) begin
            fifo_empty <= 1'b1;
        end

        else begin

            if (rd_ptr_bin_next == wr_ptr_bin_sync)
                fifo_empty <= 1'b1;

            else
                fifo_empty <= 1'b0;

        end

    end

endmodule
