`timescale 1ns / 1ps

module tb_SPI_AXI_Wrapper;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 4;

    logic  ACLK    = 0;
    logic  ARESETN = 0;
    
    always #5 ACLK = ~ACLK;  

  // AXI-Lite signals
    logic  [ADDR_WIDTH-1:0]     AWADDR;
    logic                       AWVALID;
    logic                       AWREADY;
    logic  [DATA_WIDTH-1:0]     WDATA;
    logic  [DATA_WIDTH/8-1:0]   WSTRB;
    logic                       WVALID;
    logic                       WREADY;
    logic [1:0]                 BRESP;
    logic                       BVALID;
    logic                       BREADY;

    logic  [ADDR_WIDTH-1:0]     ARADDR;
    logic                       ARVALID;
    logic                       ARREADY;
    logic [DATA_WIDTH-1:0]      RDATA;
    logic [1:0]                 RRESP;
    logic                       RVALID;
    logic                       RREADY;

    // SPI interface
    logic MOSI, SCLK, SS;
    logic MISO;

    // Loopback for simpler simulation
    assign MISO = MOSI;

    // DUT instantiation
    SPI_AXI_Wrapper #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .ACLK(ACLK),
        .ARESETN(ARESETN),
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        .WDATA(WDATA),
        .WSTRB(WSTRB),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        .RDATA( RDATA),
        .RRESP(RRESP),
        .RVALID(RVALID),
        .RREADY(RREADY),
        .clk(ACLK),
        .MISO(MISO),
        .MOSI(MOSI),
        .SCLK(SCLK),
        .SS(SS)
    );

    // Simple AXI-Lite write task
    task automatic axi_write(
        input [ADDR_WIDTH-1:0] addr,
        input [DATA_WIDTH-1:0] data
    );
        begin
          AWADDR  = addr; 
          AWVALID = 1;
          WDATA   = data; 
          WSTRB  = {DATA_WIDTH/8{1'b1}}; 
          WVALID = 1;
          @(posedge ACLK);
          wait (AWREADY && WREADY);
          AWVALID = 0; 
          WVALID = 0;
          @(posedge ACLK);
          BREADY  = 1;
          wait (BVALID);
          @(posedge ACLK);
          BREADY  = 0;
        end
    endtask

  // Simple AXI-Lite read task
    task automatic axi_read(
        input  [ADDR_WIDTH-1:0] addr,
        output [DATA_WIDTH-1:0] data_out
    );
    begin
        ARADDR  = addr; 
        ARVALID = 1;
        @(posedge ACLK);
        wait (ARREADY);
        ARVALID = 0;
        @(posedge ACLK);
        RREADY  = 1;
        wait (RVALID);
        data_out = RDATA;
        @(posedge ACLK);
        RREADY  = 0;
    end
    endtask
  
    //For checking the read value
    logic [DATA_WIDTH-1:0] rx_data;
    
    initial begin
        // Initialize AXI signals
        AWADDR = 0; AWVALID = 0; WDATA = 0; WSTRB = 0; WVALID = 0; BREADY = 0;
        ARADDR = 0; ARVALID = 0; RREADY = 0;

        // Reset pulse
        #20;
        ARESETN = 0;
        #20;
        ARESETN = 1;
        #20;

        // 1) Write a byte to TX_DATA at 0x0
        axi_write(4'h0, 32'hA5);
    
        // 2) Write '1' to TX_VALID at 0x4 to start SPI transfer
        axi_write(4'h4, 32'h1);
        
        // wait for the DUT's internal seen-flag
        wait (dut.rx_valid_seen == 1);
        @(posedge ACLK);
        
       // Comapre teh read byte
       axi_read(4'h8, rx_data);
       $display(">> Received loopback data = 0x%0h", rx_data);

       #100; 
       $finish;
    end
endmodule
