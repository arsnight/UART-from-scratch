`timescale 1ns / 1ps

module UART_TX(
    input clk,
    input [7:0] parallel_in,
    input start_tx,
    output serial_out
    );


    reg [7:0] data_stored;
    reg prev_state = 0;
    reg edge_detect = 0;
    reg edge_detect_d = 0;
    wire tick;
    
    always @(posedge clk) begin
        edge_detect_d <= edge_detect;
        if (prev_state == 0 && start_tx == 1) begin
            data_stored <= parallel_in;
            edge_detect <= 1;
        end
        
        else if(edge_detect_d && tick) begin
            edge_detect <= 0;
        end
                
        prev_state <= start_tx;
    end
      
    baud_rate_gen baud_rate(
        .clk(clk),
        .tick(tick)
        );

    uart_tx_fsm fsm_init(
        .clk(clk),
        .data_stored(data_stored),
        .tick(tick),
        .edge_detect(edge_detect),
        .serial_out(serial_out)
        );
            
endmodule
