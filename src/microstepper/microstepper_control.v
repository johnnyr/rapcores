// SPDX-License-Identifier: ISC
`default_nettype none
module microstepper_control (
    input           clk,
    input           resetn,
    output          phase_a1_l_out,
    output          phase_a2_l_out,
    output          phase_b1_l_out,
    output          phase_b2_l_out,
    output          phase_a1_h_out,
    output          phase_a2_h_out,
    output          phase_b1_h_out,
    output          phase_b2_h_out,
    input    [9:0]  config_fastdecay_threshold,
    input           config_invert_highside,
    input           config_invert_lowside,
    input    [3:0]  config_deadtime,
    input           step,
    input           dir,
    input           enable_in,
    input           analog_cmp1,
    input           analog_cmp2,
    output reg      faultn,
    input  wire     s1,
    input  wire     s2,
    input  wire     s3,
    input  wire     s4,
    output          offtimer_en0,
    output          offtimer_en1,
    output reg [7:0] phase_ct,
    input      [7:0] blank_timer0,
    input      [7:0] blank_timer1,
    input      [9:0] off_timer0,
    input      [9:0] off_timer1,
    input      [7:0] minimum_on_timer0,
    input      [7:0]   minimum_on_timer1
//    input           mixed_decay_enable,
);
  reg [2:0] step_r;
  reg [1:0] dir_r;
  reg [3:0] deadtime_counter_a1;
  reg [3:0] deadtime_counter_a2;
  reg [3:0] deadtime_counter_b1;
  reg [3:0] deadtime_counter_b2;

  reg       enable;

  always @(posedge clk) begin
    if (!resetn)
      enable <= 0;
    else
      enable <= enable_in;
    step_r <= {step_r[1:0], step};
    dir_r <= {dir_r[0], dir};
  end

  wire step_rising = (step_r == 3'b001);

  always @(posedge clk) begin
    if (!resetn) begin
      phase_ct <= 0;
    end
    else if (step_rising)
        phase_ct <= dir_r[1] ? phase_ct + 1 : phase_ct - 1;
  end

  // Fault (active low) if off timer starts before minimum on timer expires
  wire fault0 = (off_timer0 != 0) & (minimum_on_timer0 != 0);
  wire fault1 = (off_timer1 != 0) & (minimum_on_timer1 != 0);

  // Fault latches until reset
  always @(posedge clk) begin
      if (!resetn) begin
//        fault0 <= 0;
//        fault1 <= 0;
        faultn <= 1;
      end
      else if (faultn) begin
        faultn <= enable ? !( fault0 | fault1 ) : 1'b1;
      end
    end


  // Dead time
  // High Side A1
  //         /----\
  // _______/      \__________________
  // Slow Dead On  Dead Fast Dead Slow
  // ----\             /--------------
  //      \___________/
  // Low Side A1
  ////////////////////////////////////
  // Comparator
  // _____________/-\_________________
  ////////////////////////////////////
  // High Side A2
  //                    /--\
  // __________________/    \_________
  // Slow Dead On  Dead Fast Dead Slow
  // --------------\             /----
  //                \-----------/
  // Low Side A2
  ////////////////////////////////////


  // Catch turn off event for dead time.
  reg phase_a1_l_previous;
  reg phase_a2_l_previous;
  reg phase_b1_l_previous;
  reg phase_b2_l_previous;
  reg phase_a1_h_previous;
  reg phase_a2_h_previous;
  reg phase_b1_h_previous;
  reg phase_b2_h_previous;

  always @(posedge clk) begin
    phase_a1_l_previous <= phase_a1_l_control;
    phase_a2_l_previous <= phase_a2_l_control;
    phase_b1_l_previous <= phase_b1_l_control;
    phase_b2_l_previous <= phase_b2_l_control;
    phase_a1_h_previous <= phase_a1_h_control;
    phase_a2_h_previous <= phase_a2_h_control;
    phase_b1_h_previous <= phase_b1_h_control;
    phase_b2_h_previous <= phase_b2_h_control;
  end

  wire phase_a1_l_falling_edge = (phase_a1_l_previous && !phase_a1_l_control);
  wire phase_a2_l_falling_edge = (phase_a2_l_previous && !phase_a2_l_control);
  wire phase_b1_l_falling_edge = (phase_b1_l_previous && !phase_b1_l_control);
  wire phase_b2_l_falling_edge = (phase_b2_l_previous && !phase_b2_l_control);
  wire phase_a1_h_falling_edge = (phase_a1_h_previous && !phase_a1_h_control);
  wire phase_a2_h_falling_edge = (phase_a2_h_previous && !phase_a2_h_control);
  wire phase_b1_h_falling_edge = (phase_b1_h_previous && !phase_b1_h_control);
  wire phase_b2_h_falling_edge = (phase_b2_h_previous && !phase_b2_h_control);

  reg deadtime_a1;
  reg deadtime_a2;
  reg deadtime_b1;
  reg deadtime_b2;

  always @(posedge clk) begin
    if (!resetn)
      deadtime_counter_a1 <= 0;
    else if (phase_a1_l_falling_edge | phase_a1_h_falling_edge) 
      deadtime_counter_a1 <= config_deadtime;
    else if (deadtime_counter_a1 > 0)
      deadtime_counter_a1 <= deadtime_counter_a1 - 1;
    if (deadtime_counter_a1 | phase_a1_l_falling_edge | phase_a1_h_falling_edge)
      deadtime_a1 <= 1;
    else
      deadtime_a1 <= 0;
  end

  always @(posedge clk) begin
    if (!resetn)
      deadtime_counter_a2 <= 0;
    else if (phase_a2_l_falling_edge | phase_a2_h_falling_edge) 
      deadtime_counter_a2 <= config_deadtime;
    else if (deadtime_counter_a2 > 0)
      deadtime_counter_a2 <= deadtime_counter_a2 - 1;
    if (deadtime_counter_a2 | phase_a2_l_falling_edge | phase_a2_h_falling_edge)
      deadtime_a2 <= 1;
    else
      deadtime_a2 <= 0;
  end

  always @(posedge clk) begin
    if (!resetn)
      deadtime_counter_b1 <= 0;
    else if (phase_b1_l_falling_edge | phase_b1_h_falling_edge) 
      deadtime_counter_b1 <= config_deadtime;
    else if (deadtime_counter_b1 > 0)
      deadtime_counter_b1 <= deadtime_counter_b1 - 1;
    if (deadtime_counter_b1 | phase_b1_l_falling_edge | phase_b1_h_falling_edge)
      deadtime_b1 <= 1;
    else
      deadtime_b1 <= 0;
  end

  always @(posedge clk) begin
    if (!resetn)
      deadtime_counter_b2 <= 0;
    else if (phase_b2_l_falling_edge | phase_b2_h_falling_edge) 
      deadtime_counter_b2 <= config_deadtime;
    else if (deadtime_counter_b2 > 0)
      deadtime_counter_b2 <= deadtime_counter_b2 - 1;
    if (deadtime_counter_b2 | phase_b2_l_falling_edge | phase_b2_h_falling_edge)
      deadtime_b2 <= 1;
    else
      deadtime_b2 <= 0;
  end

  wire phase_a1_h, phase_a1_l, phase_a2_h, phase_a2_l;
  wire phase_b1_h, phase_b1_l, phase_b2_h, phase_b2_l;

  // Outputs are active high unless config_invert_**** is set
  // Low side
  assign phase_a1_l_out = config_invert_lowside ^ phase_a1_l_control;
  assign phase_a2_l_out = config_invert_lowside ^ phase_a2_l_control;
  assign phase_b1_l_out = config_invert_lowside ^ phase_b1_l_control;
  assign phase_b2_l_out = config_invert_lowside ^ phase_b2_l_control;
  // High side
  assign phase_a1_h_out = config_invert_highside ^  phase_a1_h_control;
  assign phase_a2_h_out = config_invert_highside ^  phase_a2_h_control;
  assign phase_b1_h_out = config_invert_highside ^  phase_b1_h_control;
  assign phase_b2_h_out = config_invert_highside ^  phase_b2_h_control;


  // Low Side - enable
  // One clk of deadtime included on phase_a1_h_falling_edge then the dead time count
  wire phase_a1_l_control = ( phase_a1_l && !deadtime_a1 && !phase_a1_h_falling_edge ) | !enable;
  wire phase_a2_l_control = ( phase_a2_l && !deadtime_a2 && !phase_a2_h_falling_edge ) | !enable;
  wire phase_b1_l_control = ( phase_b1_l && !deadtime_b1 && !phase_b1_h_falling_edge ) | !enable;
  wire phase_b2_l_control = ( phase_b2_l && !deadtime_b2 && !phase_b2_h_falling_edge ) | !enable;
  // High side - enable, and fault shutdown
  wire phase_a1_h_control = phase_a1_h && faultn && enable && !phase_a1_l_control && !deadtime_a1 && !phase_a1_l_falling_edge;
  wire phase_a2_h_control = phase_a2_h && faultn && enable && !phase_a2_l_control && !deadtime_a2 && !phase_a2_l_falling_edge;
  wire phase_b1_h_control = phase_b1_h && faultn && enable && !phase_b1_l_control && !deadtime_b1 && !phase_b1_l_falling_edge;
  wire phase_b2_h_control = phase_b2_h && faultn && enable && !phase_b2_l_control && !deadtime_b2 && !phase_b2_l_falling_edge;

  // Fast decay is first x ticks of off time
  // default fast decay = 706
  wire fastDecay0 = off_timer0 >= config_fastdecay_threshold;
  wire fastDecay1 = off_timer1 >= config_fastdecay_threshold;

  // Slow decay remainder of off time - Active high
  wire slowDecay0 = (off_timer0 != 0) & (fastDecay0 == 0);
  wire slowDecay1 = (off_timer1 != 0) & (fastDecay1 == 0);

  // Half bridge high side is active
  // WHEN slow decay is NOT active
  // AND
  // ( fast decay active AND would normally be off this phase )
  // OR
  // Should be on to drive this phase / polarity (microstepper_counter)
  assign phase_a1_h = !slowDecay0 && ( fastDecay0 ? !s1 : s1 );
  assign phase_a2_h = !slowDecay0 && ( fastDecay0 ? !s2 : s2 );
  assign phase_b1_h = !slowDecay1 && ( fastDecay1 ? !s3 : s3 );
  assign phase_b2_h = !slowDecay1 && ( fastDecay1 ? !s4 : s4 );
  // Low side is active
  // WHEN slow decay is active
  // OR
  // ( Fast decay active AND would normally be off this phase )
  assign phase_a1_l = slowDecay0 | ( fastDecay0 ? s1 : !s1 );
  assign phase_a2_l = slowDecay0 | ( fastDecay0 ? s2 : !s2 );
  assign phase_b1_l = slowDecay1 | ( fastDecay1 ? s3 : !s3 );
  assign phase_b2_l = slowDecay1 | ( fastDecay1 ? s4 : !s4 );

  // Fixed off time peak current controller off time start
  assign offtimer_en0 = analog_cmp1 & (blank_timer0 == 0) & (off_timer0 == 0);
  assign offtimer_en1 = analog_cmp2 & (blank_timer1 == 0) & (off_timer1 == 0);

`ifdef FORMAL
  `define ON 1'b1
  always @(*) begin
    assert (!(phase_a1_l_control == `ON && phase_a1_h_control == `ON));
    assert (!(phase_a2_l_control == `ON && phase_a2_h_control == `ON));
    assert (!(phase_b1_l_control == `ON && phase_b1_h_control == `ON));
    assert (!(phase_b2_l_control == `ON && phase_b2_h_control == `ON));
  end
`endif

endmodule
