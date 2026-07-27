`timescale 1ns / 1ps

module uart_wrap #(
    parameter integer CLK_FREQ  = 50000000,
    parameter integer BAUD_RATE = 115200
) (
    input  wire         aclk,
    input  wire         aresetn,
    input  wire [31:0]  s_axi_awaddr,
    input  wire [7:0]   s_axi_awlen,
    input  wire [2:0]   s_axi_awsize,
    input  wire [1:0]   s_axi_awburst,
    input  wire         s_axi_awvalid,
    output wire         s_axi_awready,
    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wlast,
    input  wire         s_axi_wvalid,
    output wire         s_axi_wready,
    output wire [1:0]   s_axi_bresp,
    output wire         s_axi_bvalid,
    input  wire         s_axi_bready,
    input  wire [31:0]  s_axi_araddr,
    input  wire [7:0]   s_axi_arlen,
    input  wire [2:0]   s_axi_arsize,
    input  wire [1:0]   s_axi_arburst,
    input  wire         s_axi_arvalid,
    output wire         s_axi_arready,
    output wire [31:0]  s_axi_rdata,
    output wire [1:0]   s_axi_rresp,
    output wire         s_axi_rlast,
    output wire         s_axi_rvalid,
    input  wire         s_axi_rready,
    input  wire         rx,
    output wire         tx
);

    localparam integer CPB = CLK_FREQ / BAUD_RATE;

    wire        wr_en;
    wire        rd_en;
    wire [31:0] wr_addr;
    wire [31:0] wr_data;
    wire [31:0] rd_addr;
    wire [3:0]  wr_strb;

    reg  [ 9:0] tx_shift;
    reg  [31:0] tx_count;
    reg  [ 3:0] tx_bits;
    wire        tx_busy = |tx_bits;

    reg  [ 1:0] rx_state;
    reg  [31:0] rx_count;
    reg  [ 2:0] rx_bit;
    reg  [ 7:0] rx_shift;
    reg  [ 7:0] rx_data;
    reg         rx_valid;
    reg         rx_meta;
    reg         rx_sync;

    wire [31:0] status  = {28'h0, tx_busy, !tx_busy, rx_valid, rx_valid};
    wire [31:0] rd_data = (rd_addr[11:0] == 12'h000) ? {24'h0, rx_data} :
                          (rd_addr[11:0] == 12'h008) ? status : 32'h0;

    assign tx = tx_busy ? tx_shift[0] : 1'b1;

    axi_reg_slave U_bus (
        .aclk           (aclk),
        .aresetn        (aresetn),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awlen    (s_axi_awlen),
        .s_axi_awsize   (s_axi_awsize),
        .s_axi_awburst  (s_axi_awburst),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wlast    (s_axi_wlast),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arlen    (s_axi_arlen),
        .s_axi_arsize   (s_axi_arsize),
        .s_axi_arburst  (s_axi_arburst),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rlast    (s_axi_rlast),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        .wr_en          (wr_en),
        .wr_addr        (wr_addr),
        .wr_data        (wr_data),
        .wr_strb        (wr_strb),
        .rd_en          (rd_en),
        .rd_addr        (rd_addr),
        .rd_data        (rd_data)
    );

    // ---- TX state machine ----
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            tx_shift <= 10'h3ff;
            tx_count <= 32'h0;
            tx_bits  <= 4'h0;
        end else begin
            if (wr_en && wr_addr[11:0] == 12'h004 && !tx_busy) begin
                tx_shift <= {1'b1, wr_data[7:0], 1'b0};
                tx_count <= CPB - 1;
                tx_bits  <= 4'd10;
            end else if (wr_en && wr_addr[11:0] == 12'h00c && wr_data[0]) begin
                tx_bits <= 4'h0;
            end else if (tx_busy) begin
                if (tx_count == 0) begin
                    tx_shift <= {1'b1, tx_shift[9:1]};
                    tx_count <= CPB - 1;
                    tx_bits  <= tx_bits - 1'b1;
                end else begin
                    tx_count <= tx_count - 1'b1;
                end
            end
        end
    end

    // ---- RX state machine ----
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rx_meta  <= 1'b1;
            rx_sync  <= 1'b1;
            rx_state <= 2'd0;
            rx_count <= 32'h0;
            rx_bit   <= 3'h0;
            rx_shift <= 8'h0;
            rx_data  <= 8'h0;
            rx_valid <= 1'b0;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;

            if (rd_en && rd_addr[11:0] == 12'h000)
                rx_valid <= 1'b0;
            if (wr_en && wr_addr[11:0] == 12'h00c && wr_data[1])
                rx_valid <= 1'b0;

            case (rx_state)
                2'd0: begin
                    if (!rx_sync) begin
                        rx_count <= CPB / 2;
                        rx_state <= 2'd1;
                    end
                end
                2'd1: begin
                    if (rx_count == 0) begin
                        if (!rx_sync) begin
                            rx_count <= CPB - 1;
                            rx_bit   <= 3'h0;
                            rx_state <= 2'd2;
                        end else begin
                            rx_state <= 2'd0;
                        end
                    end else begin
                        rx_count <= rx_count - 1'b1;
                    end
                end
                2'd2: begin
                    if (rx_count == 0) begin
                        rx_shift[rx_bit] <= rx_sync;
                        rx_count <= CPB - 1;
                        if (rx_bit == 3'd7)
                            rx_state <= 2'd3;
                        else
                            rx_bit <= rx_bit + 1'b1;
                    end else begin
                        rx_count <= rx_count - 1'b1;
                    end
                end
                2'd3: begin
                    if (rx_count == 0) begin
                        rx_data  <= rx_shift;
                        rx_valid <= 1'b1;
                        rx_state <= 2'd0;
                    end else begin
                        rx_count <= rx_count - 1'b1;
                    end
                end
            endcase
        end
    end

    wire unused = wr_strb[0];

endmodule
