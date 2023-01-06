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
    input      [7:0] config_minimum_on_time
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
        faultn <= 1;
      end
      else if (faultn) begin
        faultn <= enable ? !( fault0 | fault1 ) : 1'b1;
      end
    end

  always @(posedge clk) begin
    if (phase_a1_l_control) 
      deadtime_counter_a1 <= config_deadtime;
    else if (deadtime_counter_a1 > 0)
      deadtime_counter_a1 <= deadtime_counter_a1 - 1;
  end

  always @(posedge clk) begin
    if (phase_a2_l_control) 
      deadtime_counter_a2 <= config_deadtime;
    else if (deadtime_counter_a2 > 0)
      deadtime_counter_a2 <= deadtime_counter_a2 - 1;
  end

  always @(posedge clk) begin
    if (phase_a1_l_control) 
      deadtime_counter_b1 <= config_deadtime;
    else if (deadtime_counter_b1 > 0)
      deadtime_counter_b1 <= deadtime_counter_b1 - 1;
  end

  always @(posedge clk) begin
    if (phase_a2_l_control) 
      deadtime_counter_b2 <= config_deadtime;
    else if (deadtime_counter_b2 > 0)
      deadtime_counter_b2 <= deadtime_counter_b2 - 1;
  end

  mytimer_8 minimumontimer0 (
      .clk         (clk),
      .resetn      (resetn),
      .start_enable(off_timer0_done),
      .start_time  (config_minimum_on_time),
      .timer       (minimum_on_timer0)
  );

  mytimer_8 minimumontimer1 (
      .clk         (clk),
      .resetn      (resetn),
      .start_enable(off_timer1_done),
      .start_time  (config_minimum_on_time),
      .timer       (minimum_on_timer1)
  );

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

  wire phase_a1_l_control, phase_a1_h_control;
  wire phase_a2_l_control, phase_a2_h_control;
  wire phase_b1_l_control, phase_b1_h_control;
  wire phase_b2_l_control, phase_b2_h_control;

  // Low Side - enable
  assign phase_a1_l_control = phase_a1_l | !enable;
  assign phase_a2_l_control = phase_a2_l | !enable;
  assign phase_b1_l_control = phase_b1_l | !enable;
  assign phase_b2_l_control = phase_b2_l | !enable;
  // High side - enable, and fault shutdown
  assign phase_a1_h_control = phase_a1_h && faultn && enable && !phase_a1_l_control;
  assign phase_a2_h_control = phase_a2_h && faultn && enable && !phase_a2_l_control;
  assign phase_b1_h_control = phase_b1_h && faultn && enable && !phase_b1_l_control;
  assign phase_b2_h_control = phase_b2_h && faultn && enable && !phase_b2_l_control;

  wire fastDecay0;
  wire fastDecay1;
  wire slowDecay0;
  wire slowDecay1;

  // Fast decay is first x ticks of off time
  // default fast decay = 706
  assign fastDecay0 = off_timer0 >= config_fastdecay_threshold;
  assign fastDecay1 = off_timer1 >= config_fastdecay_threshold;

  // Slow decay remainder of off time - Active high
  assign slowDecay0 = (off_timer0 != 0) & (fastDecay0 == 0);
  assign slowDecay1 = (off_timer1 != 0) & (fastDecay1 == 0);

  // Half bridge high side is active
  // WHEN deadtime_counter ends
  // AND
  // slow decay is NOT active
  // AND
  // ( fast decay active AND would normally be off this phase )
  // OR
  // Should be on to drive this phase / polarity (microstepper_counter)
  assign phase_a1_h = !deadtime_counter_a1 && !slowDecay0 && ( fastDecay0 ? !s1 : s1 );
  assign phase_a2_h = !deadtime_counter_a2 && !slowDecay0 && ( fastDecay0 ? !s2 : s2 );
  assign phase_b1_h = !deadtime_counter_b1 && !slowDecay1 && ( fastDecay1 ? !s3 : s3 );
  assign phase_b2_h = !deadtime_counter_b2 && !slowDecay1 && ( fastDecay1 ? !s4 : s4 );
  // Low side is active
  // WHEN slow decay is active
  // OR
  // ( Fast decay active AND would normally be off this phase )
  assign phase_a1_l = slowDecay0 | ( fastDecay0 ? s1 : !s1 );
  assign phase_a2_l = slowDecay0 | ( fastDecay0 ? s2 : !s2 );
  assign phase_b1_l = slowDecay1 | ( fastDecay1 ? s3 : !s3 );
  assign phase_b2_l = slowDecay1 | ( fastDecay1 ? s4 : !s4 );

  // Fixed off time peak current controller off time start
  // Total off time = config_offtime + config_blanktime
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
