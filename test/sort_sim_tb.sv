`timescale 1ns/1ps

`include "defines.vh"

module sort_sim_tb;

    // ============================================================
    // Clock & Reset
    // ============================================================
    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;   // 100MHz clock

    // ============================================================
    // UART simulation settings (match baud 115200 @ 100MHz = ~868 clocks/bit)
    // ============================================================
    localparam CLK_FREQ   = 100000000;
    localparam BAUD_RATE  = 115200;
    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;  // 868

    // ============================================================
    // cpu_top AXI interface
    // ============================================================
    wire [31:0] awaddr;    wire [7:0] awlen;    wire [2:0] awsize;
    wire [1:0] awburst;    wire awvalid;        wire awready;
    wire [31:0] wdata;     wire [3:0] wstrb;    wire wlast;
    wire wvalid;           wire wready;          wire bready;
    wire [1:0] bresp;      wire bvalid;
    wire [31:0] araddr;    wire [7:0] arlen;    wire [2:0] arsize;
    wire [1:0] arburst;    wire arvalid;        wire arready;
    wire rready;           reg [31:0] rdata = 0;
    reg [1:0] rresp = 0;   reg rlast = 0;       reg rvalid = 0;

    cpu_top u_cpu_top (
        .cpu_clk        (clk),
        .cpu_rst        (rst),
        .m_axi_awaddr   (awaddr),
        .m_axi_awlen    (awlen),
        .m_axi_awsize   (awsize),
        .m_axi_awburst  (awburst),
        .m_axi_awvalid  (awvalid),
        .m_axi_awready  (awready),
        .m_axi_wdata    (wdata),
        .m_axi_wstrb    (wstrb),
        .m_axi_wlast    (wlast),
        .m_axi_wvalid   (wvalid),
        .m_axi_wready   (wready),
        .m_axi_bready   (bready),
        .m_axi_bresp    (bresp),
        .m_axi_bvalid   (bvalid),
        .m_axi_araddr   (araddr),
        .m_axi_arlen    (arlen),
        .m_axi_arsize   (arsize),
        .m_axi_arburst  (arburst),
        .m_axi_arvalid  (arvalid),
        .m_axi_arready  (arready),
        .m_axi_rready   (rready),
        .m_axi_rdata    (rdata),
        .m_axi_rresp    (rresp),
        .m_axi_rlast    (rlast),
        .m_axi_rvalid   (rvalid)
    );

    // ============================================================
    // AXI Slave model: memory + UART emulation
    // ============================================================
    reg [31:0] memory [0:65535];    // 256KB memory

    // UART input buffer (pre-loaded test input)
    reg [7:0] uart_inbuf [0:255];
    integer   uart_rd_idx = 0;
    integer   uart_wr_count = 0;
    integer   cycles = 0;
    integer   i;

    // ---- AXI write channel ----
    reg aw_hold = 0, w_hold = 0;
    reg [31:0] awaddr_q, wdata_q;
    reg [3:0] wstrb_q;

    assign awready = !aw_hold && !bvalid;
    assign wready  = !w_hold  && !bvalid;
    assign bvalid  = bvalid_reg;
    assign bresp   = 2'b00;
    reg bvalid_reg = 0;

    always @(posedge clk) begin
        if (awvalid && awready) begin
            aw_hold <= 1; awaddr_q <= awaddr;
        end
        if (wvalid && wready) begin
            w_hold <= 1; wdata_q <= wdata; wstrb_q <= wstrb;
        end

        // Commit write
        if (aw_hold && w_hold && !bvalid_reg) begin
            if (awaddr_q == 32'hFFFF3004) begin
                // UART TX: print to console
                $write("%c", wdata_q[7:0]);
                $fflush();
            end else if (awaddr_q[31:16] != 16'hFFFF) begin
                // Normal memory write
                if (wstrb_q[0]) memory[awaddr_q[17:2]][7:0]   <= wdata_q[7:0];
                if (wstrb_q[1]) memory[awaddr_q[17:2]][15:8]  <= wdata_q[15:8];
                if (wstrb_q[2]) memory[awaddr_q[17:2]][23:16] <= wdata_q[23:16];
                if (wstrb_q[3]) memory[awaddr_q[17:2]][31:24] <= wdata_q[31:24];
            end
            aw_hold <= 0; w_hold <= 0; bvalid_reg <= 1;
        end else if (bvalid_reg && bready) begin
            bvalid_reg <= 0;
        end
    end

    // ---- AXI read channel ----
    reg read_active = 0;
    reg [31:0] read_addr_q;
    reg [7:0] read_len_q, read_beat_q;

    assign arready = !read_active && !rvalid;

    function [31:0] emulate_read;
        input [31:0] addr;
        begin
            if (addr == 32'hFFFF3008) begin
                // UART status: bit0 = RX not empty
                emulate_read = (uart_rd_idx < uart_wr_count) ? 32'h1 : 32'h0;
            end else if (addr == 32'hFFFF3000) begin
                // UART RX data
                if (uart_rd_idx < uart_wr_count) begin
                    emulate_read = {24'h0, uart_inbuf[uart_rd_idx]};
                end else begin
                    emulate_read = 0;
                end
            end else if (addr == 32'hFFFF4000 || addr == 32'hFFFF4008) begin
                // Timer: return cycle counter
                emulate_read = (addr == 32'hFFFF4008) ? 32'h0 : cycles;
            end else if (addr[31:16] == 16'hFFFF) begin
                emulate_read = 32'h0;
            end else begin
                emulate_read = memory[addr[17:2]];
            end
        end
    endfunction

    always @(posedge clk) begin
        if (arvalid && arready) begin
            read_active  <= 1;
            read_addr_q  <= araddr;
            read_len_q   <= arlen;
            read_beat_q  <= 0;
        end
        if (read_active && !rvalid) begin
            rdata  <= emulate_read(read_addr_q);
            rlast  <= (read_beat_q == read_len_q);
            rvalid <= 1;
            // Advance UART read pointer after each RX byte read
            if (read_addr_q == 32'hFFFF3000 && uart_rd_idx < uart_wr_count)
                uart_rd_idx <= uart_rd_idx + 1;
        end else if (rvalid && rready) begin
            rvalid <= 0;
            if (rlast) begin
                read_active <= 0;
                rlast <= 0;
            end else begin
                read_addr_q  <= read_addr_q + 4;
                read_beat_q  <= read_beat_q + 1;
            end
        end
    end

    // ============================================================
    // UART TX monitor: decode CPU's TX output
    // (Already handled in the write channel for address 0xFFFF3004)
    // ============================================================

    // ============================================================
    // UART input: pre-load sort test data
    // Use fixed-width register + reverse loop to match the pattern
    // from cpu_pipeline_axi_program_tb.sv that is known to work in Vivado.
    // ============================================================
    task push_sort_input;
        begin
            // Phase 0: 8 integers, separated by spaces
            // Phase 1: array size = 10 (numbers auto-generated by fast_rand)
            // Full input: "12 34 56 78 90 12 34 56\n10\n"
            //             |----------- 23 chars ----------|  |2c|
            // Total = 23 + 1 + 2 + 1 = 27 chars, no null in register
            automatic reg [8*27-1:0] full = "12 34 56 78 90 12 34 56\n10\n";
            integer j;
            for (j = 26; j >= 0; j = j - 1)
                uart_inbuf[uart_wr_count++] = full[j*8 +: 8];
        end
    endtask

    // ============================================================
    // Simulation control
    // ============================================================
    reg [1023:0] prog_file;
    integer      finish_flag;

    initial begin
        // Default program file
        prog_file = "sort_test.mem";

        // Allow override via +IMAGE= command-line option
        if ($value$plusargs("IMAGE=%s", prog_file) == 0) begin
            $display("NOTE: Using default program file: %s", prog_file);
            $display("      Override with +IMAGE=<file.mem>");
        end

        // Load program into memory
        $readmemh(prog_file, memory);

        // Pre-load UART input using verified fixed-width approach
        push_sort_input();

        // Reset
        rst = 1;
        repeat (10) @(posedge clk);
        @(negedge clk);
        rst = 0;

        finish_flag = 0;
    end

    // ============================================================
    // System tasks for Verilator compatibility
    // ============================================================
    // $value$plusargs and $readmemh are standard system tasks
    // They work in both Vivado XSim and Verilator

    // ============================================================
    // Cycle counter & timeout
    // ============================================================
    always @(posedge clk) begin
        if (!rst) cycles <= cycles + 1;
    end

    // Timeout after 5 million cycles (~50ms @ 100MHz)
    always @(posedge clk) begin
        if (!rst && cycles > 5000000 && !finish_flag) begin
            $display("\n[TB] TIMEOUT at cycle %0d", cycles);
            $finish;
        end
    end

    // ============================================================
    // Print simulation header
    // ============================================================
    initial begin
        $display("===========================================");
        $display(" Sort Test Simulation");
        $display(" CPU: 流水线整合 (pipeline)");
        $display(" Clock: %0d MHz", CLK_FREQ / 1000000);
        $display("===========================================");
        $display("");
    end

endmodule
