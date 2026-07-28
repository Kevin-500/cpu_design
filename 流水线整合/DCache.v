`timescale 1ns / 1ps

`include "defines.vh"

module DCache (
    input  wire                       cpu_clk,
    input  wire                       cpu_rst,
    input  wire [3:0]                 data_ren,
    input  wire [31:0]                data_addr,
    output reg                        data_valid,
    output reg  [31:0]                data_rdata,
    input  wire [3:0]                 data_wen,
    input  wire [31:0]                data_wdata,
    output reg                        data_wresp,
    input  wire                       dev_wrdy,
    output reg  [3:0]                 cpu_wen,
    output reg  [31:0]                cpu_waddr,
    output reg  [31:0]                cpu_wdata,
    input  wire                       dev_rrdy,
    output reg  [3:0]                 cpu_ren,
    output reg  [31:0]                cpu_raddr,
    input  wire                       dev_rvalid,
    input  wire [`DC_BLK_SIZE-1:0]    dev_rdata
);
    localparam IDLE      = 3'd0;
    localparam R_LOOKUP  = 3'd1;
    localparam R_REQ     = 3'd2;
    localparam R_WAIT    = 3'd3;
    localparam W_LOOKUP  = 3'd4;
    localparam W_REQ     = 3'd5;
    localparam W_WAIT    = 3'd6;

`ifdef ENABLE_DCACHE
    localparam CACHE_ENABLED = 1'b1;
`else
    localparam CACHE_ENABLED = 1'b0;
`endif

    reg [2:0] state;
    reg [31:0] req_addr;
    reg [3:0] req_enable;
    reg [31:0] req_wdata;
    reg write_hit;
    reg [21:0] tags [0:63];
    reg [63:0] valid_bits;
    integer i;

    wire uncached = (req_addr[31:16] == 16'hffff) || !CACHE_ENABLED;
    wire [5:0] ram_addr = (state == IDLE) ? data_addr[9:4] : req_addr[9:4];
    wire [127:0] line_rdata;
    wire read_hit = !uncached && valid_bits[req_addr[9:4]] &&
                    (tags[req_addr[9:4]] == req_addr[31:10]);
    wire refill_we = (state == R_WAIT) && dev_rvalid && !uncached;
    wire write_update_we = (state == W_WAIT) && dev_wrdy && write_hit;
    wire cache_we = refill_we || write_update_we;

    reg [127:0] updated_line;
    wire [127:0] refill_line = dev_rdata;
    wire [127:0] cache_wdata = refill_we ? refill_line : updated_line;

    cache_line_ram U_data (
        .clk(cpu_clk), .rst(cpu_rst), .we(cache_we), .addr(ram_addr),
        .wdata(cache_wdata), .rdata(line_rdata)
    );

    function [31:0] select_word;
        input [127:0] line;
        input [1:0] offset;
        begin
            case (offset)
                2'd0: select_word = line[31:0];
                2'd1: select_word = line[63:32];
                2'd2: select_word = line[95:64];
                default: select_word = line[127:96];
            endcase
        end
    endfunction

    function [31:0] merge_word;
        input [31:0] base_word;
        input [3:0]  byte_enable;
        input [31:0] write_data;
        begin
            merge_word = base_word;
            if (byte_enable[0]) merge_word[7:0]   = write_data[7:0];
            if (byte_enable[1]) merge_word[15:8]  = write_data[15:8];
            if (byte_enable[2]) merge_word[23:16] = write_data[23:16];
            if (byte_enable[3]) merge_word[31:24] = write_data[31:24];
        end
    endfunction

    wire [31:0] updated_word = merge_word(
        select_word(line_rdata, req_addr[3:2]), req_enable, req_wdata
    );

    always @(*) begin
        updated_line = line_rdata;
        case (req_addr[3:2])
            2'd0: updated_line[31:0] = updated_word;
            2'd1: updated_line[63:32] = updated_word;
            2'd2: updated_line[95:64] = updated_word;
            default: updated_line[127:96] = updated_word;
        endcase
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            state <= IDLE;
            req_addr <= 32'h0;
            req_enable <= 4'h0;
            req_wdata <= 32'h0;
            write_hit <= 1'b0;
            valid_bits <= 64'h0;
            for (i = 0; i < 64; i = i + 1)
                tags[i] <= 22'h0;
        end else begin
            case (state)
                IDLE: begin
                    if (data_wen != 4'h0) begin
                        req_addr <= data_addr;
                        req_enable <= data_wen;
                        req_wdata <= data_wdata;
                        state <= W_LOOKUP;
                    end else if (data_ren != 4'h0) begin
                        req_addr <= data_addr;
                        req_enable <= data_ren;
                        state <= R_LOOKUP;
                    end
                end
                R_LOOKUP: begin
                    if (read_hit)
                        state <= IDLE;
                    else if (dev_rrdy)
                        state <= R_WAIT;
                    else
                        state <= R_REQ;
                end
                R_REQ: begin
                    if (dev_rrdy)
                        state <= R_WAIT;
                end
                R_WAIT: begin
                    if (dev_rvalid) begin
                        if (!uncached) begin
                            tags[req_addr[9:4]] <= req_addr[31:10];
                            valid_bits[req_addr[9:4]] <= 1'b1;
                        end
                        state <= IDLE;
                    end
                end
                W_LOOKUP: begin
                    write_hit <= !uncached && valid_bits[req_addr[9:4]] &&
                                 (tags[req_addr[9:4]] == req_addr[31:10]);
                    state <= W_REQ;
                end
                W_REQ: begin
                    if (dev_wrdy)
                        state <= W_WAIT;
                end
                W_WAIT: begin
                    if (dev_wrdy)
                        state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    always @(*) begin
        data_valid = 1'b0;
        data_rdata = 32'h0;
        data_wresp = 1'b0;
        cpu_ren = 4'h0;
        cpu_raddr = uncached ? req_addr : {req_addr[31:4], 4'h0};
        cpu_wen = 4'h0;
        cpu_waddr = req_addr;
        cpu_wdata = req_wdata;

        case (state)
            R_LOOKUP: begin
                if (read_hit) begin
                    data_valid = 1'b1;
                    data_rdata = select_word(line_rdata, req_addr[3:2]);
                end else begin
                    cpu_ren = uncached ? req_enable : 4'hf;
                end
            end
            R_REQ: begin
                cpu_ren = uncached ? req_enable : 4'hf;
            end
            R_WAIT: begin
                if (dev_rvalid) begin
                    data_valid = 1'b1;
`ifdef ENABLE_DCACHE
                    data_rdata = uncached ? dev_rdata[31:0] :
                                 select_word(dev_rdata, req_addr[3:2]);
`else
                    data_rdata = dev_rdata[31:0];
`endif
                end
            end
            W_REQ: begin
                if (dev_wrdy)
                    cpu_wen = req_enable;
            end
            W_WAIT: begin
                if (dev_wrdy)
                    data_wresp = 1'b1;
            end
            default: begin end
        endcase
    end
endmodule
