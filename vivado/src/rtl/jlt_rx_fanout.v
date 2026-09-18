`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Description: Replicates the single Mini-JLT NMEA RX line to four identical
//              GPIO output pins in pure combinational logic. Lets multiple
//              downstream devices each listen to the same GPS/NMEA serial
//              stream independently, while the original jlt_rx signal still
//              feeds axi_uartlite_0 for PS-side parsing as before. This is a
//              direct electrical fan-out, not a UART core -- no re-timing,
//              no buffering, no clock involved.
//////////////////////////////////////////////////////////////////////////////////


module jlt_rx_fanout(
    input  wire  jlt_rx,
    output wire  tx1,tx2,tx3,tx4
);
    assign tx1 = jlt_rx;
    assign tx2 = jlt_rx;
    assign tx3 = jlt_rx;
    assign tx4 = jlt_rx;
endmodule