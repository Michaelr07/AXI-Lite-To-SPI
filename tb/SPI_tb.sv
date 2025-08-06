`timescale 1ns / 1ps

module SPI_tb;
    parameter int DATA_WIDTH = 8;
    parameter int CPHA = 1;
    parameter int CPOL = 1;

    logic clk;
    logic rst_n;

    logic MOSI, SCLK, SS;
    logic TX_READY, RX_VALID;
    logic TX_VALID;
    logic [DATA_WIDTH-1:0] TX_DATA;
    logic [DATA_WIDTH-1:0] RX_DATA;

    always #5 clk = ~clk;

    SPI_Master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_FREQ(100_000_000),
        .SPI_FREQ(50_000_000),
        .CPOL(CPOL),
        .CPHA(CPHA)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .MISO(MOSI), //loopback
        .MOSI(MOSI),
        .SCLK(SCLK),
        .SS(SS),
        .TX_VALID(TX_VALID),
        .TX_READY(TX_READY),
        .TX_DATA(TX_DATA),
        .RX_DATA(RX_DATA),
        .RX_VALID(RX_VALID)
    );

    initial begin
        clk         = 0;
        rst_n       = 0;    
        TX_VALID    = 0;
        TX_DATA     = 0;  
        repeat(10) @(posedge clk);
        rst_n       = 1;    
    end
  
    task automatic SendAndCheck(input logic [DATA_WIDTH-1:0] data);
    begin
      @(posedge clk);
      wait (TX_READY);
      TX_DATA   <= data;
      TX_VALID  <= 1;
      @(posedge clk);
      TX_VALID  <= 0;

      @(posedge RX_VALID);
      if (RX_DATA !== data) begin
        $display("[ERROR] Sent=0x%0X, Received=0x%0X @ %0t", data, RX_DATA, $time);
      end else begin
        $display("[GOOD] Sent=0x%0X, Received=0x%0X @ %0t", data, RX_DATA, $time);
      end
    end
  endtask

  initial begin
    wait (rst_n);
    repeat(5) @(posedge clk);

    SendAndCheck(8'h00);
    SendAndCheck(8'hFF);
    SendAndCheck(8'hA5);
    SendAndCheck(8'h5A);

    #20 $finish;
  end

endmodule