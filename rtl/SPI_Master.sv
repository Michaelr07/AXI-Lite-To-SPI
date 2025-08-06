`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Michael Rosales 
// Module Name: SPI_Master
//////////////////////////////////////////////////////////////////////////////////

module SPI_Master
#(
    parameter int DATA_WIDTH = 8,
    parameter int CLK_FREQ   = 100_000_000, // 100 MHz system clock
    parameter int SPI_FREQ   = 10_000_000,  // 10 MHz SCLK
    parameter bit CPOL       = 0,
    parameter bit CPHA       = 0
)
(
    input  logic                   clk,
    input  logic                   rst_n,
    
    // SPI pins
    input  logic                   MISO,
    output logic                   MOSI,
    output logic                   SCLK,
    output logic                   SS,
    
    // control
    input  logic                   TX_VALID,
    input  logic [DATA_WIDTH-1:0]  TX_DATA,
    output logic                   TX_READY,
    
    output logic [DATA_WIDTH-1:0]  RX_DATA,
    output logic                   RX_VALID 
);

    // Timer to generate tick at half SCLK intervals
    localparam int DIV = CLK_FREQ / (2*SPI_FREQ);
    logic        tick, enable;
    
    timer #(DIV) clkgen (
      .clk(clk), 
      .rst_n(rst_n),
      .enable(enable), 
      .done(tick)
    );

    typedef enum logic [1:0] {IDLE, LOAD, SHIFT} state_type;
    state_type  state, next;
    
    logic [$clog2(DATA_WIDTH):0] bit_counter;
    logic [DATA_WIDTH-1:0]       shift_reg, rx_reg;
    logic                        prev_SS, ss_fall;

    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n)   prev_SS <= 1;
      else          prev_SS <= SS;
    end
    assign ss_fall = prev_SS & ~SS;

    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n)   state <= IDLE;
      else          state <= next;
    end

    always_comb begin
      next = state;
      case (state)
        IDLE:  next = (TX_VALID)?   LOAD  : IDLE;
        LOAD:  next = ss_fall   ?   SHIFT : LOAD;
        SHIFT: next = RX_VALID  ?   IDLE  : SHIFT;
      endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        MOSI        <= CPOL;
        SCLK        <= CPOL;
        enable      <= 1'b0;
        RX_VALID    <= 1'b0;
        bit_counter <= 0;
        shift_reg   <= 0;
        rx_reg      <= 0;
      end
      else begin
        RX_VALID    <= 1'b0;
        enable      <= (state != IDLE);

        case (state)
          IDLE: begin
            if (TX_VALID) begin            
              shift_reg   <= TX_DATA;
              bit_counter <= 0;
            end
          end

          LOAD: begin
            if (ss_fall && !CPHA) begin
              MOSI        <= shift_reg[DATA_WIDTH-1];
              shift_reg   <= {shift_reg[DATA_WIDTH-2:0],1'b0};
              bit_counter <= 1;
            end
          end

          SHIFT: begin
            if (tick) begin
              if ((CPHA==0 && SCLK==CPOL) || (CPHA==1 && SCLK!=CPOL)) begin
                // this is the sample edge
                rx_reg <= {rx_reg[DATA_WIDTH-2:0], MISO};
              end
              else begin
                // this is the drive edge
                if (bit_counter < DATA_WIDTH) begin
                  MOSI        <= shift_reg[DATA_WIDTH-1];
                  shift_reg   <= {shift_reg[DATA_WIDTH-2:0],1'b0};
                  bit_counter <= bit_counter + 1;
                end
                else begin
                  MOSI      <= 0;
                  enable    <= 1'b0;
                  RX_VALID  <= 1'b1;
                end
              end
              SCLK <= ~SCLK;
            end
          end
        endcase
      end
    end

    // Outputs
    assign TX_READY = (state == IDLE);
    assign SS       = (state == IDLE);
    assign RX_DATA  = rx_reg;

endmodule
