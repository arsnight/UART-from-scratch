module uart_tx_fsm(
    input clk,
    input [7:0] data_stored,
    input tick,
    input edge_detect,
    output reg serial_out
    );
    
    initial serial_out = 1;
    
    reg [3:0] state = 0;
    reg [3:0] counter = 0;
    
    
    localparam IDLE = 0;
    localparam START_BIT = 1;
    localparam DATA_BITS = 2;
    localparam STOP_BIT = 3;
    
    always @(posedge clk) begin            
            if (tick) begin
                if (state == IDLE) begin
                    serial_out <= 1;
                    if (edge_detect) begin
                        state <= START_BIT;
                    end
                end
                else if (state == START_BIT) begin
                        state <= DATA_BITS;
                        counter <= 0;
                        serial_out <= 0;
                end
                else if (state == DATA_BITS) begin
                    serial_out <= data_stored[counter];
                    counter <= counter + 1'b1;
                    if (counter == 4'd7) begin
                            state <= STOP_BIT;
                    end
                end
                else if (state == STOP_BIT) begin
                        state <= IDLE;
                        counter <= 0;
                        serial_out <= 1;
                end
                end
            end                        
endmodule
