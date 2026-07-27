`timescale 1ns / 1ps

module axi_bridge #(
    parameter integer N = 6
) (
    input  wire             aclk,
    input  wire             aresetn,
    input  wire [31:0]      s_axi_awaddr,
    input  wire [7:0]       s_axi_awlen,
    input  wire [2:0]       s_axi_awsize,
    input  wire [1:0]       s_axi_awburst,
    input  wire             s_axi_awvalid,
    output reg              s_axi_awready,
    input  wire [31:0]      s_axi_wdata,
    input  wire [3:0]       s_axi_wstrb,
    input  wire             s_axi_wlast,
    input  wire             s_axi_wvalid,
    output reg              s_axi_wready,
    output reg  [1:0]       s_axi_bresp,
    output reg              s_axi_bvalid,
    input  wire             s_axi_bready,
    input  wire [31:0]      s_axi_araddr,
    input  wire [7:0]       s_axi_arlen,
    input  wire [2:0]       s_axi_arsize,
    input  wire [1:0]       s_axi_arburst,
    input  wire             s_axi_arvalid,
    output reg              s_axi_arready,
    output reg  [31:0]      s_axi_rdata,
    output reg  [1:0]       s_axi_rresp,
    output reg              s_axi_rlast,
    output reg              s_axi_rvalid,
    input  wire             s_axi_rready,
    output reg  [N*32-1:0] m_axi_awaddr,
    output reg  [N*8-1:0]  m_axi_awlen,
    output reg  [N*3-1:0]  m_axi_awsize,
    output reg  [N*2-1:0]  m_axi_awburst,
    output reg  [N-1:0]    m_axi_awvalid,
    input  wire [N-1:0]    m_axi_awready,
    output reg  [N*32-1:0] m_axi_wdata,
    output reg  [N*4-1:0]  m_axi_wstrb,
    output reg  [N-1:0]    m_axi_wlast,
    output reg  [N-1:0]    m_axi_wvalid,
    input  wire [N-1:0]    m_axi_wready,
    input  wire [N*2-1:0]  m_axi_bresp,
    input  wire [N-1:0]    m_axi_bvalid,
    output reg  [N-1:0]    m_axi_bready,
    output reg  [N*32-1:0] m_axi_araddr,
    output reg  [N*8-1:0]  m_axi_arlen,
    output reg  [N*3-1:0]  m_axi_arsize,
    output reg  [N*2-1:0]  m_axi_arburst,
    output reg  [N-1:0]    m_axi_arvalid,
    input  wire [N-1:0]    m_axi_arready,
    input  wire [N*32-1:0] m_axi_rdata,
    input  wire [N*2-1:0]  m_axi_rresp,
    input  wire [N-1:0]    m_axi_rlast,
    input  wire [N-1:0]    m_axi_rvalid,
    output reg  [N-1:0]    m_axi_rready
);
    reg write_active;
    reg [2:0] write_sel;
    reg write_invalid;
    reg write_data_done;
    reg read_active;
    reg [2:0] read_sel;
    reg read_invalid;

    wire [2:0] aw_decode = decode(s_axi_awaddr);
    wire [2:0] ar_decode = decode(s_axi_araddr);

    function [2:0] decode;
        input [31:0] address;
        begin
            if (address < 32'h0008_0000) decode = 3'd0;
            else begin
                case (address[31:12])
                    20'hffff0: decode = 3'd1;
                    20'hffff1: decode = 3'd2;
                    20'hffff2: decode = 3'd3;
                    20'hffff3: decode = 3'd4;
                    20'hffff4: decode = 3'd5;
                    default: decode = 3'd7;
                endcase
            end
        end
    endfunction

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            write_active <= 1'b0;
            write_sel <= 3'h0;
            write_invalid <= 1'b0;
            write_data_done <= 1'b0;
        end else begin
            if (!write_active && s_axi_awvalid && s_axi_awready) begin
                write_active <= 1'b1;
                write_sel <= aw_decode;
                write_invalid <= (aw_decode == 3'd7);
                write_data_done <= 1'b0;
            end else if (write_active && s_axi_wvalid && s_axi_wready) begin
                write_data_done <= 1'b1;
            end

            if (write_active && write_data_done && s_axi_bvalid && s_axi_bready) begin
                write_active <= 1'b0;
                write_data_done <= 1'b0;
            end
        end
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            read_active <= 1'b0;
            read_sel <= 3'h0;
            read_invalid <= 1'b0;
        end else begin
            if (!read_active && s_axi_arvalid && s_axi_arready) begin
                read_active <= 1'b1;
                read_sel <= ar_decode;
                read_invalid <= (ar_decode == 3'd7);
            end else if (read_active && s_axi_rvalid && s_axi_rready && s_axi_rlast) begin
                read_active <= 1'b0;
            end
        end
    end

    integer i;
    always @(*) begin
        m_axi_awaddr = {N{s_axi_awaddr}};
        m_axi_awlen = {N{s_axi_awlen}};
        m_axi_awsize = {N{s_axi_awsize}};
        m_axi_awburst = {N{s_axi_awburst}};
        m_axi_awvalid = {N{1'b0}};
        s_axi_awready = 1'b0;
        if (!write_active && s_axi_awvalid) begin
            if (aw_decode == 3'd7)
                s_axi_awready = 1'b1;
            else begin
                m_axi_awvalid[aw_decode] = 1'b1;
                s_axi_awready = m_axi_awready[aw_decode];
            end
        end

        m_axi_wdata = {N{s_axi_wdata}};
        m_axi_wstrb = {N{s_axi_wstrb}};
        m_axi_wlast = {N{s_axi_wlast}};
        m_axi_wvalid = {N{1'b0}};
        s_axi_wready = 1'b0;
        if (write_active && !write_data_done) begin
            if (write_invalid)
                s_axi_wready = 1'b1;
            else begin
                m_axi_wvalid[write_sel] = s_axi_wvalid;
                s_axi_wready = m_axi_wready[write_sel];
            end
        end

        m_axi_bready = {N{1'b0}};
        s_axi_bresp = 2'b00;
        s_axi_bvalid = 1'b0;
        if (write_active && write_data_done) begin
            if (write_invalid) begin
                s_axi_bresp = 2'b11;
                s_axi_bvalid = 1'b1;
            end else begin
                s_axi_bresp = m_axi_bresp[write_sel*2 +: 2];
                s_axi_bvalid = m_axi_bvalid[write_sel];
                m_axi_bready[write_sel] = s_axi_bready;
            end
        end

        m_axi_araddr = {N{s_axi_araddr}};
        m_axi_arlen = {N{s_axi_arlen}};
        m_axi_arsize = {N{s_axi_arsize}};
        m_axi_arburst = {N{s_axi_arburst}};
        m_axi_arvalid = {N{1'b0}};
        s_axi_arready = 1'b0;
        if (!read_active && s_axi_arvalid) begin
            if (ar_decode == 3'd7)
                s_axi_arready = 1'b1;
            else begin
                m_axi_arvalid[ar_decode] = 1'b1;
                s_axi_arready = m_axi_arready[ar_decode];
            end
        end

        m_axi_rready = {N{1'b0}};
        s_axi_rdata = 32'h0;
        s_axi_rresp = 2'b00;
        s_axi_rlast = 1'b0;
        s_axi_rvalid = 1'b0;
        if (read_active) begin
            if (read_invalid) begin
                s_axi_rresp = 2'b11;
                s_axi_rlast = 1'b1;
                s_axi_rvalid = 1'b1;
            end else begin
                s_axi_rdata = m_axi_rdata[read_sel*32 +: 32];
                s_axi_rresp = m_axi_rresp[read_sel*2 +: 2];
                s_axi_rlast = m_axi_rlast[read_sel];
                s_axi_rvalid = m_axi_rvalid[read_sel];
                m_axi_rready[read_sel] = s_axi_rready;
            end
        end
    end
endmodule
