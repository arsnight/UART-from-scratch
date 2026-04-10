# UART-from-scratch
UART implementation with the transmitter and receiver modules written separately from scratch using verilog. Focusing on FSM design, baud rate generation and oversampling.

# UART-TX-from-scratch
UART Transmitter (TX) implemented in Verilog from scratch, focusing on FSM design, baud rate generation and a testbench for verification.

## Features
- 115200 Baud UART TX
- FSM based design
- Fully synchronous design
- Testbench verification

# Day 1 - Design
Planned architecture:
- Baud rate generator
- Data storage

As a beginner to the field of verilog, a lot in this project was just me switching from the "software" thinking to the hardware thinking. After reviewing the theory and concepts regarding a complete UART module, I decided to start with a transmitter module first as that felt easier than the receiver (And indeed it was!)

The first step in this project was to assume the input data is going to be received to the tx (transmitter) module in parallel form. This usually just meant instead of bit by bit input, the inputs will be a collection of bits instead (better called bytes). Example for the alphabet A, the parallel input would be 01000001. Hence, we need to store this data somewhere because if we use it raw, data can change and then the tx module will just output a bunch of gibberish.

This is where I got my first roadblock, I started thinking in terms of software, making codes like - 
```verilog  
module Input_storage (
  input clk,
  input reset,
  input [7:0] parallel_in,
  output reg [7:0] data_stored
  );
  always @(posedge clk or posedge reset) begin
    if (reset == 1'b1) begin
      data_stored <= 0;
    end
    else begin
      data_stored <= parallel_in;
    end
  end
endmodule
```
Looks correct right? No.
The thing is, this code forces data_stored to update every clock cycle.
For example, imagine transmitting:

A → B → C

If `data_stored` updates continuously, the transmitter may output:

- First few bits from A
- Then some bits from B
- Then remaining bits from C

Absolutely corrupted UART frame, essentially just a gibberish output. This was my first major realization in shifting from software thinking to hardware thinking — signals must often be *latched* at the right time rather than continuously updated.

To solve this I used a trigger, an edge detection logic instead. Introducing a reg start_tx along with another reg prev_state, while using this logic -
```verilog  
module Input_storage (
  input clk,
  input reset,
  input start_tx,
  input [7:0] parallel_in,
  output reg [7:0] data_stored
  );

  reg prev_state = 0;  //------> Don't forget to initialize, a good habit!
  always @(posedge clk or posedge reset) begin
    if (prev_state == 0 && start_tx == 1) begin
      data_stored <= parallel_in;
    end
      prev_state <= start_tx;
  end
endmodule
```
Now that this issue was resolved, the next part was to create the backbone of this project, `The Baud tick generator`. As complicated as it sounds, the code was rather simple. For this project I went with the most common baud rate of 115200:

- For the standard baud tick, Baud rate = 115200 bits/s
- Each bit will last for around 1/115200 seconds or 8.68us
- Assuming a 100 MHz FPGA clock, fundamental time period of on board clock = 10ns
- So, if 1 cycle takes 10ns, then 8.68us/10ns cycles take 8.68us.

By simple arthmetic, each baud tick will last for exactly 868 on board clock ticks. Hence the code logic is simple, initialize a counter that adds each time it isn't equal to 10'd867 (counter starts at 0, so total counts will be from 0 to 867) and reset it once it reaches 10'd867.
```verilog
module baud_rate_gen(
  input clk,
  output reg tick
);
  reg [9:0] count = 0;
  always @(posedge clk) begin
    if (count == 10'd867) begin
      tick <= 1'b1;
      count <= 0;
    end
    else begin
      count <= count + 1'b1;
      tick <= 0;
    end
  end
endmodule
```
This tick signal now acts as the timing reference for the UART FSM, ensuring each bit is transmitted at the correct baud rate.
However, it is important to note that the baud tick is **not another clock**. 
Using it directly in an `always @(posedge tick)` block is dangerous and can 
lead to timing issues.

Instead, a single global clock should be used throughout the design, while 
the baud tick is used as a **clock enable** signal:

# Day 2 - FSM
Planned architecture:
- Finite State Machine

Now started the confusing part of this project (as a beginner), the FSM. For this project i considered the use of four states:
- IDLE : serial_out will be High during the IDLE state.
- START_BIT : Transmit start bit.
- DATA_BITS : This is where the data will be actually transmitted one at a time.
- STOP_BIT : Detect stop bit and stop the FSM.

At first however I made the critical mistake of using multiple state flags like:
```verilog
reg IDLE;
reg START_BIT;
...
```
But this is extremely bad as it allowed for the possibility of multiple states to be active at once, which breakes the fundamental structure of FSM.
The realisation was to create one state variable and use 4 local parameters to assign the states.
```verilog
...
reg [3:0] state = 0;

localparam IDLE = 0;
localparam START_BIT = 1;
localparam DATA_BITS = 2;
localparam STOP_BIT = 3;
...
```

Before proceeding further, finding this in the dubugging state, the start_tx defined earlier was causing the FSM to be level triggered instead of edge triggered resulting in the FSM to retrigger continuously for no reason and causing errors in the transimitted serial output.
To conter this we just use a edge trigger instead by rewriting this code:
```verilog  
...
  reg prev_state = 0;
  always @(posedge clk or posedge reset) begin
    if (prev_state == 0 && start_tx == 1) begin
      data_stored <= parallel_in;
      edge_detect <= 1; //------> Change here
    end else begin
      edge_detect <= 0; //------> Change here
    prev_state <= start_tx;
...
```
Therefore the final FSM written after debugs:
```verilog
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
```

## Learned Experiences

1. Hardware ≠ Software Thinking
One of the biggest lessons from this project was understanding that hardware behaves fundamentally differently from software.
Initially, I designed logic assuming signals could update continuously without consequences. However, in hardware this can lead to unintended behavior such as data corruption.
This became evident when data_stored was updating every clock cycle, which caused mixed transmission frames. The solution was to latch data at the correct moment using edge detection logic.
This project reinforced that:
Signals must be latched intentionally
Timing matters more than instruction order
Hardware runs in parallel, not sequentially like software

2. Baud Tick is Not a Clock
Another important learning was understanding that the baud tick is not another clock.
Initially, it seemed intuitive to use:
```verilog
always @(posedge tick)
```
However, this creates a derived clock, which can introduce:
Timing violations
Clock domain crossing issues
Unreliable synthesis behavior
Instead, the correct approach is using a clock enable signal:
```verilog
always @(posedge clk)
  if (tick)
```      
This ensures the entire design remains synchronous and stable.

3. Proper FSM Design Matters
At first, I used multiple state flags:
```verilog
reg IDLE;
reg START_BIT;
```
This allowed multiple states to become active simultaneously, breaking FSM behavior.
The correct solution was:
- Use one state register
- Define states using localparam
- Ensure only one active state at any time
- This improved reliability and readability of the design.

4. Edge Detection is Essential in Hardware
The start_tx signal initially retriggered the FSM repeatedly because it was level-triggered.
This led to unexpected retransmissions.
Implementing edge detection solved this:
- Prevented multiple triggers
- Made transmission deterministic
- Improved overall design stability

5. Simple Designs Can Still Be Deep
Although UART TX appears simple, this project required understanding:

- Timing
- FSM design
- Data latching
- Synchronization
- Hardware debugging

This reinforced that even small modules can provide significant learning value.

## Future Scalability

1. Parameterizable Baud Rate :
The Current design is limited to baud rate 115200 and a 100 MHz master clock, However future improvements can be made to introduce parameterized baud rate generator and master clock frequency.

2. Configurable Data Length :
Currently, my design can only accomodate for 8 bits of data. However the design is done keeping the scalability to 5-9 bits depending on the needs.

3. Parity bit :
Currently, Parity bit is not included, however I plan to implement even, odd parity and an optional parity enable feature.

4. Integration with UART RX module :
Implement UART RX, Combine TX + RX and build full UART module.

5. System-Level Integration :
This UART module will eventually become part of larger systems such as a custom CPU, VGA terminal, FPGA operating terminal and many more.
