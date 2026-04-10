`timescale 1ns / 1ps

module UART_main_tb;

reg clk = 0;
reg [7:0] parallel_in;
reg start_tx;
wire [7:0] parallel_out;

UART_main dut (
    .clk(clk),
    .parallel_in(parallel_in),
    .start_tx(start_tx),
    .parallel_out(parallel_out)
);


// 100 MHz clock
always #5 clk = ~clk;


// Task to send byte
task send_byte(input [7:0] data);
begin
    @(negedge clk);
    parallel_in = data;
    start_tx = 1;
    
    @(negedge clk);
    start_tx = 0;
end
endtask


initial begin

    // Initialize
    start_tx = 0;
    parallel_in = 0;

    // Wait some time
    #1000;

    // Test cases
    send_byte(8'hCF);
    #200000;



    $stop;

end

endmodule
