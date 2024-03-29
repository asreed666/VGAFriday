module vga_controller(iRST_n,
                      iVGA_CLK,
                      oBLANK_n,
                      oHS,
                      oVS,
                      oVGA_B,
                      oVGA_G,
                      oVGA_R);
input iRST_n;
input iVGA_CLK;
output reg oBLANK_n;
output reg oHS;
output reg oVS;
output [3:0] oVGA_B;
output [3:0] oVGA_G;  
output [3:0] oVGA_R;                       
///////// ////                     
reg [18:0] ADDR ;
wire VGA_CLK_n;
wire [7:0] index;
wire [23:0] bgr_data_raw;
wire cBLANK_n,cHS,cVS,rst;
wire [10:0] xPos;
wire [9:0] yPos;
reg [10:0] ballX = 0;
reg [9:0] ballY = 0;
integer ballXspeed = 4;
integer ballYspeed = 4;
integer ballSpeed = 4;
reg [9:0] plyr1PaddleY = 100;
reg [10:0] plyr1PaddleX = 10;
reg [9:0] plyr2PaddleY = 100;
reg [10:0] plyr2PaddleX = VIDEO_W - 20;
integer paddleWidth = 10;
integer paddleHeight = 40;
reg [11:0] charAddr;
reg [7:0] charData;
wire char_nWr;
//`define INCLUSIVE


////
assign rst = ~iRST_n;

video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                              .reset(rst),
                              .blank_n(cBLANK_n),
                              .HS(cHS),
                              .VS(cVS),
										.xPos(xPos),
										.yPos(yPos)
										);
txtScreen txtScreen(
      .hp(xPos),
		.vp(yPos),
		.addr(charAddr),
		.data(charData),
		.nWr (char_nWr),
      .pClk(iVGA_CLK),
		.nblnk(cBLANK_n),
		.pix(textRGB)
      );


////Addresss generator
always@(posedge iVGA_CLK,negedge iRST_n)
begin
  if (!iRST_n)
     ADDR<=19'd0;
  else if (cBLANK_n==1'b1)
     ADDR<=ADDR+1;
	  else
	    ADDR<=19'd0;
end
										
reg [23:0] bgr_data;

parameter VIDEO_W	= 640;
parameter VIDEO_H	= 480;

always@(posedge iVGA_CLK)
begin
  if (~iRST_n)
  begin
     bgr_data<=24'h000000;
  end
    else
    begin  
	   // This block draws stuff on the display
		if ((xPos >= plyr1PaddleX) && (xPos < plyr1PaddleX + paddleWidth) &&
				(yPos >= plyr1PaddleY) && (yPos < plyr1PaddleY + paddleHeight))
`ifdef INCLUSIVE
			if (yPos%paddleHeight < paddleHeight/5)
				bgr_data<= 24'h0000ff; // Red
			else if (yPos%paddleHeight < 2*paddleHeight/5)
				bgr_data<= 24'h00ff00; // Green
			else if (yPos%paddleHeight < 3*paddleHeight/5)
				bgr_data<= 24'h00ffff; // Cyan
			else if (yPos%paddleHeight < 4*paddleHeight/5)
				bgr_data<= 24'hff0000; // Blue
			else
				bgr_data<= 24'hff00ff; // Magenta
`else
			bgr_data<= 24'hff00ff;
`endif
		else if ((xPos >= plyr2PaddleX) && (xPos < plyr2PaddleX + paddleWidth) &&
				(yPos >= plyr2PaddleY) && (yPos < plyr2PaddleY + paddleHeight))
			bgr_data<=24'hffff00;
		// green Top line
		else if ((yPos >= 90) && (yPos < 95)) bgr_data <= {8'h00,8'hff, 8'h00};  
		// green bottom line
      else if ((yPos >= VIDEO_H - 15) && (yPos < VIDEO_H  - 10)) bgr_data <= {8'h00,8'hff, 8'h00};
		// the net
		else if ((yPos > 92) && (yPos < VIDEO_H - 15) && // vertical position
					(xPos > VIDEO_W/2 - 2)  && (xPos < VIDEO_W/2 + 2) && // horizontal position
					(yPos % 22 < 11)) // dashed line
			bgr_data <= {8'hcc,8'hcc, 8'hcc};
		// The ball
		else if ((xPos >= ballX) && (xPos < ballX + 5) && (yPos >= ballY) && (yPos < ballY + 5))
			bgr_data <= 24'hffffff;
		else if (textRGB == 1'b1) bgr_data = {8'h00, 8'hcc, 8'hcc}; // yellow text
		// default to black
		else bgr_data <= 24'h0000; 
		
 
    end
end

always @(posedge cVS)
begin

	
	// horizontal bounce
	if (ballX > VIDEO_W - 11'd10) ballXspeed = - ballSpeed;
	else if (ballX < 11'd10) ballXspeed = ballSpeed;

	// vertical bounce
	if (ballY > VIDEO_H - 10'd25) ballYspeed = - ballSpeed;
	else if (ballY < 10'd100) ballYspeed = ballSpeed;
	
	// bouncing off player 1 paddle
	else if ((ballX > plyr1PaddleX) && (ballX < plyr1PaddleX + paddleWidth) && 
		(ballY > plyr1PaddleY) && (ballY < plyr1PaddleY + paddleHeight))
		begin
			ballXspeed = ballSpeed;
			ballX <= ballX + paddleWidth;
		end
	// bouncing off player 2 paddle
	else if ((ballX > plyr2PaddleX) && (ballX < plyr2PaddleX + paddleWidth) && 
		(ballY > plyr2PaddleY) && (ballY < plyr2PaddleY + paddleHeight))
		begin
			ballXspeed = - ballSpeed;
			ballX <= ballX - ballXspeed - paddleWidth;
		end
	else
		ballX <= ballX + ballXspeed;
		ballY <= ballY + ballYspeed;
		plyr1PaddleY <= ballY - paddleHeight/2;
		plyr2PaddleY <= ballY - paddleHeight/2;
	
end

assign oVGA_B=bgr_data[23:20];
assign oVGA_G=bgr_data[15:12]; 
assign oVGA_R=bgr_data[7:4];
///////////////////
//////Delay the iHD, iVD,iDEN for one clock cycle;
reg mHS, mVS, mBLANK_n;
always@(posedge iVGA_CLK)
begin
  mHS<=cHS;
  mVS<=cVS;
  mBLANK_n<=cBLANK_n;
  oHS<=mHS;
  oVS<=mVS;
  oBLANK_n<=mBLANK_n;
end


////for signaltap ii/////////////
reg [18:0] H_Cont/*synthesis noprune*/;
always@(posedge iVGA_CLK,negedge iRST_n)
begin
  if (!iRST_n)
     H_Cont<=19'd0;
  else if (mHS==1'b1)
     H_Cont<=H_Cont+1;
	  else
	    H_Cont<=19'd0;
end
endmodule
 	
















