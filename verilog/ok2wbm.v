module ok2wbm(
		// Wishbone master interface
		input  wire wb_clk_i,
		input  wire wb_rst_i,
		input  wire wb_ack_i,
		input  wire wb_int_i,
		output reg  wb_cyc_o,
		output reg  wb_stb_o,
		output reg  wb_we_o,
		input  wire [15:0] wb_data_i,
		output reg  [15:0] wb_data_o,
		output wire [4:0] wb_addr_o,
		output wire [1:0] wb_sel_o,
		output reg  [2:0] wb_cti_o,
		// Status triggers and signals
		output wire trg_irq,
		output wire trg_done,
		output wire busy,
		// Transaction triggers and signals
		input  wire trg_sngl_rd,
		input  wire trg_sngl_wr,
		input  wire trg_brst_rd,
		input  wire trg_brst_wr,
		input  wire brst_rd,
		input  wire brst_wr,
		// Address
		input  wire [15:0] addr_in,		
		// Single transaction data ports
		input  wire [15:0] sngl_data_in,
		output reg  [15:0] sngl_data_out,
		// Burst transaction data ports
		input  wire [15:0] brst_data_in,
		output wire [15:0] brst_data_out,
		// Debug
		output wire [15:0] debug_out
	);
	
// DEBUG!
assign debug_out = sngl_data_out;
	
// May need to change in future - for now everything is 16bit wide
assign wb_sel_o = 2'b11;

// Start of Transaction (SOT) - both single and burst mdoes
wire sot;
assign sot = trg_sngl_rd | trg_sngl_wr | trg_brst_rd | trg_delay_wr[1];

// End of Transaction (EOT) - burst mode only
wire eot;
assign eot = wb_stb_o & ((wb_we_o & ~brst_wr) | (rd_burst_live & ~brst_rd));

// Delay the write trigger to get data to align with Opal Kelly BT Pipe
reg [1:0] trg_delay_wr;
always @(posedge wb_clk_i) begin
	trg_delay_wr <= {trg_delay_wr[0], trg_brst_wr};
end

// Detect burst mode
reg rd_burst_live;
reg wr_burst_live;
always @(posedge wb_clk_i) begin
	// Set by burst triggers or itself. Cleared by EOT or reset
	rd_burst_live <= (trg_brst_rd | rd_burst_live) & ~(eot | wb_rst_i);
	wr_burst_live <= (trg_delay_wr[1] | wr_burst_live) & ~(eot | wb_rst_i);
end

// Denote when the system is using burst-mode functionality
wire burst_mode;
assign burst_mode = rd_burst_live | wr_burst_live;

// End of Transation - both modes
assign trg_done = (wb_ack_i & ~burst_mode) | eot;

// Transaction type identification
always @(burst_mode or eot) begin
	if (burst_mode & ~eot)
		wb_cti_o = 3'b001;	// Constant address
	else if (burst_mode & eot)
		wb_cti_o = 3'b111;	// Last transaction of burst
	else
		wb_cti_o = 3'b000;	// Classic transaction type
end

// Frame transaction
always @(posedge wb_clk_i) begin
	// Set by SOT or itself, cleared by trg_done or RST
	wb_cyc_o <=  (sot | wb_cyc_o) & ~(trg_done | wb_rst_i);
	wb_stb_o <=  (sot | wb_stb_o) & ~(trg_done | wb_rst_i);
end
assign busy = wb_cyc_o;

// Put one clock delay on incoming data to align with WB control signals
always @(posedge wb_clk_i) begin
	if (burst_mode)
		wb_data_o <= brst_data_in;
	else
		wb_data_o <= sngl_data_in;
end

// Straight pass-throughs
assign wb_addr_o = addr_in[4:0];
assign irq = wb_int_i;
assign brst_data_out = wb_data_i;

// Read handling
always @(posedge wb_clk_i) begin
	// Latch on ACK - qualify with STB and CYC
	if (wb_ack_i &&  wb_stb_o && wb_cyc_o)
		sngl_data_out <= wb_data_i;
	else
		sngl_data_out <= sngl_data_out; // Explicit latch
end

// Write enable
always @(posedge wb_clk_i) begin
	// Set by single write, write burst live, or itself; cleared by trg_done or RST
	wb_we_o <= (trg_sngl_wr | wr_burst_live | wb_we_o) & ~(trg_done | wb_rst_i);
end
  
endmodule
