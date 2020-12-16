/*  UltiCores -- IP Cores for Mechatronic Control Systems
 *
 *  Copyright (C) 2019 UltiMachine <info@ultimachine.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

`include "../src/spi.v"
`timescale 1ns/100ps

module testbench(
    input             clk,
    output             SCK,
    output             CS,
    output            COPI,
    output            CIPO,
    output reg [63:0] word_send_data,
    output            word_received,
    output reg [63:0] word_data_received,
    output COPI_tx
  );

  wire CS = 0; // selected
  wire COPI = 0;
  wire CIPO; // readback tbd

  // SCK can't be faster than every two clocks ~ use 4
  reg [1:0] SCK_r = 0;
  wire SCK;
  assign SCK = (SCK_r == 2'b11 || SCK_r == 2'b10);
  always @(posedge clk) SCK_r <= SCK_r + 1'b1;

  // COPI trigger 1/4 clk before SCK posedge
  wire COPI_tx = (SCK_r == 2'b01);

  // Locals
  reg [63:0] word_data_received;
  reg [63:0] word_send_data;

  // TB data
  reg [63:0] word_data_tb;

  // SPI 64 bit module
  SPIWord word_proc (
                .clk(clk),
                .SCK(SCK),
                .CS(CS),
                .COPI(COPI),
                .CIPO(CIPO),
                .word_send_data(word_send_data),
                .word_received(word_received),
                .word_data_received(word_data_received));

  reg [7:0] tx_byte;

  initial begin
    word_send_data = 64'h00000000005fffff;
    word_data_tb = 64'hbeefdeaddeadbeef;
    tx_byte = 8'b0;
  end

  reg [3:0] bit_count = 4'b0;
  reg [3:0] byte_count = 4'b0;

  // slice the register into 8 bit, little endian chunks
  wire [7:0] word_slice [8:0];
  assign word_slice[0] = word_data_tb[7:0]; // This should only hit at initialization
  assign word_slice[1] = word_data_tb[15:8];
  assign word_slice[2] = word_data_tb[23:16];
  assign word_slice[3] = word_data_tb[31:24];
  assign word_slice[4] = word_data_tb[39:32];
  assign word_slice[5] = word_data_tb[47:40];
  assign word_slice[6] = word_data_tb[55:48];
  assign word_slice[7] = word_data_tb[63:56];
  assign word_slice[8] = word_data_tb[7:0];

  assign COPI = tx_byte[0];

  reg trig = 0;

  always @(posedge COPI_tx) begin
    bit_count <= bit_count + 1'b1;
    trig = ~trig;
    //tx_byte = {1'b0, tx_byte[6:1]};
    //if (bit_count == 4'b111) begin
      //byte_count = byte_count + 1'b1;
      //tx_byte = word_slice[byte_count];
    //end
  end

endmodule
