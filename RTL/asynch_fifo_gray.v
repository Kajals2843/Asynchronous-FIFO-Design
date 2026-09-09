`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Design Name: async_fifo_gray
// Module Name: async_fifo_gray
// Project Name: Asynchronous FIFO Design
// Tool Versions: Vivado 2025.2
// Description:
//     Asynchronous FIFO using direct Gray-code comparison
//
//     APPROACH 2:
//     Synchronized Gray pointers are directly compared for
//     FIFO FULL and FIFO EMPTY generation.
//
//     Unlike Approach 1, there is NO Gray-to-Binary conversion
//     of the synchronized pointers.
//
//////////////////////////////////////////////////////////////////////////////////

module async_fifo_gray #(
    parameter PTR_WIDTH  = 4,   // Pointer width = address bits + 1 wrap bit
    parameter ADDR_WIDTH = 3    // Address width for 8 FIFO locations
)(
    input        wclk,          // Write clock
    input        rclk,          // Read clock
    input        rst,           // Asynchronous reset

    input  [7:0] din,           // Data input
    input        wr_en,         // Write enable
    input        rd_en,         // Read enable

    output reg [7:0] dout,      // Data output
    output reg       fifo_full, // FIFO full flag
    output reg       fifo_empty // FIFO empty flag
);


    //==================================================================
    // FIFO MEMORY
    //
    // Depth = 2^ADDR_WIDTH = 2^3 = 8 locations
    // Data width = 8 bits
    //
    // mem[0] to mem[7]
    //==================================================================

    reg [7:0] mem [0:7];


    //==================================================================
    // WRITE POINTER
    //
    // wr_ptr_bin       : Current binary write pointer
    // wr_ptr_bin_next  : Next binary write pointer
    //
    // wr_ptr_gray      : Current Gray-code write pointer
    // wr_ptr_gray_next : Next Gray-code write pointer
    //==================================================================

    reg [PTR_WIDTH-1:0] wr_ptr_bin;
    reg [PTR_WIDTH-1:0] wr_ptr_bin_next;

    reg [PTR_WIDTH-1:0] wr_ptr_gray;
    reg [PTR_WIDTH-1:0] wr_ptr_gray_next;


    //==================================================================
    // READ POINTER
    //
    // rd_ptr_bin       : Current binary read pointer
    // rd_ptr_bin_next  : Next binary read pointer
    //
    // rd_ptr_gray      : Current Gray-code read pointer
    // rd_ptr_gray_next : Next Gray-code read pointer
    //==================================================================

    reg [PTR_WIDTH-1:0] rd_ptr_bin;
    reg [PTR_WIDTH-1:0] rd_ptr_bin_next;

    reg [PTR_WIDTH-1:0] rd_ptr_gray;
    reg [PTR_WIDTH-1:0] rd_ptr_gray_next;


    //==================================================================
    // WRITE POINTER SYNCHRONIZER
    //
    // Write pointer crosses from:
    //
    //       WRITE CLOCK DOMAIN
    //                |
    //           wr_ptr_gray
    //                |
    //              FF1
    //                |
    //              FF2
    //                |
    //       READ CLOCK DOMAIN
    //
    // wr_ptr_gray_sync is used for EMPTY generation.
    //==================================================================

    reg [PTR_WIDTH-1:0] wr_ptr_gray_sync_1;
    reg [PTR_WIDTH-1:0] wr_ptr_gray_sync;


    //==================================================================
    // READ POINTER SYNCHRONIZER
    //
    // Read pointer crosses from:
    //
    //       READ CLOCK DOMAIN
    //                |
    //           rd_ptr_gray
    //                |
    //              FF1
    //                |
    //              FF2
    //                |
    //       WRITE CLOCK DOMAIN
    //
    // rd_ptr_gray_sync is used for FULL generation.
    //==================================================================

    reg [PTR_WIDTH-1:0] rd_ptr_gray_sync_1;
    reg [PTR_WIDTH-1:0] rd_ptr_gray_sync;


    //==================================================================
    // WRITE POINTER NEXT-STATE LOGIC
    //
    // Write pointer advances only when:
    //
    //       wr_en     = 1
    //       fifo_full = 0
    //
    // If FIFO is full, the write pointer must not advance.
    //==================================================================

    always @(*) begin

        if (wr_en && !fifo_full)
            wr_ptr_bin_next = wr_ptr_bin + 1'b1;

        else
            wr_ptr_bin_next = wr_ptr_bin;

    end


    //==================================================================
    // WRITE BINARY -> GRAY CONVERSION
    //
    // Gray = Binary XOR (Binary >> 1)
    //
    // This Gray pointer is transferred to the read clock domain.
    //==================================================================

    always @(*) begin

        wr_ptr_gray_next =
            wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    end


    //==================================================================
    // WRITE POINTER REGISTER
    //
    // Updates on the write clock.
    //==================================================================

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


    //==================================================================
    // WRITE DATA INTO FIFO MEMORY
    //
    // Data is written only when:
    //
    //       wr_en = 1
    //       fifo_full = 0
    //
    // The lower ADDR_WIDTH bits of the binary pointer select
    // the memory location.
    //==================================================================

    always @(posedge wclk) begin

        if (wr_en && !fifo_full)
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= din;

    end


    //==================================================================
    // WRITE POINTER SYNCHRONIZER
    //
    // WRITE DOMAIN -> READ DOMAIN
    //
    // Two flip-flops are used to safely synchronize the Gray pointer.
    //==================================================================

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


    //==================================================================
    // READ POINTER NEXT-STATE LOGIC
    //
    // Read pointer advances only when:
    //
    //       rd_en      = 1
    //       fifo_empty = 0
    //
    // If FIFO is empty, the read pointer must not advance.
    //==================================================================

    always @(*) begin

        if (rd_en && !fifo_empty)
            rd_ptr_bin_next = rd_ptr_bin + 1'b1;

        else
            rd_ptr_bin_next = rd_ptr_bin;

    end


    //==================================================================
    // READ BINARY -> GRAY CONVERSION
    //
    // Gray = Binary XOR (Binary >> 1)
    //==================================================================

    always @(*) begin

        rd_ptr_gray_next =
            rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);

    end


    //==================================================================
    // READ POINTER REGISTER
    //
    // Updates on the read clock.
    //==================================================================

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


    //==================================================================
    // READ DATA FROM FIFO MEMORY
    //
    // Data is read only when:
    //
    //       rd_en      = 1
    //       fifo_empty = 0
    //
    // dout is updated on the read clock.
    //==================================================================

    always @(posedge rclk or posedge rst) begin

        if (rst)

            dout <= 8'h00;

        else if (rd_en && !fifo_empty)

            dout <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

    end


    //==================================================================
    // READ POINTER SYNCHRONIZER
    //
    // READ DOMAIN -> WRITE DOMAIN
    //
    // Two flip-flops are used to safely synchronize the Gray pointer.
    //==================================================================

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


    //==================================================================
    // FIFO EMPTY GENERATION
    //
    //              APPROACH 2
    //       DIRECT GRAY-CODE COMPARISON
    //
    // FIFO is empty when the NEXT read pointer equals the
    // synchronized write pointer.
    //
    // No Gray -> Binary conversion is required.
    //
    //       rd_ptr_gray_next == wr_ptr_gray_sync
    //==================================================================

    always @(posedge rclk or posedge rst) begin

        if (rst) begin

            fifo_empty <= 1'b1;

        end

        else begin

            if (rd_ptr_gray_next == wr_ptr_gray_sync)

                fifo_empty <= 1'b1;

            else

                fifo_empty <= 1'b0;

        end

    end


    //==================================================================
    // FIFO FULL GENERATION
    //
    //              APPROACH 2
    //       DIRECT GRAY-CODE COMPARISON
    //
    // For a 4-bit Gray pointer:
    //
    // rd_ptr_gray_sync = g3 g2 g1 g0
    //
    // FULL condition:
    //
    // wr_ptr_gray_next = ~g3 ~g2 g1 g0
    //
    // Therefore, the upper TWO Gray bits are inverted and
    // compared with the next write Gray pointer.
    //
    // For PTR_WIDTH = 4:
    //
    // {~rd_ptr_gray_sync[3:2], rd_ptr_gray_sync[1:0]}
    //
    // No Gray -> Binary conversion is required.
    //==================================================================

    always @(posedge wclk or posedge rst) begin

        if (rst) begin

            fifo_full <= 1'b0;

        end

        else begin

            if (wr_ptr_gray_next ==
                {~rd_ptr_gray_sync[PTR_WIDTH-1:PTR_WIDTH-2],
                  rd_ptr_gray_sync[PTR_WIDTH-3:0]})

                fifo_full <= 1'b1;

            else

                fifo_full <= 1'b0;

        end

    end


endmodule
