# SPI AXI-Lite Wrapper

A lightweight AXI-Lite-controlled SPI master wrapper that exposes a simple four-register interface for byte-wide transfers. Written in SystemVerilog, it instantiates a parameterizable `SPI_Master` block and handles clock-domain crossing of received data into the AXI domain.

---

## Table of Contents

- [Features](#features)  
- [Register Map](#register-map)  
- [Getting Started](#getting-started)  
  - [Prerequisites](#prerequisites)  
  - [Hardware Setup](#hardware-setup)  
  - [Simulation](#simulation)  
- [Usage](#usage)  
  - [Instantiating the Wrapper](#instantiating-the-wrapper)  
  - [AXI-Lite Transactions](#axi-lite-transactions)  
- [Testbench](#testbench)  
- [Future Improvements](#future-improvements)  
- [License](#license)  

---

## Features

- **AXI-Lite slave interface** with independent write and read channels  
- **4-register mapping** for TX data, TX trigger, RX data, and RX-seen flag  
- **SPI master** supporting CPOL/CPHA modes (static at synthesis time)  
- **Clock-domain crossing** for reliable RX data capture  
- **Simple loopback testbench** included  

---

## Register Map

| Offset | Name        | R/W | Description                                   |
|:------:|-------------|:---:|-----------------------------------------------|
| 0x00    | `TX_DATA`   |  W  | [7:0] = Data byte to transmit; upper bits ignored. |
| 0x04    | `TX_VALID`  |  W  | [0] = Set to 1 to start transmission; clears on handshake. |
| 0x08    | `RX_DATA`   |  R  | [7:0] = Last received data byte.              |
| 0x0C    | `RX_SEEN`   |  R  | [0] = Read-and-clear flag indicating new RX data. |

---

## Getting Started

### Prerequisites

- Vivado 2022.2 or later (or any toolchain supporting SystemVerilog)  
- An FPGA development board (e.g., Xilinx Nexys A7, Zynq-7000)  
- AXI-Lite interconnect (or simple master)  

### Hardware Setup

1. Connect your FPGA’s SPI pins (MOSI, SCLK, SS) to the target SPI slave device.  
2. Tie `MISO` back to the wrapper’s `MISO` input.  
3. Ensure `ACLK` and `ARESETN` are driven by your AXI clock/reset.  
4. Drive the wrapper’s `clk` port with the same or divided clock for the SPI domain.

### Simulation

1. Open `tb_SPI_AXI_Wrapper.sv` in your simulator.  
2. Compile both `SPI_AXI_Wrapper.sv` and `SPI_Master.sv`.  
3. Run the simulation; the testbench will:  
   - Write a byte to `TX_DATA` (0x00)  
   - Pulse `TX_VALID` (0x04)  
   - Poll `RX_SEEN` (0x0C) until new data arrives  
   - Read back the looped-back byte from `RX_DATA` (0x08)

---

## Usage

### Instantiating the Wrapper

```verilog
SPI_AXI_Wrapper #(
  .DATA_WIDTH(32),
  .ADDR_WIDTH(4)
) spi_axi_u (
  .ACLK(    ACLK),
  .ARESETN( ARESETN),
  .AWADDR(  AWADDR),
  .AWVALID( AWVALID),
  .AWREADY( AWREADY),
  .WDATA(   WDATA),
  .WSTRB(   WSTRB),
  .WVALID(  WVALID),
  .WREADY(  WREADY),
  .BRESP(   BRESP),
  .BVALID(  BVALID),
  .BREADY(  BREADY),
  .ARADDR(  ARADDR),
  .ARVALID( ARVALID),
  .ARREADY( ARREADY),
  .RDATA(   RDATA),
  .RRESP(   RRESP),
  .RVALID(  RVALID),
  .RREADY(  RREADY),
  .clk(     spi_clk),
  .MISO(    MISO),
  .MOSI(    MOSI),
  .SCLK(    SCLK),
  .SS(      SS)
);
