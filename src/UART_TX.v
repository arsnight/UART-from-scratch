`timescale 1ns / 1ps

module UART_TX #(
    parameter CLK_FREQ = 100_000_000, //Finally understood parameterized hierarchical design
    parameter BAUD_RATE = 115200,
    parameter BIT_COUNT = 8,
    parameter NUM_STATES = 4 // For future scalability to add parity bits
)(
    input clk,
    input rst, // Added reset port
    input [BIT_COUNT-1:0] parallel_in,
    input start_tx,
    output wire serial_out
    );

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;


    reg [BIT_COUNT-1:0] data_stored = 0;
    reg start_tx_prev = 0; //Changed three reg for edge detect to only one
    wire edge_detect;
    wire TX_busy;
    
    assign edge_detect = ~start_tx_prev & start_tx;
    
    wire tick;
    
    always @(posedge clk) begin
        if (rst) begin
            start_tx_prev <= 0;
            data_stored <= 0;
        end else begin
            start_tx_prev <= start_tx;
            if (edge_detect && ~TX_busy) begin //Used TX_busy here
                data_stored <= parallel_in;
            end
        end      
    end
      
    baud_rate_gen #(
            .BAUD_DIV(BAUD_DIV)
    )baud_gen(
        .clk(clk),
        .rst(rst),
        .tick(tick)
        );

    uart_tx_fsm #(
        .BIT_COUNT(BIT_COUNT),
        .NUM_STATES(NUM_STATES)
    )
    tx_fsm_inst(
        .clk(clk),
        .data_stored(data_stored),
        .tick(tick),
        .edge_detect(edge_detect),
        .rst(rst),
        .TX_busy(TX_busy),
        .serial_out(serial_out)
        );
            
endmodule
