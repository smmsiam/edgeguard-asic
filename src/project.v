`default_nettype none

module tt_um_edgeguard_asic (
    input  wire [7:0] ui_in,    // Dedicated inputs: 8-bit digitized voltage reading (0-255)
    output wire [7:0] uo_out,   // Dedicated outputs: [0]=Relay Trip, [1]=Warning, [7:2]=Fault Count
    input  wire [7:0] uio_in,   // IOs: Input path (unused)
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (0=input, 1=output)
    input  wire       ena,      // Always 1 when powered
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset_n - low to reset
);

  // Safe operating voltage limits (scaled 0 to 255)
  localparam [7:0] OVER_VOLTAGE_LIMIT  = 8'd220;
  localparam [7:0] UNDER_VOLTAGE_LIMIT = 8'd110;
  localparam [3:0] PERSISTENCE_CYCLES  = 4'd5; // Must stay unsafe for 5 cycles to avoid false trips

  reg [3:0] spike_counter;
  reg [5:0] total_faults;
  reg       relay_trip;
  reg       warning_flag;

  wire is_unsafe = (ui_in > OVER_VOLTAGE_LIMIT) || (ui_in < UNDER_VOLTAGE_LIMIT);

  always @(posedge clk) begin
    if (!rst_n) begin
      spike_counter <= 4'd0;
      total_faults  <= 6'd0;
      relay_trip    <= 1'b0;
      warning_flag  <= 1'b0;
    end else if (ena) begin
      if (is_unsafe) begin
        warning_flag <= 1'b1;
        if (spike_counter < PERSISTENCE_CYCLES) begin
          spike_counter <= spike_counter + 4'd1;
        end else if (!relay_trip) begin
          // Trigger hardware cut-off after sustained fault
          relay_trip <= 1'b1;
          if (total_faults < 6'd63) begin
            total_faults <= total_faults + 6'd1;
          end
        end
      end else begin
        // Voltage returned to safe range; reset filter counter
        spike_counter <= 4'd0;
        warning_flag  <= 1'b0;
      end
    end
  end

  // Map internal registers to physical chip output pins
  assign uo_out[0]   = relay_trip;
  assign uo_out[1]   = warning_flag;
  assign uo_out[7:2] = total_faults;

  // Unused bidirectional pins set to safe defaults
  assign uio_out = 8'b00000000;
  assign uio_oe  = 8'b00000000;

  // Prevent unused input warnings
  wire _unused = &{uio_in, 1'b0};

endmodule
