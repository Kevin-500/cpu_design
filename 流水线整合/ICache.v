`timescale 1ns / 1ps

`include "defines.vh"

module ICache (
    input  wire                       cpu_clk,
    input  wire                       cpu_rst,
    input  wire                       inst_rreq,
    input  wire [31:0]                inst_addr,
    output reg                        inst_valid,
    output reg  [31:0]                inst_out,
    input  wire                       dev_rrdy,
    output reg  [3:0]                 cpu_ren,
    output reg  [31:0]                cpu_raddr,
    input  wire                       dev_rvalid,
    input  wire [`IC_BLK_SIZE-1:0]    dev_rdata
);
    localparam IDLE      = 3'd0;
    localparam LOOKUP    = 3'd1;
    localparam MISS_REQ  = 3'd2;
    localparam MISS_WAIT = 3'd3;

`ifdef ENABLE_ICACHE
    localparam CACHE_ENABLED = 1'b1;
`else
    localparam CACHE_ENABLED = 1'b0;
`endif

    reg [2:0] state;
    reg [31:0] req_addr;
    reg [21:0] tags [0:63];
    reg [63:0] valid_bits;
    integer i;

    wire [5:0] ram_addr = (state == IDLE) ? inst_addr[9:4] : req_addr[9:4];
    wire [127:0] line_rdata;
    wire [127:0] refill_line = dev_rdata;
    wire refill_we = CACHE_ENABLED && (state == MISS_WAIT) && dev_rvalid;
    wire hit = CACHE_ENABLED && valid_bits[req_addr[9:4]] &&
               (tags[req_addr[9:4]] == req_addr[31:10]);

    cache_line_ram U_data (
        .clk(cpu_clk), .we(refill_we), .addr(ram_addr),
        .wdata(refill_line), .rdata(line_rdata)
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

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            state <= IDLE;
            req_addr <= 32'h0;
            valid_bits <= 64'h0;
            for (i = 0; i < 64; i = i + 1)
                tags[i] <= 22'h0;
        end else begin
            case (state)
                IDLE: begin
                    if (inst_rreq) begin
                        req_addr <= inst_addr;
                        state <= LOOKUP;
                    end
                end
                LOOKUP: begin
                    if (hit)
                        state <= IDLE;
                    else if (dev_rrdy)
                        state <= MISS_WAIT;
                    else
                        state <= MISS_REQ;
                end
                MISS_REQ: begin
                    if (dev_rrdy)
                        state <= MISS_WAIT;
                end
                MISS_WAIT: begin
                    if (dev_rvalid) begin
                        if (CACHE_ENABLED) begin
                            tags[req_addr[9:4]] <= req_addr[31:10];
                            valid_bits[req_addr[9:4]] <= 1'b1;
                        end
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

    always @(*) begin
        inst_valid = 1'b0;
        inst_out = 32'h0;
        cpu_ren = 4'h0;
        cpu_raddr = CACHE_ENABLED ? {req_addr[31:4], 4'h0} : req_addr;

        case (state)
            LOOKUP: begin
                if (hit) begin
                    inst_valid = 1'b1;
                    inst_out = select_word(line_rdata, req_addr[3:2]);
                end else if (dev_rrdy) begin
                    cpu_ren = CACHE_ENABLED ? 4'hf : 4'hf;
                end
            end
            MISS_REQ: begin
                if (dev_rrdy)
                    cpu_ren = 4'hf;
            end
            MISS_WAIT: begin
                if (dev_rvalid) begin
                    inst_valid = 1'b1;
`ifdef ENABLE_ICACHE
                    inst_out = select_word(dev_rdata, req_addr[3:2]);
`else
                    inst_out = dev_rdata[31:0];
`endif
                end
            end
            default: begin end
        endcase
    end
endmodule
