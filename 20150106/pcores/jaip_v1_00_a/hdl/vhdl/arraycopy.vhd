------------------------------------------------------------------------------
-- Filename	:	arraycopy.vhd
-- Version	:	1.00
-- Author	:	Chia-Che Hsu
-- Date		:	Jan. 2013
-- VHDL Standard:	VHDL'93
-- Describe	:	
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2012. All rights reserved.							**		
-- ** Multimedia Embedded System Lab, NCTU.								**  
-- ** Department of Computer Science and Information engineering			**
-- ** National Chiao Tung University, Hsinchu 300, Taiwan				**
-- ***************************************************************************
--
----------------------------------Modified------------------------------------
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.config.all;

entity arraycopy is
	generic(
			C_MST_AWIDTH				: integer			:= 32;
			C_MST_DWIDTH				: integer			:= 32;
			MAX_BURSTS					: integer			:= 16
	);
	port (
			Clk									: in  std_logic;
			Rst										: in  std_logic;
			
			-- PLB MST BURST ports --
			AC_IP2Bus_MstRd_Req			: out std_logic;
			AC_IP2Bus_MstWr_Req			: out std_logic;
			AC_IP2Bus_Mst_Addr				: out std_logic_vector(C_MST_AWIDTH-1 downto 0);
			AC_IP2Bus_Mst_BE				: out std_logic_vector(C_MST_DWIDTH/8-1 downto 0);
			AC_IP2Bus_Mst_Length			: out std_logic_vector(11 downto 0);
			AC_Bus2IP_MstRd_d				: in  std_logic_vector(0 to C_MST_DWIDTH-1);
			AC_IP2Bus_MstWr_d				: out std_logic_vector(0 to C_MST_DWIDTH-1);
			AC_IP2Bus_Mst_Type				: out std_logic;
			AC_Bus2IP_Mst_CmdAck			: in  std_logic;
			AC_Bus2IP_Mst_Cmplt			: in  std_logic;
			AC_Bus2IP_MstRd_sof_n			: in  std_logic;
			AC_Bus2IP_MstRd_eof_n			: in  std_logic;
			AC_Bus2IP_MstRd_src_rdy_n		: in  std_logic;
			AC_IP2Bus_MstRd_dst_rdy_n		: out std_logic;
			AC_IP2Bus_MstRd_dst_dsc_n		: out std_logic;
			AC_IP2Bus_MstWr_sof_n			: out std_logic;
			AC_IP2Bus_MstWr_eof_n			: out std_logic;
			AC_IP2Bus_MstWr_src_rdy_n		: out std_logic;
			AC_IP2Bus_MstWr_src_dsc_n		: out std_logic;	
			AC_Bus2IP_MstWr_dst_rdy_n		: in  std_logic;
			AC_Bus2IP_MstWr_dst_dsc_n		: in  std_logic;
			
			-- native HW
			xcptn_thrown_Native_HW			: out  std_logic;
			Native_HW_thrown_ID				: out  std_logic_vector(15 downto 0);	
			
			CTRL_state						: in DynamicResolution_SM_TYPE;
			-- args & ctrl ports --
			ACEn								: in std_logic;
			ACCmplt								: out std_logic;
			
			src									: in std_logic_vector(31 downto 0);
			srcPos								: in std_logic_vector(31 downto 0);
			dst									: in std_logic_vector(31 downto 0);
			dstPos								: in std_logic_vector(31 downto 0);	
			cpyLength							: in std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of arraycopy is 

	-- register for args 
	signal src_reg								: std_logic_vector(31 downto 0);
	signal srcPos_reg							: std_logic_vector(31 downto 0);
	signal dst_reg								: std_logic_vector(31 downto 0);
	signal dstPos_reg							: std_logic_vector(31 downto 0);	
	signal cpyLength_reg						: std_logic_vector(31 downto 0);
	
	-- common
	signal logElementSize							: std_logic_vector(1 downto 0);
	signal cpySize								: std_logic_vector (11 downto 0);
	signal srcEnd_addr							: std_logic_vector(31 downto 0);
	signal dstEnd_addr							: std_logic_vector(31 downto 0);
	signal SingleOrBurst						: std_logic;
	signal srcStartAddr								: std_logic_vector(31 downto 0);
	signal dstStart								: std_logic_vector(31 downto 0);
	
	-- array buffer
	TYPE   charAryType is array (127 downto 0) of	std_logic_vector(7 downto 0);
	signal charAryBuf							: charAryType;
	signal SP									: integer; 			-- buffer start pointer
	signal EP									: integer;			-- buffer end pointer
	signal aryBufLen							: integer;
	signal aryBufLen_SLV						: std_logic_vector(6 downto 0);
	signal aryBufBE								: std_logic_vector(3 downto 0);
	signal aryBufBE_L							: std_logic_vector(3 downto 0);
	signal aryBufBE_U							: std_logic_vector(3 downto 0);
	signal bufWrEn								: std_logic;
	signal bufRdEn								: std_logic;
	signal bufInit								: std_logic;
	
	-- the main controller of AC
	type   ACType is (idle, srcInfo_req, wait_srcInfo, dstInfo_req, wait_dstInfo, copy);
	signal ACSM							: ACType;
	signal next_ACSM					: ACType;
	signal ACSM_Rd_req					: std_logic;
	signal ACSM_Addr					: std_logic_vector(31 downto 0);
	signal ACSM_Len						: std_logic_vector(11 downto 0);
	signal srcInfoRd					: std_logic;
	signal dstInfoRd					: std_logic;
	signal InfoType						: std_logic;										-- '0' indicating it is waiting for array type, '1' indicating it is waiting for array length
	signal srcType						: std_logic_vector(7 downto 0);
	signal srcLength					: std_logic_vector(11 downto 0);
	signal dstType						: std_logic_vector(7 downto 0);
	signal dstLength					: std_logic_vector(11 downto 0);
	signal NullPointerException			: std_logic;
	signal ArrayStoreException			: std_logic;
	signal ArrayIndexOutOfBoundsException : std_logic;
	signal srcEnd						: std_logic_vector(31 downto 0);
	signal dstEnd						: std_logic_vector(31 downto 0);
	signal xcptn_thrown_Native_HW_reg	: std_logic;
	signal Native_HW_thrown_ID_reg		: std_logic_vector(15 downto 0);
	
	-- AC reader
	type   ACReaderType is(idle, fixedLenRd, variableLenRd, waitWriter);
	signal readerSM								: ACReaderType;
	signal next_readerSM						: ACReaderType;
	signal ACRdRemBytes							: std_logic_vector(11 downto 0);			-- remainder length
	signal readerBurstCmplt						: std_logic;								-- raised when one burst of read operation is finished		
	signal reader_Rd_req						: std_logic;
	signal next_reader_Addr						: std_logic_vector(31 downto 0);			-- src address for each burst	
	signal reader_Addr_reg						: std_logic_vector(31 downto 0);			-- src address for each burst
	signal reader_Len							: std_logic_vector(11 downto 0);
	signal reader_Len_reg						: std_logic_vector(11 downto 0);
	signal isReading							: std_logic;
	signal roundedRdRemBytes					: std_logic_vector(11 downto 0);
	signal VeryFirstRdBurst					: std_logic;
	signal VeryLastRdBurst					: std_logic;
	
	-- AC writer
	type   ACWriterType is(idle, waitReader, fixedLenWr, variableLenWr_U, variableLenWr_L, singleModeWr_U, singleModeWr_L);
	signal writerSM								: ACWriterType;
	signal next_writerSM						: ACWriterType;
	signal ACWrRemBytes							: std_logic_vector(11 downto 0);			-- remainder length
	signal writerBurstCmplt						: std_logic;								-- raised when one burst of write operation is finished
	signal writer_Wr_req						: std_logic;								
	signal next_writer_Addr						: std_logic_vector(31 downto 0);
	signal writer_Addr_reg						: std_logic_vector(31 downto 0);			-- dst address for each burst
	signal writer_Len							: std_logic_vector(11 downto 0);
	signal writer_Len_reg						: std_logic_vector(11 downto 0);
	signal next_writer_Len						: std_logic_vector(11 downto 0);
	signal isWriting							: std_logic;
	signal writeBE								: std_logic_vector(3 downto 0);
	signal writeBE_L							: std_logic_vector(3 downto 0);
	signal writeBE_U							: std_logic_vector(3 downto 0);
	signal validWr								: std_logic;
	signal VeryLastWrBurst					: std_logic;
	
	-- PLB CMD CTRL
	type   PBL_CMD_SM_TYPE is (idle, wait_ack, wait_data);
	signal PLB_CMD_SM							: PBL_CMD_SM_TYPE;
	signal NEXT_PLB_CMD_SM						: PBL_CMD_SM_TYPE;
	signal ACstart						: std_logic;
	signal wr_sof								: std_logic;
	signal wr_eof								: std_logic;
	signal thisBurstWrBytes							: std_logic_vector(11 downto 0); 
	
begin

	AC_IP2Bus_MstRd_Req <= ACSM_Rd_req or reader_Rd_req;
	AC_IP2Bus_MstWr_Req <= writer_Wr_req;
	AC_IP2Bus_Mst_Addr <= ACSM_Addr	when(srcInfoRd = '1' or dstInfoRd = '1') else
						reader_Addr_reg when(isReading = '1')else
						writer_Addr_reg when(isWriting = '1') else
						(others => '0');
	AC_IP2Bus_Mst_BE <= writeBE when(isWriting = '1') else
						"1111";
	AC_IP2Bus_Mst_Length <= ACSM_Len	when(srcInfoRd = '1' or dstInfoRd = '1') else
							reader_Len   when (isReading = '1') else
							writer_Len   when (isWriting = '1') else
							(others => '0');
	AC_IP2Bus_Mst_Type <= SingleOrBurst;
	AC_IP2Bus_MstRd_dst_rdy_n <= '0' when(srcInfoRd = '1' or dstInfoRd = '1') else
								'0' when(isReading = '1') else
								'1';
	AC_IP2Bus_MstRd_dst_dsc_n <= '1';
	AC_IP2Bus_MstWr_sof_n <= wr_sof;
	wr_sof <= '0' when (thisBurstWrBytes = x"000" and PLB_CMD_SM /= idle and isWriting = '1' and SingleOrBurst = '1') else
			'0' when (PLB_CMD_SM /= idle and isWriting = '1' and SingleOrBurst = '0') else
			'1';
	AC_IP2Bus_MstWr_eof_n <= wr_eof;
	wr_eof <= '0' when (thisBurstWrBytes = writer_Len_reg - 4 and PLB_CMD_SM /= idle and isWriting = '1' and SingleOrBurst = '1') else
			'0' when (PLB_CMD_SM /= idle and isWriting = '1' and SingleOrBurst = '0') else
			'1';
	AC_IP2Bus_MstWr_src_rdy_n <= '0' when(isWriting = '1' and PLB_CMD_SM /= idle) else
								'1';
	AC_IP2Bus_MstWr_src_dsc_n <= '1';
	AC_IP2Bus_MstWr_d <= x"000000" & charAryBuf(SP MOD 128) when (writerSM = singleModeWr_U and dstStart(1 downto 0 ) = "11") else
						x"0000" & charAryBuf(SP MOD 128) & charAryBuf((SP + 1) MOD 128) when (writerSM = singleModeWr_U and dstStart(1 downto 0 ) = "10") else
						x"00" & charAryBuf(SP MOD 128) & charAryBuf((SP + 1) MOD 128) & charAryBuf((SP + 2) MOD 128) when(writerSM = singleModeWr_U and dstStart(1 downto 0 ) = "01") else
						charAryBuf(SP MOD 128) & charAryBuf((SP + 1) MOD 128) & charAryBuf((SP + 2) MOD 128) & charAryBuf((SP + 3) MOD 128);
	
	xcptn_thrown_Native_HW <= xcptn_thrown_Native_HW_reg when(CTRL_state = Normal) else
							'0';
	Native_HW_thrown_ID <= Native_HW_thrown_ID_reg when(CTRL_state = Normal) else
						(others => '0');
	NullPointerException <= '1' when ((src = x"00000000" or dst = x"00000000") and ACEn = '1') else
							'0';					
	ArrayStoreException <= '1' when ((srcType /= dstType) and ACSM = wait_dstInfo and AC_Bus2IP_Mst_Cmplt = '1') else
						'0';
	ArrayIndexOutOfBoundsException <= '1' when ((srcPos_reg(31) = '1' or dstPos_reg(31) = '1' or cpyLength_reg(31) = '1' or srcEnd(31) = '1' or dstEnd(31) = '1' or srcEnd > srcLength or dstEnd > dstLength) and ACSM = wait_dstInfo and AC_Bus2IP_Mst_Cmplt = '1') else
									'0';
	With srcType(7 downto 0) Select
	logElementSize <= "00" when x"04",				
					"00" when x"05",
					"01" when x"08",
					"01" when x"09",
					"10" when x"0A",
					"11" when x"06",
					"11" when x"07",
					"11" when x"11",
					"01" when others;		
	srcEnd_addr <= srcStartAddr + cpySize - 1;							-- address of the last byte
	dstEnd_addr <= dstStart + cpySize - 1;							-- address of the last byte
	SingleOrBurst <= '1' when (writerSM = fixedLenWr or writerSM = variableLenWr_U or writerSM = variableLenWr_L) else
					'1' when (srcInfoRd = '1' or dstInfoRd = '1') else
					'1' when (isReading = '1') else
					'0';
	
	-- the main controller of AC
	process(Clk, Rst)
	begin
		if(Rst = '1') then
			ACSM <= idle;
		elsif(rising_edge(Clk)) then
			ACSM <= next_ACSM;
		end if;
	end process;
	
	process(ACSM, ACEn, AC_Bus2IP_Mst_Cmplt, readerBurstCmplt, writerBurstCmplt, ACRdRemBytes, ACWrRemBytes, AC_Bus2IP_Mst_CmdAck)
	begin
		case ACSM is			
			when idle =>
				if(ACEn = '1') then
					if(NullPointerException = '1' or cpyLength = x"00000000") then
						next_ACSM <= idle;
					else
						next_ACSM <= srcInfo_req;
					end if;
				else
					next_ACSM <= idle;
				end if;
			
			when srcInfo_req =>
				if(AC_Bus2IP_Mst_CmdAck = '1') then
					next_ACSM <= wait_srcInfo;
				else
					next_ACSM <= srcInfo_req;
				end if;
				
			when wait_srcInfo =>
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					next_ACSM <= dstInfo_req;
				else
					next_ACSM <= wait_srcInfo;
				end if;
			
			when dstInfo_req =>
				if(AC_Bus2IP_Mst_CmdAck = '1') then	
					next_ACSM <= wait_dstInfo;
				else
					next_ACSM <= dstInfo_req;
				end if;
			
			when wait_dstInfo =>
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					if(ArrayStoreException = '1' or ArrayIndexOutOfBoundsException = '1') then
						next_ACSM <= idle;
					else
						next_ACSM <= copy;
					end if;
				else
					next_ACSM <= wait_dstInfo;
				end if;
			
			when copy =>
				if(ACRdRemBytes = x"000" and ACWrRemBytes = x"000" and AC_Bus2IP_Mst_Cmplt = '1') then
					next_ACSM <= idle;
				else
					next_ACSM <= copy;
				end if;
			
			when others =>
				next_ACSM <= idle;
		end case;
	end process;
	srcInfoRd <= '1' when (ACSM = srcInfo_req or ACSM = wait_srcInfo) else
				'0';
	dstInfoRd <= '1' when (ACSM = dstInfo_req or ACSM = wait_dstInfo) else
				'0';
	ACSM_Rd_req <= '1' when (ACSM = srcInfo_req or ACSM = dstInfo_req) else
				'0';
	ACSM_Addr <= src_reg - 8 when (srcInfoRd = '1') else
				dst_reg - 8 when (dstInfoRd = '1') else
				(others => '0');
	ACSM_Len <= x"008";														-- always read 2 word of info. for each array(i.e. the array type and the array length) 
	ACCmplt <= '1' when(ACSM = copy and ACRdRemBytes = x"000" and ACWrRemBytes = x"000" and AC_Bus2IP_Mst_Cmplt = '1') else
			'1' when(NullPointerException = '1' or ArrayStoreException = '1' or ArrayIndexOutOfBoundsException = '1') else
			'1' when(cpyLength = x"00000000" and ACEn = '1') else
			'0';
			
	-- arraycopy reader
	process(Clk, Rst)
	begin
		if(Rst = '1') then
			readerSM <= idle;
		elsif(rising_edge(Clk)) then
			readerSM <= next_readerSM;
		end if;
	end process;
	
	process(ACSM, ACRdRemBytes, AC_Bus2IP_Mst_Cmplt, writerBurstCmplt)
	begin
		case readerSM is
			when idle => 
				if(ACSM = copy and ACRdRemBytes /= x"000") then
					if(ACRdRemBytes < x"040") then
						next_readerSM <= variableLenRd;
					else
						next_readerSM <= fixedLenRd;
					end if;
				else
					next_readerSM <= idle;
				end if;
					
			when fixedLenRd => 
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					if(ACRdRemBytes = x"000") then
						next_readerSM <= idle;
					else
						next_readerSM <= waitWriter;
					end if;
				else
					next_readerSM <= fixedLenRd;
				end if;
				
			when variableLenRd => 
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					next_readerSM <= idle;
				else
					next_readerSM <= variableLenRd;
				end if;
				
			when waitWriter => 	
				if(writerBurstCmplt = '1') then
					if(ACRdRemBytes < x"040") then
						next_readerSM <= variableLenRd;
					else
						next_readerSM <= fixedLenRd;
					end if;
				else
					next_readerSM <= waitWriter;
				end if;
				
			when others =>
				next_readerSM <= idle;
				
		end case;
	end process;
	
	isReading <= '1' when(readerSM = fixedLenRd or readerSM = variableLenRd) else
				'0';
	reader_Len <= reader_Len_reg;		
	readerBurstCmplt <= '1' when(isReading = '1' and AC_Bus2IP_Mst_Cmplt = '1') else
						'0';					
	VeryFirstRdBurst <= '1' when(AC_Bus2IP_MstRd_sof_n = '0' and ACRdRemBytes = cpySize) else
						'0';
	VeryLastRdBurst <= '1' when(AC_Bus2IP_MstRd_eof_n = '0' and ACRdRemBytes = ((x"0000000"&"00"&srcEnd_addr(1 downto 0)) + 1)) else
						'0';
	-- arraycopy writer
	process(Clk, Rst)
	begin
		if(Rst = '1') then
			writerSM <= idle;
		elsif(rising_edge(Clk)) then
			writerSM <= next_writerSM;
		end if;
	end process;
	
	process(writerSM, readerSM, ACWrRemBytes, AC_Bus2IP_Mst_Cmplt, readerBurstCmplt, aryBufLen_SLV)
	begin
		case writerSM is
			when idle =>
				if(readerBurstCmplt = '1') then
					if(dstStart(1 downto 0) = "00") then
						if(aryBufLen_SLV <= x"004") then
							next_writerSM <= singleModeWr_U;
						elsif(aryBufLen_SLV < x"040") then
							next_writerSM <= variableLenWr_U;
						else
							next_writerSM <= fixedLenWr;
						end if;
					else
						next_writerSM <= singleModeWr_U;
					end if;
				else
					next_writerSM <= idle;
				end if;
			when fixedLenWr => 
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					if(ACWrRemBytes = x"000") then
						next_writerSM <= idle;
					else
						next_writerSM <= waitReader;
					end if;	
				else
					next_writerSM <= fixedLenWr;
				end if;
			when variableLenWr_U => 
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					if(ACWrRemBytes = x"000") then
						next_writerSM <= idle;
					elsif(ACWrRemBytes = aryBufLen_SLV) then
						next_writerSM <= singleModeWr_L;
					else
						next_writerSM <= waitReader;
					end if;
				else
					next_writerSM <= variableLenWr_U;
				end if;
			when variableLenWr_L =>
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					if(ACWrRemBytes = x"000") then
						next_writerSM <= idle;
					elsif(ACWrRemBytes = aryBufLen_SLV) then
						next_writerSM <= singleModeWr_L;
					else
						next_writerSM <= waitReader;
					end if;
				else
					next_writerSM <= variableLenWr_L;
				end if;
			when singleModeWr_U =>	
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					if(ACWrRemBytes = x"000") then
						next_writerSM <= idle;
					elsif(aryBufLen_SLV <= x"004") then
						next_writerSM <= singleModeWr_L;
					else
						next_writerSM <= variableLenWr_U;
					end if;
				else
					next_writerSM <= singleModeWr_U;
				end if;
			when singleModeWr_L =>		
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					next_writerSM <= idle;
				else
					next_writerSM <= singleModeWr_L;
				end if;
			when waitReader	=> 
				if(readerBurstCmplt = '1') then
					if(aryBufLen_SLV >= x"040") then
						next_writerSM <= fixedLenWr;
					else
						if(aryBufLen_SLV <= x"004") then
							next_writerSM <= singleModeWr_L;
						else
							next_writerSM <= variableLenWr_L;
						end if;
					end if;
				else
					next_writerSM <= waitReader;
				end if;
			when others =>
				next_writerSM <= idle;
		end case;
	end process;
	
	isWriting <= '1' when(writerSM /= idle and writerSM /= waitReader) else
				'0';
	writer_Len <= (writer_Len_reg(11 downto 2) + (writer_Len_reg(1) or writer_Len_reg(0))) & "00"; -- round up the writing length to multiple of 4
	writerBurstCmplt <= '1' when((aryBufLen_SLV < x"004") and isWriting = '1' and AC_Bus2IP_Mst_Cmplt = '1') else
						'0';
	VeryLastWrBurst <= '1' when(wr_eof = '0' and ACWrRemBytes = ((x"0000000"&"00"&dstEnd_addr(1 downto 0)) + 1)) else
					'0';
	-- PLB Master command controller
	process(Clk, Rst)
	begin
		if(Rst = '1') then
			PLB_CMD_SM <= idle;
		elsif(rising_edge(Clk)) then
			PLB_CMD_SM <= NEXT_PLB_CMD_SM;
		end if;
	end process;
	
	process(PLB_CMD_SM, AC_Bus2IP_Mst_CmdAck, AC_Bus2IP_Mst_Cmplt, ACSM_Rd_req, reader_Rd_req, writer_Wr_req) 
	begin
		case PLB_CMD_SM is
			when idle =>
				if(ACSM_Rd_req = '1' or reader_Rd_req = '1' or writer_Wr_req = '1') then
					NEXT_PLB_CMD_SM <= wait_ack;
				else
					NEXT_PLB_CMD_SM <= idle;
				end if;
			when wait_ack =>
				if(AC_Bus2IP_Mst_CmdAck = '1') then
					NEXT_PLB_CMD_SM <= wait_data;
				else
					NEXT_PLB_CMD_SM <= wait_ack;
				end if;
			when wait_data =>
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					NEXT_PLB_CMD_SM <= idle;
				else
					NEXT_PLB_CMD_SM <= wait_data;
				end if;
			when others =>
				NEXT_PLB_CMD_SM <= idle;
		end case;
	end process;
	
	ACstart <= '1' when(isReading = '1' or isWriting = '1') else
			'0';
	
	-- flip-flops
	process(Clk, Rst) 
	begin
		if(Rst = '1') then
			src_reg <= (others => '0');
			srcPos_reg <= (others => '0');
			dst_reg <= (others => '0');
			dstPos_reg <= (others => '0');
			cpyLength_reg <= (others => '0');
			InfoType <= '0';
			srcType <= (others => '0');
			srcLength <= (others => '0');
			dstType <= (others => '0');
			dstLength <= (others => '0');
			reader_Addr_reg <= (others => '0');
			reader_Len_reg <= (others => '0');
			writer_Addr_reg <= (others => '0');
			writer_Len_reg <= (others => '0');
			ACRdRemBytes <= (others => '0');
			ACWrRemBytes <= (others => '0');
			thisBurstWrBytes <= (others => '0');
		elsif(rising_edge(Clk)) then
			if(ACEn = '1') then
				src_reg <= src;
				srcPos_reg <= srcPOs;
				dst_reg <= dst;
				dstPos_reg <= dstPos;
				cpyLength_reg <= cpyLength;
				cpySize <= SHL(cpyLength(11 downto 0), logElementSize);
			end if;
			
			srcStartAddr <= src_reg + SHL(srcPos_reg , logElementSize);
			dstStart <= dst_reg + SHL(dstPos_reg , logElementSize);
			
			if(AC_Bus2IP_MstRd_src_rdy_n = '0' and PLB_CMD_SM = wait_data) then
				if(srcInfoRd = '1') then
					if(InfoType = '0') then
						srcType <= AC_Bus2IP_MstRd_d(0 to 7);
						InfoType <= '1';
					elsif(InfoType = '1') then
						srcLength <= AC_Bus2IP_MstRd_d(20 to 31);
						InfoType <= '0';
					end if;
				elsif(dstInfoRd = '1') then
					if(InfoType = '0') then
						dstType <= AC_Bus2IP_MstRd_d(0 to 7);
						InfoType <= '1';
					elsif(InfoType = '1') then
						dstLength <= AC_Bus2IP_MstRd_d(20 to 31);
						InfoType <= '0';
					end if;
				end if;
			end if;
			
			if(ACSM = wait_dstInfo and AC_Bus2IP_Mst_Cmplt = '1') then
				ACRdRemBytes <= cpySize;
				ACWrRemBytes <= cpySize;
			elsif(isReading = '1') then
				if(AC_Bus2IP_MstRd_src_rdy_n = '0' and PLB_CMD_SM = wait_data) then
					if(VeryLastRdBurst = '1') then
						ACRdRemBytes <= (others => '0');
					elsif(VeryFirstRdBurst = '1') then
						ACRdRemBytes <= ACRdRemBytes - x"004" + (x"00"&"00"&srcStartAddr(1 downto 0));
					else
						ACRdRemBytes <= ACRdRemBytes - x"004";
					end if;
				end if;	
			elsif(isWriting = '1') then
				if(writerSM = fixedLenWr or writerSM = variableLenWr_U or writerSM = variableLenWr_L) then
					if(validWr = '1') then
						ACWrRemBytes <= ACWrRemBytes - x"004";
					end if;
				elsif(writerSM = singleModeWr_U) then
					if(validWr = '1') then
						if(VeryLastWrBurst = '1') then
							ACWrRemBytes <= (others => '0');
						else
							ACWrRemBytes <= ACWrRemBytes - x"004" + (x"00"&"00"&dstStart(1 downto 0));
						end if;
					end if;
				elsif(writerSM = singleModeWr_L) then
					if(validWr = '1') then
						ACWrRemBytes <= (others => '0');
					end if;
				end if;	
			end if;
			
			if(isReading = '1' and PLB_CMD_SM = idle) then													-- setup args 
				reader_Rd_req <= '1';
				reader_Addr_reg <= next_reader_Addr(31 downto 2)&"00";
				if(readerSM = fixedLenRd) then
					reader_Len_reg <= x"040";
				elsif(readerSM = variableLenRd) then
					if(next_reader_Addr = srcStartAddr) then
						reader_Len_reg <= ACRdRemBytes + (x"00"&"00"&srcStartAddr(1 downto 0)) + (x"003" - (x"00"&"00"&srcEnd_addr(1 downto 0)));
					else
						reader_Len_reg <= roundedRdRemBytes;													-- readerSM = variableLenRd if and only of this is the last burst of read operation					
					end if;
				end if;	
			elsif(AC_Bus2IP_Mst_CmdAck = '1') then
				reader_Rd_req <= '0';
			end if;
			
			if(isWriting = '1' and PLB_CMD_SM = idle) then													-- setup args 
				writer_Wr_req <= '1';
				writer_Addr_reg <= next_writer_Addr(31 downto 2)&"00";
				if(writerSM = fixedLenWr) then
					writer_Len_reg <= x"040";
				elsif(writerSM = singleModeWr_U) then
					writer_Len_reg <= x"004" - dstStart(1 downto 0);											-- ignored by single mode PLB	
				elsif(writerSM = variableLenWr_U) then
					writer_Len_reg <= "00000" & aryBufLen_SLV(6 downto 2) & "00";	
				elsif(writerSM = variableLenWr_L) then
					writer_Len_reg <= "00000" & aryBufLen_SLV(6 downto 2) & "00";	
				elsif(writerSM = singleModeWr_L) then
					writer_Len_reg <= "00000" & aryBufLen_SLV;												-- ignored by single mode PLB	
				end if;
			elsif(AC_Bus2IP_Mst_CmdAck = '1') then
				writer_Wr_req <= '0';
			end if;
			
			if(PLB_CMD_SM = idle) then																		-- recording in just one burst	
				thisBurstWrBytes <= x"000";
			elsif(validWr = '1') then
				thisBurstWrBytes <= thisBurstWrBytes + 4;
			end if;
			
			if(NullPointerException = '1') then
				xcptn_thrown_Native_HW_reg	<= '1';
				Native_HW_thrown_ID_reg <= x"000F";
			elsif(ArrayStoreException = '1') then
				xcptn_thrown_Native_HW_reg	<= '1';
				Native_HW_thrown_ID_reg <= x"000E";	
			elsif(ArrayIndexOutOfBoundsException = '1') then	
				xcptn_thrown_Native_HW_reg	<= '1';
				Native_HW_thrown_ID_reg <= x"000C";	
			elsif(CTRL_state = Normal) then
				xcptn_thrown_Native_HW_reg	<= '0';
				Native_HW_thrown_ID_reg <= (others => '0');
			end if;
		end if;
	end process;
	
	srcEnd <= srcPos_reg + cpyLength_reg;
	dstEnd <= dstPos_reg + cpyLength_reg;
	next_reader_Addr <= cpySize - ACRdRemBytes + srcStartAddr;
	roundedRdRemBytes <= (ACRdRemBytes(11 downto 2) + (ACRdRemBytes(1) or ACRdRemBytes(0)))&"00";		-- round up the ACRdRemBytes to multiple of 4 
	next_writer_Addr <= cpySize - ACWrRemBytes + dstStart;
	validWr <= '1' when(AC_Bus2IP_MstWr_dst_rdy_n = '0' and thisBurstWrBytes /= writer_Len and PLB_CMD_SM /= idle) else
			'0';
			
	-- char array buffer
	bufWrEn <= '1' when(AC_Bus2IP_MstRd_src_rdy_n = '0' and PLB_CMD_SM = wait_data and isReading = '1') else
			'0';
	bufRdEn <= '1' when(validWr = '1') else
			'0';
	bufInit <= '1' when(ACen = '1') else
			'0';
	process(Clk, Rst) 
	begin
		if(Rst = '1') then
			charAryBuf <= (others => (others => '0'));
			aryBufLen <= 0;
			SP <= 0;
		elsif(rising_edge(Clk)) then
			if(bufInit = '1') then
				aryBufLen <= 0;
				SP <= 0;
			elsif(bufWrEn = '1') then
				case aryBufBE is
					when "1111" =>
						charAryBuf(EP)	<= AC_Bus2IP_MstRd_d(0 to 7);
						charAryBuf((EP + 1) MOD 128)  <= AC_Bus2IP_MstRd_d(8 to 15);
						charAryBuf((EP + 2) MOD 128) <= AC_Bus2IP_MstRd_d(16 to 23);
						charAryBuf((EP + 3) MOD 128) <= AC_Bus2IP_MstRd_d(24 to 31);
						aryBufLen <= (aryBufLen + 4) MOD 128;
					when "0111" =>
						charAryBuf(EP) 	<= AC_Bus2IP_MstRd_d(8 to 15);
						charAryBuf((EP + 1) MOD 128) <= AC_Bus2IP_MstRd_d(16 to 23);
						charAryBuf((EP + 2) MOD 128) <= AC_Bus2IP_MstRd_d(24 to 31);
						aryBufLen <= (aryBufLen + 3) MOD 128;
					when "0011" =>
						charAryBuf(EP)	<= AC_Bus2IP_MstRd_d(16 to 23);
						charAryBuf((EP + 1) MOD 128) <= AC_Bus2IP_MstRd_d(24 to 31);
						aryBufLen <= (aryBufLen + 2) MOD 128;
					when "0001" =>
						charAryBuf(EP) 	<= AC_Bus2IP_MstRd_d(24 to 31);
						aryBufLen <= (aryBufLen + 1) MOD 128;
					when "1110" =>
						charAryBuf(EP) 	<= AC_Bus2IP_MstRd_d(0 to 7);
						charAryBuf((EP + 1) MOD 128) <= AC_Bus2IP_MstRd_d(8 to 15);
						charAryBuf((EP + 2) MOD 128) <= AC_Bus2IP_MstRd_d(16 to 23);
						aryBufLen <= (aryBufLen + 3) MOD 128;
					when "1100" =>
						charAryBuf(EP)	<= AC_Bus2IP_MstRd_d(0 to 7);
						charAryBuf((EP + 1) MOD 128) <= AC_Bus2IP_MstRd_d(8 to 15);
						aryBufLen <= (aryBufLen + 2) MOD 128;
					when "1000" =>
						charAryBuf(EP)	<= AC_Bus2IP_MstRd_d(0 to 7);
						aryBufLen <= (aryBufLen + 1) MOD 128;
					when others => null;						
				end case;
			elsif(bufRdEn = '1') then
				if(SingleOrBurst = '1') then
					SP <= (SP + 4) MOD 128;
					aryBufLen <= aryBufLen - 4;
				else
					SP <= (SP + CONV_INTEGER(writer_Len_reg)) MOD 128;
					aryBufLen <= aryBufLen - CONV_INTEGER(writer_Len_reg);
				end if;
			end if;
		end if;
	end process;
	
	process(AC_Bus2IP_MstRd_sof_n,  AC_Bus2IP_MstRd_eof_n, srcEnd_addr, aryBufBE_L, aryBufBE_U, dstEnd_addr, writeBE_L, writeBE_U, SingleOrBurst, isWriting, srcStartAddr, ACRdRemBytes, cpySize, dstStart, wr_sof, wr_eof, ACWrRemBytes)
	begin
		if(AC_Bus2IP_MstRd_sof_n = '0' and ACRdRemBytes = cpySize) then	
			case srcStartAddr(1 downto 0) is
				when "00" =>
					aryBufBE_L <= "1111";
				when "01" =>
					aryBufBE_L <= "0111";
				when "10" =>
					aryBufBE_L <= "0011";
				when "11" =>
					aryBufBE_L <= "0001";
				when others =>
					null;
			end case;
		else
			aryBufBE_L <= "1111";
		end if;
		
		if(AC_Bus2IP_MstRd_eof_n = '0' and ACRdRemBytes = ((x"0000000"&"00"&srcEnd_addr(1 downto 0)) + 1)) then
			case srcEnd_addr(1 downto 0) is
				when "00" =>
					aryBufBE_U <= "1000";
				when "01" =>
					aryBufBE_U <= "1100";
				when "10" =>
					aryBufBE_U <= "1110";
				when "11" =>
					aryBufBE_U <= "1111";
				when others =>
					null;
			end case;	
		else
			aryBufBE_U <= "1111";	
		end if;
		
		if(wr_sof = '0' and ACWrRemBytes = cpySize) then	
			case dstStart(1 downto 0) is
				when "00" =>
					writeBE_L <= "1111";
				when "01" =>
					writeBE_L <= "0111";
				when "10" =>
					writeBE_L <= "0011";
				when "11" =>
					writeBE_L <= "0001";
				when others =>
					null;
			end case;
		else
			writeBE_L <= "1111";
		end if;
		
		if(wr_eof = '0' and ACWrRemBytes = ((x"0000000"&"00"&dstEnd_addr(1 downto 0)) + 1)) then
			case dstEnd_addr(1 downto 0) is
				when "00" =>
					writeBE_U <= "1000";
				when "01" =>
					writeBE_U <= "1100";
				when "10" =>
					writeBE_U <= "1110";
				when "11" =>
					writeBE_U <= "1111";
				when others =>
					null;
			end case;	
		else
			writeBE_U <= "1111";	
		end if;
	end process;
	
	aryBufBE <= aryBufBE_L and aryBufBE_U;					-- sof and eof could be raised at same time
	writeBE <= writeBE_L and writeBE_U;
	EP <= (SP + aryBufLen) MOD 128;
	aryBufLen_SLV <= conv_std_logic_vector(aryBufLen, 7);
	
end architecture rtl;

