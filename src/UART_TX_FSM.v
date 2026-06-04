module uart_tx_fsm#(
    parameter BIT_COUNT = 8,
    parameter NUM_STATES = 4
)(
    input clk,
    input [BIT_COUNT-1:0] data_stored,
    input tick,
    input edge_detect,
    input rst,
    output wire TX_busy, //put TX_busy as an output wire instead of updating inside fsm
    output reg serial_out
    );
    
    localparam BIT_WIDTH = $clog2(BIT_COUNT + 1); //ceiling of log base 2 to calculate bit width, used one decimal larger than BIT_COUNT to account for overflow
    localparam STATE_WIDTH = $clog2(NUM_STATES + 1); 
    reg [STATE_WIDTH-1:0] state = 0; //parameterized state width too for future scaling, accomodating parity bit state
    reg [BIT_WIDTH-1:0] counter = 0;
    
    localparam [STATE_WIDTH-1:0] IDLE = 0;  // Specifying state width to avoid defaulting it's bit size to 32
    localparam [STATE_WIDTH-1:0] START_BIT = 1;
    localparam [STATE_WIDTH-1:0] DATA_BITS = 2;
    localparam [STATE_WIDTH-1:0] STOP_BIT = 3;
    
    assign TX_busy = (state != IDLE); //Assign will update anytime state changes which should be better
    
    always @(posedge clk) begin
            if (rst) begin //Added synchronous reset however may add asynchronous assert synchronous release in the future instead
                serial_out <= 1;
                state <= IDLE;
                counter <= 0;
            end
            else begin            
            if (tick) begin
                serial_out <= 1; //Moore FSM default init
                
                case(state)
                
                    default: begin
                        state <= IDLE;
                        counter <= 0;
                    end
                    
                    IDLE: begin
                        serial_out <= 1;
                        if (edge_detect) begin
                            state <= START_BIT;
                        end
                    end
                    START_BIT: begin
                        state <= DATA_BITS;
                        counter <= 0;
                        serial_out <= 0;
                    end
                    DATA_BITS: begin
                        serial_out <= data_stored[counter];
                        counter <= counter + 1'b1;
                        if (counter == BIT_COUNT - 1) begin
                            counter <= 0;
                            state <= STOP_BIT;
                        end
                    end
                    STOP_BIT: begin
                        serial_out <= 1;
                        state <= IDLE;
                    end                        
            endcase
         end
         end 
     end                       
endmodule
