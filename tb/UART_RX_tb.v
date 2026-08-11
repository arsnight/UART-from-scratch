`timescale 1ns / 1ps

module UART_RX_tb();

reg clk = 0;
reg rst = 0;
reg serial_out = 1;
wire [7:0] Received_Byte;

localparam OVERSAMPLE = 31;
localparam SAMPLES = 28;
localparam BIT_TIME = OVERSAMPLE * SAMPLES;

always #5 clk = ~clk;

UART_RX dut(
    .clk(clk),
    .rst(rst),
    .serial_out(serial_out),
    .Received_Byte(Received_Byte)
);

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

        // Start bit
        send_bit(0);

        // Data bits, LSB first
        for(i = 0; i < 8; i = i + 1) begin
            send_bit(data[i]);
        end

        // Stop bit
        send_bit(1);

        // Display what RX received
        $display("Received Byte: %h at time %t", Received_Byte, $time);
    end
endtask

task send_byte_with_reset;
    input [7:0] data;
    input integer reset_after_bit;
    integer i;
    reg interrupted;

    begin
        interrupted = 0;

        $display("Sending Byte: %h at time %t", data, $time);

        // Start bit
        send_bit(0);

        for(i = 0; i < 8; i = i + 1) begin

            serial_out = data[i];

            if(i == reset_after_bit) begin

                // Send only half of this bit
                repeat(BIT_TIME/2) @(posedge clk);

                $display(">>> RESET MID-BIT %0d at time %t",
                         i, $time);

                serial_out = 1;
                rst = 1;

                repeat(2) @(posedge clk);

                rst = 0;

                $display(">>> RESET RELEASED at time %t", $time);

                repeat(BIT_TIME) @(posedge clk);

                interrupted = 1;

            end
            else begin
                repeat(BIT_TIME) @(posedge clk);
            end

            if(interrupted)
                i = 8;
        end

        if(!interrupted) begin
            send_bit(1);
            $display("Received Byte: %h at time %t",
                     Received_Byte, $time);
        end

    end
endtask

initial begin
    $dumpfile("uart_rx.vcd");
    $dumpvars(0, UART_RX_tb);
end

initial begin

    serial_out = 1;
    rst = 0;

    repeat(2000) @(posedge clk);

    // Normal
    send_byte(8'h77);

    // Normal
    send_byte(8'hA5);

    // Interrupt A5 after data bit 2
    send_byte_with_reset(8'hA5, 2);

    // Fresh frame after reset
    send_byte(8'hA5);

    repeat(5000) @(posedge clk);

    $finish;

end

endmodule
