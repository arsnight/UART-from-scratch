`timescale 1ns / 1ps

module UART_RX_tb();

reg clk = 0;
reg serial_out = 1;
wire [7:0] parallel_out;

localparam OVERSAMPLE = 31;
localparam SAMPLES = 28;
localparam BIT_TIME = OVERSAMPLE * SAMPLES;

always #5 clk = ~clk;

UART_RX dut(
.clk(clk),
.serial_out(serial_out),
.parallel_out(parallel_out)
);


wire [2:0] state = dut.state;
wire [4:0] counter = dut.counter;
wire [2:0] count = dut.count;
wire rst_trigger = dut.rst_trigger;


task send_bit;
input bit_val;
begin
serial_out = bit_val;
repeat(BIT_TIME) @(posedge clk);
end
endtask



task send_byte;
input [7:0] data;
integer i;
begin
$display("Sending Byte: %h at time %t", data, $time);


    send_bit(0);


    for(i = 0; i < 8; i = i + 1) begin
        send_bit(data[i]);
    end


    send_bit(1);


    repeat(BIT_TIME) @(posedge clk);

    $display("Received Byte: %h at time %t", parallel_out, $time);
end

endtask


initial begin
$monitor("Time=%0t | state=%0d | counter=%0d | count=%0d | parallel_out=%h",
$time, state, counter, count, parallel_out);
end


initial begin
$dumpfile("uart_rx.vcd");
$dumpvars(0, UART_RX_tb);
end


initial begin


serial_out = 1;
repeat(2000) @(posedge clk);

send_byte(8'hAA);

repeat(5000) @(posedge clk);

$finish;


end

endmodule
