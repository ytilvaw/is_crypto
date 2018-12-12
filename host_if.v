`timescale 1ns / 1ps

module host_if(
  input          RSTn,     // Reset input
  input          CLK,      // Clock input

  output         DEVRDY,   // Device ready
  output         RRDYn,    // Read data empty
  output         WRDYn,    // Write buffer almost full
  input          HRE,      // Host read enable
  input          HWE,      // Host write enable
  input    [7:0] HDIN,     // Host data input
  output   [7:0] HDOUT,    // Host data output

  output         RSTOUTn,  // Internal reset output
  output         ENCn_DEC, // Encrypt/Decrypt select
  output         KEY_GEN,  // Round key generate
  output         DATA_EN,  // Encrypt or Decrypt Start
  input          KVAL,     // Round Key valid
  input          TVAL,
  output [255:0]  KEY_OUT,  // Cipher key output
  output [4095:0] DATA_OUT, // Cipher Text or Inverse Cipher Text output
  input  [2047:0] RESULT    // Cipher Text or Inverse Cipher Text input
);


  parameter [3:0]  CMD = 4'h0, READ1 = 4'h1, READ2 = 4'h2, READ3 = 4'h3, READ4 = 4'h4,
                   WRITE1 = 4'h5, WRITE2 = 4'h6, WRITE3 = 4'h7, WRITE4 = 4'h8;

// ==================================================================
// Internal signals
// ==================================================================
  reg    [4:0] cnt;             // Reset delay counter
  reg          lbus_we_reg;     // Write input register
  reg    [7:0] lbus_din_reg;    // Write data input register
  reg    [3:0] next_if_state;   // Host interface next state  machine registers
  reg    [3:0] now_if_state;    // Host interface now state machine registers
  reg   [15:0] addr_reg;        // Internal address bus register
  reg   [15:0] data_reg;        // Internal write data bus register
  reg          write_ena;       // Internal register write enable

  reg          rst;             // Internal reset
  reg          enc_dec;         // Encrypt/Decrypt select register
  reg          key_gen;         // Round key generate
  reg          data_ena;        // Encrypt or Decrypt Start
  reg  [255:0] key_reg;         // Cipher Key register
  reg  [4095:0]din_reg;         // Text input register

  reg          wbusy_reg;       // Write busy register
  reg          rrdy_reg;        // Read ready register
  reg   [15:0] dout_mux;        // Read data multiplex
  reg    [7:0] hdout_reg;       // Read data register
 
// ================================================================================
// Equasions
// ================================================================================
  // Reset delay counter
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) cnt <= 5'h00;
    else if (~&cnt) cnt <= cnt + 1'b1;
  end

  assign RSTOUTn = &cnt[3:0];
  assign DEVRDY  = &cnt;

  // Local bus input registers
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) begin
      lbus_we_reg <= 1'b0;
      lbus_din_reg <= 8'h00;
    end
    else begin
      lbus_we_reg <= HWE;

      if ( HWE == 1'b1 ) lbus_din_reg <= HDIN;
      else lbus_din_reg <= lbus_din_reg;
    end
  end

  // State machine register
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) begin
      now_if_state <= CMD;
    end
    else begin
      now_if_state <= next_if_state;
    end
  end

  // State machine control
  always @( now_if_state or lbus_we_reg or lbus_din_reg or HRE ) begin
    case ( now_if_state )
      CMD  : if ( lbus_we_reg == 1'b1 )
                if ( lbus_din_reg == 8'h00 ) next_if_state = READ1;
                else if ( lbus_din_reg == 8'h01 ) next_if_state = WRITE1;
                else next_if_state = CMD;
              else next_if_state = CMD;

      READ1 : if ( lbus_we_reg == 1'b1 ) next_if_state = READ2;   // Address High read
              else next_if_state = READ1;
      READ2 : if ( lbus_we_reg == 1'b1 ) next_if_state = READ3;   // Address Low read
              else next_if_state = READ2;
      READ3 : if ( HRE == 1'b1 ) next_if_state = READ4;           // Data High read
              else  next_if_state = READ3;
      READ4 : if ( HRE == 1'b1 ) next_if_state = CMD;            // Data Low read
              else  next_if_state = READ4;

      WRITE1: if ( lbus_we_reg == 1'b1 ) next_if_state = WRITE2;  // Address High read
              else next_if_state = WRITE1;
      WRITE2: if ( lbus_we_reg == 1'b1 ) next_if_state = WRITE3;  // Address Low read
              else next_if_state = WRITE2;
      WRITE3: if ( lbus_we_reg == 1'b1 ) next_if_state = WRITE4;  // Data High write
              else next_if_state = WRITE3;
      WRITE4: if ( lbus_we_reg == 1'b1 ) next_if_state = CMD;    // Data Low write
              else next_if_state = WRITE4;
     default: next_if_state = CMD; 
    endcase
  end

  // Internal bus 
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) begin
      addr_reg <= 16'h0000;
      data_reg <= 16'h0000;
      write_ena <= 1'b0;
    end
    else begin
      if (( now_if_state == READ1 ) || ( now_if_state == WRITE1 )) addr_reg[15:8] <= lbus_din_reg;
      else addr_reg[15:8] <= addr_reg[15:8];

      if (( now_if_state == READ2 ) || ( now_if_state == WRITE2 )) addr_reg[7:0] <= lbus_din_reg;
      else addr_reg[7:0] <= addr_reg[7:0];

      if ( now_if_state == WRITE3 ) data_reg[15:8] <= lbus_din_reg;
      else data_reg[15:8] <= data_reg[15:8];

      if ( now_if_state == WRITE4 ) data_reg[7:0] <= lbus_din_reg;
      else data_reg[7:0] <= data_reg[7:0];

      write_ena <= (( now_if_state == WRITE4 ) && ( next_if_state == CMD ))? 1'b1 : 1'b0;
    end
  end

  // AES register
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) begin
      key_gen <= 1'b0;
      data_ena <= 1'b0;
      rst <= 1'b0;
      enc_dec <= 1'b0;
      key_reg <= 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000;
      din_reg <= 4095'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000;
    end
    else begin
      if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0002 ) && ( data_reg[0] == 1'b1 )) data_ena <= 1'b1;
      else data_ena <= 1'b0;

      if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0002 ) && ( data_reg[1] == 1'b1 )) key_gen <= 1'b1;
      else key_gen <= 1'b0;

      if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0002 ) && ( data_reg[2] == 1'b1 )) rst <= 1'b1;
      else rst <= 1'b0;

      if (( write_ena == 1'b1 ) && ( addr_reg == 16'h000c ) && ( data_reg[0] == 1'b1 )) enc_dec <= data_reg[0];
      else enc_dec <= enc_dec;


		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0100 )) key_reg[255:240] <= data_reg;
		else key_reg[255:240] <= key_reg[255:240];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0102 )) key_reg[239:224] <= data_reg;
		else key_reg[239:224] <= key_reg[239:224];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0104 )) key_reg[223:208] <= data_reg;
		else key_reg[223:208] <= key_reg[223:208];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0106 )) key_reg[207:192] <= data_reg;
		else key_reg[207:192] <= key_reg[207:192];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0108 )) key_reg[191:176] <= data_reg;
		else key_reg[191:176] <= key_reg[191:176];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h010A )) key_reg[175:160] <= data_reg;
		else key_reg[175:160] <= key_reg[175:160];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h010C )) key_reg[159:144] <= data_reg;
		else key_reg[159:144] <= key_reg[159:144];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h010E )) key_reg[143:128] <= data_reg;
		else key_reg[143:128] <= key_reg[143:128];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0110 )) key_reg[127:112] <= data_reg;
		else key_reg[127:112] <= key_reg[127:112];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0112 )) key_reg[111:96] <= data_reg;
		else key_reg[111:96] <= key_reg[111:96];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0114 )) key_reg[95:80] <= data_reg;
		else key_reg[95:80] <= key_reg[95:80];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0116 )) key_reg[79:64] <= data_reg;
		else key_reg[79:64] <= key_reg[79:64];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0118 )) key_reg[63:48] <= data_reg;
		else key_reg[63:48] <= key_reg[63:48];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h011A )) key_reg[47:32] <= data_reg;
		else key_reg[47:32] <= key_reg[47:32];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h011C )) key_reg[31:16] <= data_reg;
		else key_reg[31:16] <= key_reg[31:16];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h011E )) key_reg[15:0] <= data_reg;
		else key_reg[15:0] <= key_reg[15:0];
		
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0140 )) din_reg[4095:4080] <= data_reg;
		else din_reg[4095:4080] <= din_reg[4095:4080];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0142 )) din_reg[4079:4064] <= data_reg;
		else din_reg[4079:4064] <= din_reg[4079:4064];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0144 )) din_reg[4063:4048] <= data_reg;
		else din_reg[4063:4048] <= din_reg[4063:4048];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0146 )) din_reg[4047:4032] <= data_reg;
		else din_reg[4047:4032] <= din_reg[4047:4032];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0148 )) din_reg[4031:4016] <= data_reg;
		else din_reg[4031:4016] <= din_reg[4031:4016];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h014A )) din_reg[4015:4000] <= data_reg;
		else din_reg[4015:4000] <= din_reg[4015:4000];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h014C )) din_reg[3999:3984] <= data_reg;
		else din_reg[3999:3984] <= din_reg[3999:3984];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h014E )) din_reg[3983:3968] <= data_reg;
		else din_reg[3983:3968] <= din_reg[3983:3968];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0150 )) din_reg[3967:3952] <= data_reg;
		else din_reg[3967:3952] <= din_reg[3967:3952];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0152 )) din_reg[3951:3936] <= data_reg;
		else din_reg[3951:3936] <= din_reg[3951:3936];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0154 )) din_reg[3935:3920] <= data_reg;
		else din_reg[3935:3920] <= din_reg[3935:3920];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0156 )) din_reg[3919:3904] <= data_reg;
		else din_reg[3919:3904] <= din_reg[3919:3904];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0158 )) din_reg[3903:3888] <= data_reg;
		else din_reg[3903:3888] <= din_reg[3903:3888];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h015A )) din_reg[3887:3872] <= data_reg;
		else din_reg[3887:3872] <= din_reg[3887:3872];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h015C )) din_reg[3871:3856] <= data_reg;
		else din_reg[3871:3856] <= din_reg[3871:3856];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h015E )) din_reg[3855:3840] <= data_reg;
		else din_reg[3855:3840] <= din_reg[3855:3840];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0160 )) din_reg[3839:3824] <= data_reg;
		else din_reg[3839:3824] <= din_reg[3839:3824];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0162 )) din_reg[3823:3808] <= data_reg;
		else din_reg[3823:3808] <= din_reg[3823:3808];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0164 )) din_reg[3807:3792] <= data_reg;
		else din_reg[3807:3792] <= din_reg[3807:3792];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0166 )) din_reg[3791:3776] <= data_reg;
		else din_reg[3791:3776] <= din_reg[3791:3776];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0168 )) din_reg[3775:3760] <= data_reg;
		else din_reg[3775:3760] <= din_reg[3775:3760];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h016A )) din_reg[3759:3744] <= data_reg;
		else din_reg[3759:3744] <= din_reg[3759:3744];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h016C )) din_reg[3743:3728] <= data_reg;
		else din_reg[3743:3728] <= din_reg[3743:3728];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h016E )) din_reg[3727:3712] <= data_reg;
		else din_reg[3727:3712] <= din_reg[3727:3712];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0170 )) din_reg[3711:3696] <= data_reg;
		else din_reg[3711:3696] <= din_reg[3711:3696];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0172 )) din_reg[3695:3680] <= data_reg;
		else din_reg[3695:3680] <= din_reg[3695:3680];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0174 )) din_reg[3679:3664] <= data_reg;
		else din_reg[3679:3664] <= din_reg[3679:3664];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0176 )) din_reg[3663:3648] <= data_reg;
		else din_reg[3663:3648] <= din_reg[3663:3648];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0178 )) din_reg[3647:3632] <= data_reg;
		else din_reg[3647:3632] <= din_reg[3647:3632];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h017A )) din_reg[3631:3616] <= data_reg;
		else din_reg[3631:3616] <= din_reg[3631:3616];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h017C )) din_reg[3615:3600] <= data_reg;
		else din_reg[3615:3600] <= din_reg[3615:3600];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h017E )) din_reg[3599:3584] <= data_reg;
		else din_reg[3599:3584] <= din_reg[3599:3584];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0180 )) din_reg[3583:3568] <= data_reg;
		else din_reg[3583:3568] <= din_reg[3583:3568];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0182 )) din_reg[3567:3552] <= data_reg;
		else din_reg[3567:3552] <= din_reg[3567:3552];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0184 )) din_reg[3551:3536] <= data_reg;
		else din_reg[3551:3536] <= din_reg[3551:3536];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0186 )) din_reg[3535:3520] <= data_reg;
		else din_reg[3535:3520] <= din_reg[3535:3520];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0188 )) din_reg[3519:3504] <= data_reg;
		else din_reg[3519:3504] <= din_reg[3519:3504];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h018A )) din_reg[3503:3488] <= data_reg;
		else din_reg[3503:3488] <= din_reg[3503:3488];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h018C )) din_reg[3487:3472] <= data_reg;
		else din_reg[3487:3472] <= din_reg[3487:3472];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h018E )) din_reg[3471:3456] <= data_reg;
		else din_reg[3471:3456] <= din_reg[3471:3456];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0190 )) din_reg[3455:3440] <= data_reg;
		else din_reg[3455:3440] <= din_reg[3455:3440];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0192 )) din_reg[3439:3424] <= data_reg;
		else din_reg[3439:3424] <= din_reg[3439:3424];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0194 )) din_reg[3423:3408] <= data_reg;
		else din_reg[3423:3408] <= din_reg[3423:3408];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0196 )) din_reg[3407:3392] <= data_reg;
		else din_reg[3407:3392] <= din_reg[3407:3392];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0198 )) din_reg[3391:3376] <= data_reg;
		else din_reg[3391:3376] <= din_reg[3391:3376];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h019A )) din_reg[3375:3360] <= data_reg;
		else din_reg[3375:3360] <= din_reg[3375:3360];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h019C )) din_reg[3359:3344] <= data_reg;
		else din_reg[3359:3344] <= din_reg[3359:3344];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h019E )) din_reg[3343:3328] <= data_reg;
		else din_reg[3343:3328] <= din_reg[3343:3328];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01A0 )) din_reg[3327:3312] <= data_reg;
		else din_reg[3327:3312] <= din_reg[3327:3312];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01A2 )) din_reg[3311:3296] <= data_reg;
		else din_reg[3311:3296] <= din_reg[3311:3296];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01A4 )) din_reg[3295:3280] <= data_reg;
		else din_reg[3295:3280] <= din_reg[3295:3280];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01A6 )) din_reg[3279:3264] <= data_reg;
		else din_reg[3279:3264] <= din_reg[3279:3264];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01A8 )) din_reg[3263:3248] <= data_reg;
		else din_reg[3263:3248] <= din_reg[3263:3248];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01AA )) din_reg[3247:3232] <= data_reg;
		else din_reg[3247:3232] <= din_reg[3247:3232];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01AC )) din_reg[3231:3216] <= data_reg;
		else din_reg[3231:3216] <= din_reg[3231:3216];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01AE )) din_reg[3215:3200] <= data_reg;
		else din_reg[3215:3200] <= din_reg[3215:3200];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01B0 )) din_reg[3199:3184] <= data_reg;
		else din_reg[3199:3184] <= din_reg[3199:3184];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01B2 )) din_reg[3183:3168] <= data_reg;
		else din_reg[3183:3168] <= din_reg[3183:3168];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01B4 )) din_reg[3167:3152] <= data_reg;
		else din_reg[3167:3152] <= din_reg[3167:3152];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01B6 )) din_reg[3151:3136] <= data_reg;
		else din_reg[3151:3136] <= din_reg[3151:3136];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01B8 )) din_reg[3135:3120] <= data_reg;
		else din_reg[3135:3120] <= din_reg[3135:3120];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01BA )) din_reg[3119:3104] <= data_reg;
		else din_reg[3119:3104] <= din_reg[3119:3104];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01BC )) din_reg[3103:3088] <= data_reg;
		else din_reg[3103:3088] <= din_reg[3103:3088];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01BE )) din_reg[3087:3072] <= data_reg;
		else din_reg[3087:3072] <= din_reg[3087:3072];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01C0 )) din_reg[3071:3056] <= data_reg;
		else din_reg[3071:3056] <= din_reg[3071:3056];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01C2 )) din_reg[3055:3040] <= data_reg;
		else din_reg[3055:3040] <= din_reg[3055:3040];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01C4 )) din_reg[3039:3024] <= data_reg;
		else din_reg[3039:3024] <= din_reg[3039:3024];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01C6 )) din_reg[3023:3008] <= data_reg;
		else din_reg[3023:3008] <= din_reg[3023:3008];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01C8 )) din_reg[3007:2992] <= data_reg;
		else din_reg[3007:2992] <= din_reg[3007:2992];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01CA )) din_reg[2991:2976] <= data_reg;
		else din_reg[2991:2976] <= din_reg[2991:2976];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01CC )) din_reg[2975:2960] <= data_reg;
		else din_reg[2975:2960] <= din_reg[2975:2960];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01CE )) din_reg[2959:2944] <= data_reg;
		else din_reg[2959:2944] <= din_reg[2959:2944];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01D0 )) din_reg[2943:2928] <= data_reg;
		else din_reg[2943:2928] <= din_reg[2943:2928];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01D2 )) din_reg[2927:2912] <= data_reg;
		else din_reg[2927:2912] <= din_reg[2927:2912];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01D4 )) din_reg[2911:2896] <= data_reg;
		else din_reg[2911:2896] <= din_reg[2911:2896];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01D6 )) din_reg[2895:2880] <= data_reg;
		else din_reg[2895:2880] <= din_reg[2895:2880];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01D8 )) din_reg[2879:2864] <= data_reg;
		else din_reg[2879:2864] <= din_reg[2879:2864];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01DA )) din_reg[2863:2848] <= data_reg;
		else din_reg[2863:2848] <= din_reg[2863:2848];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01DC )) din_reg[2847:2832] <= data_reg;
		else din_reg[2847:2832] <= din_reg[2847:2832];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01DE )) din_reg[2831:2816] <= data_reg;
		else din_reg[2831:2816] <= din_reg[2831:2816];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01E0 )) din_reg[2815:2800] <= data_reg;
		else din_reg[2815:2800] <= din_reg[2815:2800];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01E2 )) din_reg[2799:2784] <= data_reg;
		else din_reg[2799:2784] <= din_reg[2799:2784];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01E4 )) din_reg[2783:2768] <= data_reg;
		else din_reg[2783:2768] <= din_reg[2783:2768];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01E6 )) din_reg[2767:2752] <= data_reg;
		else din_reg[2767:2752] <= din_reg[2767:2752];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01E8 )) din_reg[2751:2736] <= data_reg;
		else din_reg[2751:2736] <= din_reg[2751:2736];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01EA )) din_reg[2735:2720] <= data_reg;
		else din_reg[2735:2720] <= din_reg[2735:2720];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01EC )) din_reg[2719:2704] <= data_reg;
		else din_reg[2719:2704] <= din_reg[2719:2704];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01EE )) din_reg[2703:2688] <= data_reg;
		else din_reg[2703:2688] <= din_reg[2703:2688];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01F0 )) din_reg[2687:2672] <= data_reg;
		else din_reg[2687:2672] <= din_reg[2687:2672];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01F2 )) din_reg[2671:2656] <= data_reg;
		else din_reg[2671:2656] <= din_reg[2671:2656];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01F4 )) din_reg[2655:2640] <= data_reg;
		else din_reg[2655:2640] <= din_reg[2655:2640];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01F6 )) din_reg[2639:2624] <= data_reg;
		else din_reg[2639:2624] <= din_reg[2639:2624];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01F8 )) din_reg[2623:2608] <= data_reg;
		else din_reg[2623:2608] <= din_reg[2623:2608];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01FA )) din_reg[2607:2592] <= data_reg;
		else din_reg[2607:2592] <= din_reg[2607:2592];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01FC )) din_reg[2591:2576] <= data_reg;
		else din_reg[2591:2576] <= din_reg[2591:2576];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h01FE )) din_reg[2575:2560] <= data_reg;
		else din_reg[2575:2560] <= din_reg[2575:2560];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0200 )) din_reg[2559:2544] <= data_reg;
		else din_reg[2559:2544] <= din_reg[2559:2544];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0202 )) din_reg[2543:2528] <= data_reg;
		else din_reg[2543:2528] <= din_reg[2543:2528];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0204 )) din_reg[2527:2512] <= data_reg;
		else din_reg[2527:2512] <= din_reg[2527:2512];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0206 )) din_reg[2511:2496] <= data_reg;
		else din_reg[2511:2496] <= din_reg[2511:2496];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0208 )) din_reg[2495:2480] <= data_reg;
		else din_reg[2495:2480] <= din_reg[2495:2480];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h020A )) din_reg[2479:2464] <= data_reg;
		else din_reg[2479:2464] <= din_reg[2479:2464];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h020C )) din_reg[2463:2448] <= data_reg;
		else din_reg[2463:2448] <= din_reg[2463:2448];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h020E )) din_reg[2447:2432] <= data_reg;
		else din_reg[2447:2432] <= din_reg[2447:2432];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0210 )) din_reg[2431:2416] <= data_reg;
		else din_reg[2431:2416] <= din_reg[2431:2416];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0212 )) din_reg[2415:2400] <= data_reg;
		else din_reg[2415:2400] <= din_reg[2415:2400];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0214 )) din_reg[2399:2384] <= data_reg;
		else din_reg[2399:2384] <= din_reg[2399:2384];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0216 )) din_reg[2383:2368] <= data_reg;
		else din_reg[2383:2368] <= din_reg[2383:2368];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0218 )) din_reg[2367:2352] <= data_reg;
		else din_reg[2367:2352] <= din_reg[2367:2352];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h021A )) din_reg[2351:2336] <= data_reg;
		else din_reg[2351:2336] <= din_reg[2351:2336];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h021C )) din_reg[2335:2320] <= data_reg;
		else din_reg[2335:2320] <= din_reg[2335:2320];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h021E )) din_reg[2319:2304] <= data_reg;
		else din_reg[2319:2304] <= din_reg[2319:2304];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0220 )) din_reg[2303:2288] <= data_reg;
		else din_reg[2303:2288] <= din_reg[2303:2288];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0222 )) din_reg[2287:2272] <= data_reg;
		else din_reg[2287:2272] <= din_reg[2287:2272];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0224 )) din_reg[2271:2256] <= data_reg;
		else din_reg[2271:2256] <= din_reg[2271:2256];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0226 )) din_reg[2255:2240] <= data_reg;
		else din_reg[2255:2240] <= din_reg[2255:2240];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0228 )) din_reg[2239:2224] <= data_reg;
		else din_reg[2239:2224] <= din_reg[2239:2224];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h022A )) din_reg[2223:2208] <= data_reg;
		else din_reg[2223:2208] <= din_reg[2223:2208];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h022C )) din_reg[2207:2192] <= data_reg;
		else din_reg[2207:2192] <= din_reg[2207:2192];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h022E )) din_reg[2191:2176] <= data_reg;
		else din_reg[2191:2176] <= din_reg[2191:2176];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0230 )) din_reg[2175:2160] <= data_reg;
		else din_reg[2175:2160] <= din_reg[2175:2160];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0232 )) din_reg[2159:2144] <= data_reg;
		else din_reg[2159:2144] <= din_reg[2159:2144];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0234 )) din_reg[2143:2128] <= data_reg;
		else din_reg[2143:2128] <= din_reg[2143:2128];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0236 )) din_reg[2127:2112] <= data_reg;
		else din_reg[2127:2112] <= din_reg[2127:2112];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0238 )) din_reg[2111:2096] <= data_reg;
		else din_reg[2111:2096] <= din_reg[2111:2096];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h023A )) din_reg[2095:2080] <= data_reg;
		else din_reg[2095:2080] <= din_reg[2095:2080];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h023C )) din_reg[2079:2064] <= data_reg;
		else din_reg[2079:2064] <= din_reg[2079:2064];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h023E )) din_reg[2063:2048] <= data_reg;
		else din_reg[2063:2048] <= din_reg[2063:2048];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0240 )) din_reg[2047:2032] <= data_reg;
		else din_reg[2047:2032] <= din_reg[2047:2032];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0242 )) din_reg[2031:2016] <= data_reg;
		else din_reg[2031:2016] <= din_reg[2031:2016];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0244 )) din_reg[2015:2000] <= data_reg;
		else din_reg[2015:2000] <= din_reg[2015:2000];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0246 )) din_reg[1999:1984] <= data_reg;
		else din_reg[1999:1984] <= din_reg[1999:1984];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0248 )) din_reg[1983:1968] <= data_reg;
		else din_reg[1983:1968] <= din_reg[1983:1968];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h024A )) din_reg[1967:1952] <= data_reg;
		else din_reg[1967:1952] <= din_reg[1967:1952];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h024C )) din_reg[1951:1936] <= data_reg;
		else din_reg[1951:1936] <= din_reg[1951:1936];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h024E )) din_reg[1935:1920] <= data_reg;
		else din_reg[1935:1920] <= din_reg[1935:1920];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0250 )) din_reg[1919:1904] <= data_reg;
		else din_reg[1919:1904] <= din_reg[1919:1904];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0252 )) din_reg[1903:1888] <= data_reg;
		else din_reg[1903:1888] <= din_reg[1903:1888];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0254 )) din_reg[1887:1872] <= data_reg;
		else din_reg[1887:1872] <= din_reg[1887:1872];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0256 )) din_reg[1871:1856] <= data_reg;
		else din_reg[1871:1856] <= din_reg[1871:1856];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0258 )) din_reg[1855:1840] <= data_reg;
		else din_reg[1855:1840] <= din_reg[1855:1840];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h025A )) din_reg[1839:1824] <= data_reg;
		else din_reg[1839:1824] <= din_reg[1839:1824];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h025C )) din_reg[1823:1808] <= data_reg;
		else din_reg[1823:1808] <= din_reg[1823:1808];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h025E )) din_reg[1807:1792] <= data_reg;
		else din_reg[1807:1792] <= din_reg[1807:1792];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0260 )) din_reg[1791:1776] <= data_reg;
		else din_reg[1791:1776] <= din_reg[1791:1776];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0262 )) din_reg[1775:1760] <= data_reg;
		else din_reg[1775:1760] <= din_reg[1775:1760];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0264 )) din_reg[1759:1744] <= data_reg;
		else din_reg[1759:1744] <= din_reg[1759:1744];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0266 )) din_reg[1743:1728] <= data_reg;
		else din_reg[1743:1728] <= din_reg[1743:1728];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0268 )) din_reg[1727:1712] <= data_reg;
		else din_reg[1727:1712] <= din_reg[1727:1712];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h026A )) din_reg[1711:1696] <= data_reg;
		else din_reg[1711:1696] <= din_reg[1711:1696];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h026C )) din_reg[1695:1680] <= data_reg;
		else din_reg[1695:1680] <= din_reg[1695:1680];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h026E )) din_reg[1679:1664] <= data_reg;
		else din_reg[1679:1664] <= din_reg[1679:1664];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0270 )) din_reg[1663:1648] <= data_reg;
		else din_reg[1663:1648] <= din_reg[1663:1648];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0272 )) din_reg[1647:1632] <= data_reg;
		else din_reg[1647:1632] <= din_reg[1647:1632];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0274 )) din_reg[1631:1616] <= data_reg;
		else din_reg[1631:1616] <= din_reg[1631:1616];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0276 )) din_reg[1615:1600] <= data_reg;
		else din_reg[1615:1600] <= din_reg[1615:1600];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0278 )) din_reg[1599:1584] <= data_reg;
		else din_reg[1599:1584] <= din_reg[1599:1584];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h027A )) din_reg[1583:1568] <= data_reg;
		else din_reg[1583:1568] <= din_reg[1583:1568];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h027C )) din_reg[1567:1552] <= data_reg;
		else din_reg[1567:1552] <= din_reg[1567:1552];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h027E )) din_reg[1551:1536] <= data_reg;
		else din_reg[1551:1536] <= din_reg[1551:1536];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0280 )) din_reg[1535:1520] <= data_reg;
		else din_reg[1535:1520] <= din_reg[1535:1520];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0282 )) din_reg[1519:1504] <= data_reg;
		else din_reg[1519:1504] <= din_reg[1519:1504];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0284 )) din_reg[1503:1488] <= data_reg;
		else din_reg[1503:1488] <= din_reg[1503:1488];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0286 )) din_reg[1487:1472] <= data_reg;
		else din_reg[1487:1472] <= din_reg[1487:1472];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0288 )) din_reg[1471:1456] <= data_reg;
		else din_reg[1471:1456] <= din_reg[1471:1456];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h028A )) din_reg[1455:1440] <= data_reg;
		else din_reg[1455:1440] <= din_reg[1455:1440];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h028C )) din_reg[1439:1424] <= data_reg;
		else din_reg[1439:1424] <= din_reg[1439:1424];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h028E )) din_reg[1423:1408] <= data_reg;
		else din_reg[1423:1408] <= din_reg[1423:1408];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0290 )) din_reg[1407:1392] <= data_reg;
		else din_reg[1407:1392] <= din_reg[1407:1392];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0292 )) din_reg[1391:1376] <= data_reg;
		else din_reg[1391:1376] <= din_reg[1391:1376];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0294 )) din_reg[1375:1360] <= data_reg;
		else din_reg[1375:1360] <= din_reg[1375:1360];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0296 )) din_reg[1359:1344] <= data_reg;
		else din_reg[1359:1344] <= din_reg[1359:1344];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0298 )) din_reg[1343:1328] <= data_reg;
		else din_reg[1343:1328] <= din_reg[1343:1328];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h029A )) din_reg[1327:1312] <= data_reg;
		else din_reg[1327:1312] <= din_reg[1327:1312];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h029C )) din_reg[1311:1296] <= data_reg;
		else din_reg[1311:1296] <= din_reg[1311:1296];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h029E )) din_reg[1295:1280] <= data_reg;
		else din_reg[1295:1280] <= din_reg[1295:1280];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02A0 )) din_reg[1279:1264] <= data_reg;
		else din_reg[1279:1264] <= din_reg[1279:1264];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02A2 )) din_reg[1263:1248] <= data_reg;
		else din_reg[1263:1248] <= din_reg[1263:1248];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02A4 )) din_reg[1247:1232] <= data_reg;
		else din_reg[1247:1232] <= din_reg[1247:1232];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02A6 )) din_reg[1231:1216] <= data_reg;
		else din_reg[1231:1216] <= din_reg[1231:1216];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02A8 )) din_reg[1215:1200] <= data_reg;
		else din_reg[1215:1200] <= din_reg[1215:1200];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02AA )) din_reg[1199:1184] <= data_reg;
		else din_reg[1199:1184] <= din_reg[1199:1184];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02AC )) din_reg[1183:1168] <= data_reg;
		else din_reg[1183:1168] <= din_reg[1183:1168];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02AE )) din_reg[1167:1152] <= data_reg;
		else din_reg[1167:1152] <= din_reg[1167:1152];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02B0 )) din_reg[1151:1136] <= data_reg;
		else din_reg[1151:1136] <= din_reg[1151:1136];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02B2 )) din_reg[1135:1120] <= data_reg;
		else din_reg[1135:1120] <= din_reg[1135:1120];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02B4 )) din_reg[1119:1104] <= data_reg;
		else din_reg[1119:1104] <= din_reg[1119:1104];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02B6 )) din_reg[1103:1088] <= data_reg;
		else din_reg[1103:1088] <= din_reg[1103:1088];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02B8 )) din_reg[1087:1072] <= data_reg;
		else din_reg[1087:1072] <= din_reg[1087:1072];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02BA )) din_reg[1071:1056] <= data_reg;
		else din_reg[1071:1056] <= din_reg[1071:1056];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02BC )) din_reg[1055:1040] <= data_reg;
		else din_reg[1055:1040] <= din_reg[1055:1040];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02BE )) din_reg[1039:1024] <= data_reg;
		else din_reg[1039:1024] <= din_reg[1039:1024];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02C0 )) din_reg[1023:1008] <= data_reg;
		else din_reg[1023:1008] <= din_reg[1023:1008];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02C2 )) din_reg[1007:992] <= data_reg;
		else din_reg[1007:992] <= din_reg[1007:992];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02C4 )) din_reg[991:976] <= data_reg;
		else din_reg[991:976] <= din_reg[991:976];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02C6 )) din_reg[975:960] <= data_reg;
		else din_reg[975:960] <= din_reg[975:960];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02C8 )) din_reg[959:944] <= data_reg;
		else din_reg[959:944] <= din_reg[959:944];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02CA )) din_reg[943:928] <= data_reg;
		else din_reg[943:928] <= din_reg[943:928];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02CC )) din_reg[927:912] <= data_reg;
		else din_reg[927:912] <= din_reg[927:912];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02CE )) din_reg[911:896] <= data_reg;
		else din_reg[911:896] <= din_reg[911:896];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02D0 )) din_reg[895:880] <= data_reg;
		else din_reg[895:880] <= din_reg[895:880];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02D2 )) din_reg[879:864] <= data_reg;
		else din_reg[879:864] <= din_reg[879:864];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02D4 )) din_reg[863:848] <= data_reg;
		else din_reg[863:848] <= din_reg[863:848];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02D6 )) din_reg[847:832] <= data_reg;
		else din_reg[847:832] <= din_reg[847:832];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02D8 )) din_reg[831:816] <= data_reg;
		else din_reg[831:816] <= din_reg[831:816];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02DA )) din_reg[815:800] <= data_reg;
		else din_reg[815:800] <= din_reg[815:800];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02DC )) din_reg[799:784] <= data_reg;
		else din_reg[799:784] <= din_reg[799:784];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02DE )) din_reg[783:768] <= data_reg;
		else din_reg[783:768] <= din_reg[783:768];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02E0 )) din_reg[767:752] <= data_reg;
		else din_reg[767:752] <= din_reg[767:752];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02E2 )) din_reg[751:736] <= data_reg;
		else din_reg[751:736] <= din_reg[751:736];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02E4 )) din_reg[735:720] <= data_reg;
		else din_reg[735:720] <= din_reg[735:720];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02E6 )) din_reg[719:704] <= data_reg;
		else din_reg[719:704] <= din_reg[719:704];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02E8 )) din_reg[703:688] <= data_reg;
		else din_reg[703:688] <= din_reg[703:688];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02EA )) din_reg[687:672] <= data_reg;
		else din_reg[687:672] <= din_reg[687:672];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02EC )) din_reg[671:656] <= data_reg;
		else din_reg[671:656] <= din_reg[671:656];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02EE )) din_reg[655:640] <= data_reg;
		else din_reg[655:640] <= din_reg[655:640];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02F0 )) din_reg[639:624] <= data_reg;
		else din_reg[639:624] <= din_reg[639:624];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02F2 )) din_reg[623:608] <= data_reg;
		else din_reg[623:608] <= din_reg[623:608];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02F4 )) din_reg[607:592] <= data_reg;
		else din_reg[607:592] <= din_reg[607:592];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02F6 )) din_reg[591:576] <= data_reg;
		else din_reg[591:576] <= din_reg[591:576];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02F8 )) din_reg[575:560] <= data_reg;
		else din_reg[575:560] <= din_reg[575:560];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02FA )) din_reg[559:544] <= data_reg;
		else din_reg[559:544] <= din_reg[559:544];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02FC )) din_reg[543:528] <= data_reg;
		else din_reg[543:528] <= din_reg[543:528];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h02FE )) din_reg[527:512] <= data_reg;
		else din_reg[527:512] <= din_reg[527:512];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0300 )) din_reg[511:496] <= data_reg;
		else din_reg[511:496] <= din_reg[511:496];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0302 )) din_reg[495:480] <= data_reg;
		else din_reg[495:480] <= din_reg[495:480];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0304 )) din_reg[479:464] <= data_reg;
		else din_reg[479:464] <= din_reg[479:464];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0306 )) din_reg[463:448] <= data_reg;
		else din_reg[463:448] <= din_reg[463:448];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0308 )) din_reg[447:432] <= data_reg;
		else din_reg[447:432] <= din_reg[447:432];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h030A )) din_reg[431:416] <= data_reg;
		else din_reg[431:416] <= din_reg[431:416];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h030C )) din_reg[415:400] <= data_reg;
		else din_reg[415:400] <= din_reg[415:400];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h030E )) din_reg[399:384] <= data_reg;
		else din_reg[399:384] <= din_reg[399:384];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0310 )) din_reg[383:368] <= data_reg;
		else din_reg[383:368] <= din_reg[383:368];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0312 )) din_reg[367:352] <= data_reg;
		else din_reg[367:352] <= din_reg[367:352];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0314 )) din_reg[351:336] <= data_reg;
		else din_reg[351:336] <= din_reg[351:336];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0316 )) din_reg[335:320] <= data_reg;
		else din_reg[335:320] <= din_reg[335:320];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0318 )) din_reg[319:304] <= data_reg;
		else din_reg[319:304] <= din_reg[319:304];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h031A )) din_reg[303:288] <= data_reg;
		else din_reg[303:288] <= din_reg[303:288];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h031C )) din_reg[287:272] <= data_reg;
		else din_reg[287:272] <= din_reg[287:272];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h031E )) din_reg[271:256] <= data_reg;
		else din_reg[271:256] <= din_reg[271:256];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0320 )) din_reg[255:240] <= data_reg;
		else din_reg[255:240] <= din_reg[255:240];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0322 )) din_reg[239:224] <= data_reg;
		else din_reg[239:224] <= din_reg[239:224];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0324 )) din_reg[223:208] <= data_reg;
		else din_reg[223:208] <= din_reg[223:208];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0326 )) din_reg[207:192] <= data_reg;
		else din_reg[207:192] <= din_reg[207:192];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0328 )) din_reg[191:176] <= data_reg;
		else din_reg[191:176] <= din_reg[191:176];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h032A )) din_reg[175:160] <= data_reg;
		else din_reg[175:160] <= din_reg[175:160];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h032C )) din_reg[159:144] <= data_reg;
		else din_reg[159:144] <= din_reg[159:144];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h032E )) din_reg[143:128] <= data_reg;
		else din_reg[143:128] <= din_reg[143:128];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0330 )) din_reg[127:112] <= data_reg;
		else din_reg[127:112] <= din_reg[127:112];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0332 )) din_reg[111:96] <= data_reg;
		else din_reg[111:96] <= din_reg[111:96];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0334 )) din_reg[95:80] <= data_reg;
		else din_reg[95:80] <= din_reg[95:80];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0336 )) din_reg[79:64] <= data_reg;
		else din_reg[79:64] <= din_reg[79:64];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0338 )) din_reg[63:48] <= data_reg;
		else din_reg[63:48] <= din_reg[63:48];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h033A )) din_reg[47:32] <= data_reg;
		else din_reg[47:32] <= din_reg[47:32];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h033C )) din_reg[31:16] <= data_reg;
		else din_reg[31:16] <= din_reg[31:16];
		if (( write_ena == 1'b1 ) && ( addr_reg == 16'h033E )) din_reg[15:0] <= data_reg;
		else din_reg[15:0] <= din_reg[15:0];
		
    end
  end


  // Read data multiplax
  always @( addr_reg or rst or enc_dec or key_gen or data_ena or KVAL or TVAL or RESULT ) begin
    case( addr_reg )
      	16'h0002: dout_mux = { 13'h0000, rst, key_gen, data_ena };
      	16'h000c: dout_mux = { KVAL, TVAL, enc_dec };

	16'h0360:    dout_mux = RESULT[2047:2032];
	16'h0362:    dout_mux = RESULT[2031:2016];
	16'h0364:    dout_mux = RESULT[2015:2000];
	16'h0366:    dout_mux = RESULT[1999:1984];
	16'h0368:    dout_mux = RESULT[1983:1968];
	16'h036A:    dout_mux = RESULT[1967:1952];
	16'h036C:    dout_mux = RESULT[1951:1936];
	16'h036E:    dout_mux = RESULT[1935:1920];
	16'h0370:    dout_mux = RESULT[1919:1904];
	16'h0372:    dout_mux = RESULT[1903:1888];
	16'h0374:    dout_mux = RESULT[1887:1872];
	16'h0376:    dout_mux = RESULT[1871:1856];
	16'h0378:    dout_mux = RESULT[1855:1840];
	16'h037A:    dout_mux = RESULT[1839:1824];
	16'h037C:    dout_mux = RESULT[1823:1808];
	16'h037E:    dout_mux = RESULT[1807:1792];
	16'h0380:    dout_mux = RESULT[1791:1776];
	16'h0382:    dout_mux = RESULT[1775:1760];
	16'h0384:    dout_mux = RESULT[1759:1744];
	16'h0386:    dout_mux = RESULT[1743:1728];
	16'h0388:    dout_mux = RESULT[1727:1712];
	16'h038A:    dout_mux = RESULT[1711:1696];
	16'h038C:    dout_mux = RESULT[1695:1680];
	16'h038E:    dout_mux = RESULT[1679:1664];
	16'h0390:    dout_mux = RESULT[1663:1648];
	16'h0392:    dout_mux = RESULT[1647:1632];
	16'h0394:    dout_mux = RESULT[1631:1616];
	16'h0396:    dout_mux = RESULT[1615:1600];
	16'h0398:    dout_mux = RESULT[1599:1584];
	16'h039A:    dout_mux = RESULT[1583:1568];
	16'h039C:    dout_mux = RESULT[1567:1552];
	16'h039E:    dout_mux = RESULT[1551:1536];
	16'h03A0:    dout_mux = RESULT[1535:1520];
	16'h03A2:    dout_mux = RESULT[1519:1504];
	16'h03A4:    dout_mux = RESULT[1503:1488];
	16'h03A6:    dout_mux = RESULT[1487:1472];
	16'h03A8:    dout_mux = RESULT[1471:1456];
	16'h03AA:    dout_mux = RESULT[1455:1440];
	16'h03AC:    dout_mux = RESULT[1439:1424];
	16'h03AE:    dout_mux = RESULT[1423:1408];
	16'h03B0:    dout_mux = RESULT[1407:1392];
	16'h03B2:    dout_mux = RESULT[1391:1376];
	16'h03B4:    dout_mux = RESULT[1375:1360];
	16'h03B6:    dout_mux = RESULT[1359:1344];
	16'h03B8:    dout_mux = RESULT[1343:1328];
	16'h03BA:    dout_mux = RESULT[1327:1312];
	16'h03BC:    dout_mux = RESULT[1311:1296];
	16'h03BE:    dout_mux = RESULT[1295:1280];
	16'h03C0:    dout_mux = RESULT[1279:1264];
	16'h03C2:    dout_mux = RESULT[1263:1248];
	16'h03C4:    dout_mux = RESULT[1247:1232];
	16'h03C6:    dout_mux = RESULT[1231:1216];
	16'h03C8:    dout_mux = RESULT[1215:1200];
	16'h03CA:    dout_mux = RESULT[1199:1184];
	16'h03CC:    dout_mux = RESULT[1183:1168];
	16'h03CE:    dout_mux = RESULT[1167:1152];
	16'h03D0:    dout_mux = RESULT[1151:1136];
	16'h03D2:    dout_mux = RESULT[1135:1120];
	16'h03D4:    dout_mux = RESULT[1119:1104];
	16'h03D6:    dout_mux = RESULT[1103:1088];
	16'h03D8:    dout_mux = RESULT[1087:1072];
	16'h03DA:    dout_mux = RESULT[1071:1056];
	16'h03DC:    dout_mux = RESULT[1055:1040];
	16'h03DE:    dout_mux = RESULT[1039:1024];
	16'h03E0:    dout_mux = RESULT[1023:1008];
	16'h03E2:    dout_mux = RESULT[1007:992];
	16'h03E4:    dout_mux = RESULT[991:976];
	16'h03E6:    dout_mux = RESULT[975:960];
	16'h03E8:    dout_mux = RESULT[959:944];
	16'h03EA:    dout_mux = RESULT[943:928];
	16'h03EC:    dout_mux = RESULT[927:912];
	16'h03EE:    dout_mux = RESULT[911:896];
	16'h03F0:    dout_mux = RESULT[895:880];
	16'h03F2:    dout_mux = RESULT[879:864];
	16'h03F4:    dout_mux = RESULT[863:848];
	16'h03F6:    dout_mux = RESULT[847:832];
	16'h03F8:    dout_mux = RESULT[831:816];
	16'h03FA:    dout_mux = RESULT[815:800];
	16'h03FC:    dout_mux = RESULT[799:784];
	16'h03FE:    dout_mux = RESULT[783:768];
	16'h0400:    dout_mux = RESULT[767:752];
	16'h0402:    dout_mux = RESULT[751:736];
	16'h0404:    dout_mux = RESULT[735:720];
	16'h0406:    dout_mux = RESULT[719:704];
	16'h0408:    dout_mux = RESULT[703:688];
	16'h040A:    dout_mux = RESULT[687:672];
	16'h040C:    dout_mux = RESULT[671:656];
	16'h040E:    dout_mux = RESULT[655:640];
	16'h0410:    dout_mux = RESULT[639:624];
	16'h0412:    dout_mux = RESULT[623:608];
	16'h0414:    dout_mux = RESULT[607:592];
	16'h0416:    dout_mux = RESULT[591:576];
	16'h0418:    dout_mux = RESULT[575:560];
	16'h041A:    dout_mux = RESULT[559:544];
	16'h041C:    dout_mux = RESULT[543:528];
	16'h041E:    dout_mux = RESULT[527:512];
	16'h0420:    dout_mux = RESULT[511:496];
	16'h0422:    dout_mux = RESULT[495:480];
	16'h0424:    dout_mux = RESULT[479:464];
	16'h0426:    dout_mux = RESULT[463:448];
	16'h0428:    dout_mux = RESULT[447:432];
	16'h042A:    dout_mux = RESULT[431:416];
	16'h042C:    dout_mux = RESULT[415:400];
	16'h042E:    dout_mux = RESULT[399:384];
	16'h0430:    dout_mux = RESULT[383:368];
	16'h0432:    dout_mux = RESULT[367:352];
	16'h0434:    dout_mux = RESULT[351:336];
	16'h0436:    dout_mux = RESULT[335:320];
	16'h0438:    dout_mux = RESULT[319:304];
	16'h043A:    dout_mux = RESULT[303:288];
	16'h043C:    dout_mux = RESULT[287:272];
	16'h043E:    dout_mux = RESULT[271:256];
	16'h0440:    dout_mux = RESULT[255:240];
	16'h0442:    dout_mux = RESULT[239:224];
	16'h0444:    dout_mux = RESULT[223:208];
	16'h0446:    dout_mux = RESULT[207:192];
	16'h0448:    dout_mux = RESULT[191:176];
	16'h044A:    dout_mux = RESULT[175:160];
	16'h044C:    dout_mux = RESULT[159:144];
	16'h044E:    dout_mux = RESULT[143:128];
	16'h0450:    dout_mux = RESULT[127:112];
	16'h0452:    dout_mux = RESULT[111:96];
	16'h0454:    dout_mux = RESULT[95:80];
	16'h0456:    dout_mux = RESULT[79:64];
	16'h0458:    dout_mux = RESULT[63:48];
	16'h045A:    dout_mux = RESULT[47:32];
	16'h045C:    dout_mux = RESULT[31:16];
	16'h045E:    dout_mux = RESULT[15:0];

      	16'hfffc: dout_mux = 16'h4522;

       default: dout_mux = 16'h0000;
    endcase
  end

  //
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) begin
      wbusy_reg <= 1'b0;
      rrdy_reg <= 1'b0;
      hdout_reg <= 8'h00;
    end
    else begin
      if (( now_if_state == READ2 ) && ( HWE == 1'b1 )) wbusy_reg <= 1'b1;
      else if ( next_if_state == CMD ) wbusy_reg <= 1'b0;
      else wbusy_reg <= wbusy_reg;

      if ( now_if_state == READ3 ) rrdy_reg <= 1'b1;
      else if ( now_if_state == READ4 ) rrdy_reg <= 1'b1;
      else rrdy_reg <= 1'b0;

      if ( now_if_state == READ3 ) hdout_reg <= dout_mux[15:8];
      else if ( now_if_state == READ4 ) hdout_reg <= dout_mux[7:0];
      else hdout_reg <= hdout_reg;
    end
  end

  assign WRDYn = wbusy_reg;
  assign RRDYn = ~rrdy_reg;
  assign HDOUT = hdout_reg;

  assign ENCn_DEC = enc_dec;
  assign KEY_GEN = key_gen;
  assign DATA_EN = data_ena;
  assign KEY_OUT = key_reg;
  assign DATA_OUT = din_reg;

endmodule
