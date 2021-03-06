// ***************************************************************************
// ***************************************************************************
// Copyright 2013(c) Analog Devices, Inc.
//  Author: Lars-Peter Clausen <lars@metafoo.de>
// 
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//     - Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     - Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in
//       the documentation and/or other materials provided with the
//       distribution.
//     - Neither the name of Analog Devices, Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//     - The use of this software may or may not infringe the patent rights
//       of one or more patent holders.  This license does not release you
//       from the requirement that you obtain separate licenses from these
//       patent holders to use this software.
//     - Use of the software either in source or binary form, must be run
//       on or directly connected to an Analog Devices Inc. component.
//    
// THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED.
//
// IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, INTELLECTUAL PROPERTY
// RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ***************************************************************************
// ***************************************************************************

module dmac_dest_axi_stream (
	input s_axis_aclk,
	input s_axis_aresetn,

	input enable,
	output enabled,
	input sync_id,
	output sync_id_ret,
        output xfer_req,

	input [ID_WIDTH-1:0] request_id,
	output [ID_WIDTH-1:0] response_id,
	output [ID_WIDTH-1:0] data_id,
	input data_eot,
	input response_eot,

	input m_axis_ready,
	output m_axis_valid,
	output [S_AXIS_DATA_WIDTH-1:0] m_axis_data,
        output m_axis_last,

	output fifo_ready,
	input fifo_valid,
	input [S_AXIS_DATA_WIDTH-1:0] fifo_data,

	input req_valid,
	output req_ready,
	input [BEATS_PER_BURST_WIDTH-1:0] req_last_burst_length,
        input req_xlast,

	output response_valid,
	input response_ready,
	output response_resp_eot,
	output [1:0] response_resp
);

parameter ID_WIDTH = 3;
parameter S_AXIS_DATA_WIDTH = 64;
parameter BEATS_PER_BURST_WIDTH = 4;

reg req_xlast_d = 1'b0;

assign sync_id_ret = sync_id;
wire data_enabled;
wire _fifo_ready;
wire m_axis_last_s;

// We are not allowed to just de-assert valid, but if the streaming target does
// not accept any samples anymore we'd lock up the DMA core. So retain the last
// beat when disabled until it is accepted. But if in the meantime the DMA core
// is re-enabled and new data becomes available overwrite the old.

always @(posedge s_axis_aclk) begin
  if(req_ready == 1'b1) begin
    req_xlast_d <= req_xlast;
  end
end

assign m_axis_last = (req_xlast_d == 1'b1) ? m_axis_last_s : 1'b0;

dmac_data_mover # (
	.ID_WIDTH(ID_WIDTH),
	.DATA_WIDTH(S_AXIS_DATA_WIDTH),
	.BEATS_PER_BURST_WIDTH(BEATS_PER_BURST_WIDTH),
	.DISABLE_WAIT_FOR_ID(0)
) i_data_mover (
	.clk(s_axis_aclk),
	.resetn(s_axis_aresetn),

	.enable(enable),
	.enabled(data_enabled),
	.sync_id(sync_id),
        .xfer_req(xfer_req),

	.request_id(request_id),
	.response_id(data_id),
	.eot(data_eot),

	.req_valid(req_valid),
	.req_ready(req_ready),
	.req_last_burst_length(req_last_burst_length),

	.m_axi_ready(m_axis_ready),
	.m_axi_valid(m_axis_valid),
	.m_axi_data(m_axis_data),
        .m_axi_last(m_axis_last_s),
	.s_axi_ready(_fifo_ready),
	.s_axi_valid(fifo_valid),
	.s_axi_data(fifo_data)
);

dmac_response_generator # (
	.ID_WIDTH(ID_WIDTH)
) i_response_generator (
	.clk(s_axis_aclk),
	.resetn(s_axis_aresetn),

	.enable(data_enabled),
	.enabled(enabled),
	.sync_id(sync_id),

	.request_id(data_id),
	.response_id(response_id),

	.eot(response_eot),

	.resp_valid(response_valid),
	.resp_ready(response_ready),
	.resp_eot(response_resp_eot),
	.resp_resp(response_resp)
);

assign fifo_ready = _fifo_ready | ~enabled;

endmodule
