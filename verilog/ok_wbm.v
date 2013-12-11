//------------------------------------------------------------------------
// ok_wbm.v
//
// $Rev$ $Date$
//------------------------------------------------------------------------
`default_nettype none
`timescale 1ns / 1ps

module ok_wbm (
	input  wire [7:0]  hi_in,
	output wire [1:0]  hi_out,
	inout  wire [15:0] hi_inout,
	inout  wire        hi_aa,
   
	output wire        hi_muxsel,
   
	input  wire        clk1,
	output wire [7:0]  led,
	output wire [15:0]  jp1,
	input  wire [3:0]  button
	);

wire        ti_clk;
wire [30:0] ok1;
wire [16:0] ok2;

// Endpoint connections:
wire [15:0]  ep00wire;
wire [15:0]  ep01wire;
wire [15:0]  ep20wire;
wire [15:0]  ep21wire;
wire [15:0]  ep40trig;
wire [15:0]  ep60trig;

// Data
wire		ep80_write;
wire        ep80_ready;
wire		ep80_stb;
wire [15:0]	ep80_data;
wire		epA0_read;
wire		epA0_ready;
wire		epA0_stb;
wire [15:0]	epA0_data;


// Opal Kelly stuff
assign hi_muxsel  = 1'b0;

// Main clock DCM - copied from okLibrary.v
wire dcm_clk1, rstin;
DCM_SP hi_dcm (	.CLKIN     (clk1),
				.CLKFB     (clk),
				.CLK0      (dcm_clk1),
				.PSCLK     (1'b0),
				.PSEN      (1'b0),
				.PSINCDEC  (1'b0),
				.RST       (rstin),
				.DSSEN     (1'b0));
BUFG clk1_buf (.I(dcm_clk1), .O(clk));
// Shift register to implement 4xclk1 reset pulse
SRL16 #(.INIT(16'hF000))
SRL16_inst (.CLK(clk1),.Q(rstin),.D(1'b0),
			.A0(1'b1),.A1(1'b1),.A2(1'b1),.A3(1'b1));


// Physical debug IO
wire [15:0] debug_out;
assign jp1 = {debug_out};
assign led = ~{debug_out[7:0]};

// System wires
wire		clk;

// Opal Kelly host interface wires
wire		rst;
wire		irq;
wire		done;
wire		busy;

// Opal Kelly host interface
assign rst = ep40trig[0];
assign ep21wire = debug_out;
assign ep60trig	= {14'd0, irq,  done};


// Wishbone Master
wire wb_clk_i;
wire wb_rst_i;
wire wb_ack_i;
wire wb_int_i;
wire wb_cyc_o;
wire wb_stb_o;
wire wb_we_o;
wire [1:0] wb_sel_o;
wire [2:0] wb_cti_o;
wire [15:0] wb_data_i;
wire [15:0] wb_data_o;
wire [4:0] wb_addr_o;

assign wb_clk_i = ti_clk;
assign wb_rst_i = rst;

ok2wbm inst_ok2wbm(
	.debug_out(),
	.wb_clk_i(wb_clk_i), .wb_rst_i(wb_rst_i),
	.wb_ack_i(wb_ack_i), .wb_int_i(wb_int_i),
	.wb_cyc_o(wb_cyc_o), .wb_stb_o(wb_stb_o), .wb_we_o(wb_we_o),
	.wb_addr_o(wb_addr_o), .wb_data_o(wb_data_o), .wb_data_i(wb_data_i),
	.wb_sel_o(wb_sel_o), .wb_cti_o(wb_cti_o),
	
	.trg_irq(irq), .trg_done(done),  .busy(busy),
	
	.trg_sngl_rd(ep40trig[1]), .trg_sngl_wr(ep40trig[2]),
	.trg_brst_rd(epA0_stb), .trg_brst_wr(ep80_stb), .brst_rd(epA0_read), .brst_wr(ep80_write),
	
	.addr_in(ep00wire), 
	.sngl_data_in(ep01wire), .sngl_data_out(ep20wire),
	.brst_data_in(ep80_data), .brst_data_out(epA0_data)
);


// Wishbone Slave Register Map
wb_regmap inst_regmap(
	.wb_clk_i(wb_clk_i), .wb_rst_i(wb_rst_i),
	.wb_adr_i(wb_addr_o), .wb_dat_i(wb_data_o), .wb_dat_o(wb_data_i),
	.wb_sel_i(wb_sel_o), .wb_cti_i(wb_cti_o),
	.wb_we_i(wb_we_o), .wb_stb_i(wb_stb_o), .wb_cyc_i(wb_cyc_o), .wb_ack_o(wb_ack_i),
	.wb_err_o(), .wb_int_o(wb_int_i),
	.debug_out(debug_out)
);
	
// Instantiate the okHost and connect endpoints.
wire [17*5-1:0]  ok2x;

okHost okHI(
	.hi_in(hi_in), .hi_out(hi_out), .hi_inout(hi_inout), .hi_aa(hi_aa), .ti_clk(ti_clk),
	.ok1(ok1), .ok2(ok2));

okWireOR # (.N(5)) wireOR (ok2, ok2x);

okWireIn     ep00(.ok1(ok1),                           .ep_addr(8'h00), .ep_dataout(ep00wire));
okWireIn     ep01(.ok1(ok1),                           .ep_addr(8'h01), .ep_dataout(ep01wire));
okWireOut    wo20(.ok1(ok1), .ok2(ok2x[ 0*17 +: 17 ]), .ep_addr(8'h20), .ep_datain(ep20wire));
okWireOut    wo21(.ok1(ok1), .ok2(ok2x[ 1*17 +: 17 ]), .ep_addr(8'h21), .ep_datain(ep21wire));
okTriggerIn  ti40(.ok1(ok1),                           .ep_addr(8'h40), .ep_clk(wb_clk_i), .ep_trigger(ep40trig));
okTriggerOut to60(.ok1(ok1), .ok2(ok2x[ 2*17 +: 17 ]), .ep_addr(8'h60), .ep_clk(wb_clk_i), .ep_trigger(ep60trig));
okBTPipeIn   ep80(.ok1(ok1), .ok2(ok2x[ 3*17 +: 17 ]), .ep_addr(8'h80), .ep_write(ep80_write), .ep_dataout(ep80_data), .ep_blockstrobe(ep80_stb), .ep_ready(~busy));
okBTPipeOut  epA0(.ok1(ok1), .ok2(ok2x[ 4*17 +: 17 ]), .ep_addr(8'hA0), .ep_read(epA0_read),   .ep_datain(epA0_data),  .ep_blockstrobe(epA0_stb), .ep_ready(~busy));
endmodule
