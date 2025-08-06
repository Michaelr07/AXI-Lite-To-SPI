`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Michael Rosales 
// Module Name: SPI AXI LITE SLAVE
//////////////////////////////////////////////////////////////////////////////////

module SPI_AXI_Wrapper 
#(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4  // 16 bytes total space
)
(
    input  logic                    ACLK,
    input  logic                    ARESETN,

    // AXI Lite interface
    input  logic [ADDR_WIDTH-1:0]  AWADDR,
    input  logic                   AWVALID,
    output logic                   AWREADY,
    
    input  logic [DATA_WIDTH-1:0]  WDATA,
    input  logic [3:0]             WSTRB,
    input  logic                   WVALID,
    output logic                   WREADY,
    
    output logic [1:0]             BRESP,
    output logic                   BVALID,
    input  logic                   BREADY,

    input  logic [ADDR_WIDTH-1:0]  ARADDR,
    input  logic                   ARVALID,
    output logic                   ARREADY,
    
    output logic [DATA_WIDTH-1:0]  RDATA,
    output logic [1:0]             RRESP,
    output logic                   RVALID,
    input  logic                   RREADY,

    // SPI interface for debugging
    input  logic                   clk,      // SPI clock domain
    input  logic                   MISO,
    output logic                   MOSI,
    output logic                   SCLK,
    output logic                   SS
);

    // axi-lite interface signals
    logic awready_reg, wready_reg, bvalid_reg, arready_reg, rvalid_reg;
    logic [31:0] rdata_reg;

    assign AWREADY = awready_reg;
    assign WREADY  = wready_reg;
    assign BVALID  = bvalid_reg;
    assign BRESP   = 2'b00; // deafult to OKAY
    assign ARREADY = arready_reg;
    assign RVALID  = rvalid_reg;
    assign RDATA   = rdata_reg;
    assign RRESP   = 2'b00; // default to OKAY

    // Internal registers
    logic [7:0] tx_data_reg;  
    logic       tx_valid_reg;
    logic      tx_ready;

    // SPI receive
    logic [7:0] rx_data;
    logic       rx_valid; // from SPI clock domain

    // Registers for Synchronized version of rx_valid
    logic rx_valid_sync_0, rx_valid_sync_1;
    logic rx_valid_prev;
    logic rx_valid_seen;

    // for strb data
    logic [DATA_WIDTH-1:0] merged_data;
    
    //strb fuinction
    function [DATA_WIDTH-1:0]	apply_wstrb;
            input	[DATA_WIDTH-1:0]		prior_data;
            input	[DATA_WIDTH-1:0]		new_data;
            input	[DATA_WIDTH/8-1:0]	wstrb;
    
            integer	k;
            for(k=0; k<DATA_WIDTH/8; k=k+1)
            begin
                apply_wstrb[k*8 +: 8]
                    = wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
            end
        endfunction
    
    // for strb data
    assign merged_data = apply_wstrb({24'h000000,tx_data_reg}, WDATA, WSTRB);

    // Write
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            awready_reg   <= 0;
            wready_reg    <= 0;
            bvalid_reg    <= 0;
            tx_valid_reg  <= 0;
        end else begin
            // Default: deassert ready signal(single cycle pulses)
            awready_reg <= 0;
            wready_reg  <= 0;

            if (!bvalid_reg) begin
                if (AWVALID && WVALID) begin
                    // Accept address and data together
                    awready_reg    <= 1;
                    wready_reg     <= 1;
    
                    case (AWADDR[3:0])
                        4'h0: tx_data_reg  <= merged_data[7:0];
                        4'h4: tx_valid_reg <= WDATA[0];
                    endcase

                    bvalid_reg <= 1;
                end
            end else if (bvalid_reg && BREADY) begin
                // Complete write response handshake
                bvalid_reg <= 0;
            end
        end
    end
    

    // Read
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            arready_reg     <= 0;
            rvalid_reg      <= 0;
            rdata_reg       <= 0;
            rx_valid_seen   <= 0;
        end else begin
            if (ARVALID && !arready_reg) begin
                arready_reg <= 1;
            end

            if (arready_reg && !rvalid_reg) begin
                arready_reg <= 0;
                rvalid_reg  <= 1;
                
                case (ARADDR[3:0])
                    4'h0:  rdata_reg <= {24'b0, tx_data_reg};
                    4'h4:  rdata_reg <= {31'b0, tx_valid_reg};
                    4'h8:  rdata_reg <= {24'b0, rx_data};
                    4'hC:  rdata_reg <= {31'b0, rx_valid_seen};
                    default: rdata_reg <= 32'hDEADBEEF;
                endcase
            end

            // Read-response handshake
            if (RVALID && RREADY) begin
                rvalid_reg <= 0;
                if (ARADDR[3:0] == 4'hC)
                    rx_valid_seen <= 0; // clear after master read
            end
        end
    end

    // Extra: To synchronize rx_valid from SPI clock domain into ACLK domain and edge-detect
    // I did not have seperate clocks so this was not needed but could be useful when working with different clocks
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            rx_valid_sync_0 <= 0;
            rx_valid_sync_1 <= 0;
            rx_valid_prev   <= 0;
            rx_valid_seen   <= 0;
        end else begin
            // two-stage synchronizer
            rx_valid_sync_0 <= rx_valid;
            rx_valid_sync_1 <= rx_valid_sync_0;

            // rising-edge detect of synchronized rx_valid
            if (rx_valid_sync_1 && !rx_valid_prev)
                rx_valid_seen <= 1;

            rx_valid_prev <= rx_valid_sync_1;
        end
    end

    // Clear tx_valid after TX_READY handshake
    always @(posedge clk or negedge ARESETN) begin
        if (!ARESETN)
            tx_valid_reg <= 0;
        else if (tx_valid_reg && tx_ready)
            tx_valid_reg <= 0;
    end

    // SPI master instance
    // Left the parameters as default, could change them from the SPI module
    SPI_Master spi_inst (
        .clk(clk),
        .rst_n(ARESETN),
        .MISO(MISO),
        .MOSI(MOSI),
        .SCLK(SCLK),
        .SS(SS),
        .TX_VALID(tx_valid_reg),
        .TX_DATA(tx_data_reg),
        .TX_READY(tx_ready),
        .RX_DATA(rx_data),
        .RX_VALID(rx_valid)
    );

endmodule
