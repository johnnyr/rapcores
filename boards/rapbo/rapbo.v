
// Enable SPI Interface
`define SPI_INTERFACE

// Use PLL for higher SPI frequencies
//`define SPIPLL

// Enable Buffer DTR pin
`define BUFFER_DTR

// Enable Move Done Pin
`define MOVE_DONE

// Motor Definitions
//`define DUAL_HBRIDGE 1
`define ULTIBRIDGE 1

// Encoder Count
`define QUAD_ENC 1

// External Step/DIR Input
`define STEPINPUT

// Output Step/DIR signals
`define STEPOUTPUT

// Change the Move Buffer Size. Should be power of two
//`define MOVE_BUFFER_SIZE 4

// Enable Logic Analyzer Out
`define LA_OUT 2

// Enable Logic Analyzer IN
//`define LA_IN 2

// Logic Analyzer IO for rapcore.v can be set here
`define LOGICANALYZER_MACRO\
  assign LA_OUT[1] = dir; \
  assign LA_OUT[2] = analog_cmp2;
