------------------------------------------------------------------------------
-- Filename     :       arraycopy_single.vhd
-- Version      :       1.00
-- Author       :       Chia-Che Hsu
-- Date         :       Mar. 2013
-- VHDL Standard:       VHDL'93
-- Describe     :       single-mode only hardware arraycopy
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2012. All rights reserved.                              **        
-- ** Multimedia Embedded System Lab, NCTU.                                 **  
-- ** Department of Computer Science and Information engineering            **
-- ** National Chiao Tung University, Hsinchu 300, Taiwan                   **
-- ***************************************************************************
--
----------------------------------Modified------------------------------------
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.config.all;

entity arraycopy_single is
	generic(
			C_MST_AWIDTH                   : integer              := 32;
			C_MST_DWIDTH                   : integer              := 32
	);
	port (
			Clk                 				      : in  std_logic;
			Rst					                  	  : in  std_logic;
			
			-- PLB MST BURST ports --
			AC_IP2Bus_MstRd_Req               : out std_logic;
			AC_IP2Bus_MstWr_Req               : out std_logic;
			AC_IP2Bus_Mst_Addr                : out std_logic_vector(C_MST_AWIDTH-1 downto 0);
			AC_IP2Bus_Mst_BE                  : out std_logic_vector(C_MST_DWIDTH/8-1 downto 0);
			AC_Bus2IP_MstRd_d                 : in  std_logic_vector(0 to C_MST_DWIDTH-1);
			AC_IP2Bus_MstWr_d                 : out std_logic_vector(0 to C_MST_DWIDTH-1);
			AC_Bus2IP_Mst_Cmplt               : in  std_logic;
			
			-- native HW
			xcptn_thrown_Native_HW			  : out  std_logic;
			Native_HW_thrown_ID				  : out  std_logic_vector(15 downto 0);	
			
			CTRL_state			              : in DynamicResolution_SM_TYPE;
			-- args & ctrl ports --
			ACEn					   		      : in std_logic;
			ACCmplt				   		  		  : out std_logic;
			
			src					   		  		  : in std_logic_vector(31 downto 0);
			srcPos						   		  : in std_logic_vector(31 downto 0);
			dst							   		  : in std_logic_vector(31 downto 0);
			dstPos						   		  : in std_logic_vector(31 downto 0);	
			cpyLength                      		  : in std_logic_vector(31 downto 0);
			--cs debug
			debug_readerSM						  : out std_logic_vector(1 downto 0);
			debug_writerSM						  : out std_logic_vector(2 downto 0);
			debug_ACRdRemBytes					  : out std_logic_vector(11 downto 0);
			debug_srcEnd_addr 					  : out std_logic_vector(31 downto 0);
			debug_cpySize 					  	  : out std_logic_vector(11 downto 0);
			debug_NullPointerException 			  : out std_logic;
			debug_ArrayStoreException 			  : out std_logic;
			debug_ArrayIndexOutOfBoundsException  : out std_logic;
			debug_AC_Bus2IP_MstRd_d				  : out std_logic_vector(31 downto 0);
			debug_ACWrRemBytes 					  : out std_logic_vector(11 downto 0);
			debug_next_aryBufLen_SLV 			  : out std_logic_vector(6 downto 0);
			debug_wrSize						  : out std_logic_vector(11 downto 0);
			debug_rdSize 						  : out std_logic_vector(11 downto 0);
			debug_AC_SP							  : out std_logic_Vector(6 downto 0);
			debug_AC_SP_next					  : out std_logic_Vector(6 downto 0)
	);
end entity;

architecture rtl of arraycopy_single is 

	-- register for args 
	signal src_reg					   		  	  : std_logic_vector(31 downto 0);
	signal srcPos_reg						   	  : std_logic_vector(31 downto 0);
	signal dst_reg							   	  : std_logic_vector(31 downto 0);
	signal dstPos_reg						   	  : std_logic_vector(31 downto 0);	
	signal cpyLength_reg                      	  : std_logic_vector(31 downto 0);
	
	-- common
	signal logElementSize							  : std_logic_vector(1 downto 0);
	signal cpySize								  	  : std_logic_vector (11 downto 0);
	signal srcStartAddr								  : std_logic_vector(31 downto 0);
	signal dstStartAddr								  : std_logic_vector(31 downto 0);
	signal srcEndAddr					  			  : std_logic_vector(31 downto 0);
	signal dstEndAddr					  			  : std_logic_vector(31 downto 0);
	
	-- array buffer
	TYPE   charAryType is array (7 downto 0) of    std_logic_vector(7 downto 0);
	signal charAryBuf							  : charAryType;
	signal SP									  : integer; 			-- buffer start pointer
	signal EP									  : integer;			-- buffer end pointer
	signal aryBufLen							  : integer;
	signal aryBufLen_SLV						  : std_logic_vector(6 downto 0);
	signal next_aryBufLen						  : integer;
	signal next_aryBufLen_SLV					  : std_logic_vector(6 downto 0);
	signal aryBufBE								  : std_logic_vector(3 downto 0);
	signal aryBufBE_L							  : std_logic_vector(3 downto 0);
	signal aryBufBE_U							  : std_logic_vector(3 downto 0);
	signal bufWrEn								  : std_logic;
	signal bufRdEn								  : std_logic;
	signal bufInit								  : std_logic;
	
	-- the main controller of AC
	type   ACType is (idle, srcTag_req, srcTag_wait, srcLen_req, srcLen_wait, dstTag_req, dstTag_wait, dstLen_req, dstLen_wait, copy);
	signal ACSM							  : ACType;
	signal next_ACSM					  : ACType;
	signal ACSM_Rd_req					  : std_logic;
	signal ACSM_Addr					  : std_logic_vector(31 downto 0);
	signal ACSM_Addr_reg				  : std_logic_vector(31 downto 0);
	signal srcTagRd						  : std_logic;
	signal dstTagRd						  : std_logic;
	signal srcLenRd						  : std_logic;
	signal dstLenRd						  : std_logic;
	signal InfoType						  : std_logic;										-- '0' indicating it is waiting for array type, '1' indicating it is waiting for array length
	signal srcType						  : std_logic_vector(7 downto 0);
	signal srcLength					  : std_logic_vector(11 downto 0);
	signal dstType						  : std_logic_vector(7 downto 0);
	signal dstLength					  : std_logic_vector(11 downto 0);
	signal NullPointerException			  : std_logic;
	signal ArrayStoreException			  : std_logic;
	signal ArrayIndexOutOfBoundsException : std_logic;
	signal srcEnd						  : std_logic_vector(31 downto 0);
	signal dstEnd						  : std_logic_vector(31 downto 0);
	signal xcptn_thrown_Native_HW_reg	  : std_logic;
	signal Native_HW_thrown_ID_reg		  : std_logic_vector(15 downto 0);
	
	-- AC reader
	type   ACReaderType is(idle, sgnlWordRd_req, sgnlWordRd_wait, waitWriter);
	signal readerSM								  : ACReaderType;
	signal next_readerSM						  : ACReaderType;
	signal ACRdRemBytes						      : std_logic_vector(11 downto 0);			-- remainder length
	signal readerBurstCmplt						  : std_logic;								-- raised when one burst of read operation is finished		
	signal reader_Rd_req						  : std_logic;
	signal next_reader_Addr						  : std_logic_vector(31 downto 0);			-- src address for each burst	
	signal reader_Addr_reg						  : std_logic_vector(31 downto 0);			-- src address for each burst
	signal isReading							  : std_logic;
	signal rdSize								  : std_logic_vector(11 downto 0);
	signal reader_Rd_req_reg					  : std_logic;
	
	-- AC writer
	type   ACWriterType is(idle, sgnlWordWr_req, sgnlWordWr_wait, waitReader);
	signal writerSM								  : ACWriterType;
	signal next_writerSM						  : ACWriterType;
	signal ACWrRemBytes							  : std_logic_vector(11 downto 0);			-- remainder length
	signal writerBurstCmplt						  : std_logic;								-- raised when one burst of write operation is finished
	signal writer_Wr_req						  : std_logic;								
	signal next_writer_Addr						  : std_logic_vector(31 downto 0);
	signal writer_Addr_reg						  : std_logic_vector(31 downto 0);			-- dst address for each burst
	signal isWriting							  : std_logic;
	signal writeBE								  : std_logic_vector(3 downto 0);
	signal writeBE_L							  : std_logic_vector(3 downto 0);
	signal writeBE_U							  : std_logic_vector(3 downto 0);
	signal wrSize								  : std_logic_vector(11 downto 0);
	signal writer_Wr_req_reg					  : std_logic;
	
begin

	AC_IP2Bus_MstRd_Req <= ACSM_Rd_req or reader_Rd_req;
	AC_IP2Bus_MstWr_Req <= writer_Wr_req;
	AC_IP2Bus_Mst_Addr <= ACSM_Addr       when(srcTagRd = '1' or srcLenRd = '1' or dstTagRd = '1' or dstLenRd = '1') else
						  reader_Addr_reg when(isReading = '1')else
						  writer_Addr_reg when(isWriting = '1') else
						  (others => '0');
	AC_IP2Bus_Mst_BE <= writeBE when(isWriting = '1') else
						"1111";
	AC_IP2Bus_MstWr_d <= x"000000" & charAryBuf(SP MOD 8) when (writer_Addr_reg(31 downto 2) = dstStartAddr(31 downto 2) and dstStartAddr(1 downto 0 ) = "11") else
						 x"0000" & charAryBuf(SP MOD 8) & charAryBuf((SP + 1) MOD 8) when (writer_Addr_reg(31 downto 2) = dstStartAddr(31 downto 2) and dstStartAddr(1 downto 0 ) = "10") else
						 x"00" & charAryBuf(SP MOD 8) & charAryBuf((SP + 1) MOD 8) & charAryBuf((SP + 2) MOD 8) when(writer_Addr_reg(31 downto 2) = dstStartAddr(31 downto 2) and dstStartAddr(1 downto 0 ) = "01") else
						 charAryBuf(SP MOD 8) & charAryBuf((SP + 1) MOD 8) & charAryBuf((SP + 2) MOD 8) & charAryBuf((SP + 3) MOD 8);
	
	xcptn_thrown_Native_HW <= xcptn_thrown_Native_HW_reg when(CTRL_state = Normal) else
							  '0';
	Native_HW_thrown_ID <= Native_HW_thrown_ID_reg when(CTRL_state = Normal) else
						   (others => '0');
	NullPointerException <= '1' when ((src = x"00000000" or dst = x"00000000") and ACEn = '1') else
							'0';					
	ArrayStoreException <= '1' when ((srcType /= AC_Bus2IP_MstRd_d(0 to 7)) and ACSM = dstTag_wait and AC_Bus2IP_Mst_Cmplt = '1') else
						   '0';
	ArrayIndexOutOfBoundsException <= '1' when ((srcPos_reg(31) = '1' or dstPos_reg(31) = '1' or cpyLength_reg(31) = '1' or srcEnd(31) = '1' or dstEnd(31) = '1' or srcEnd > srcLength or dstEnd > AC_Bus2IP_MstRd_d(20 to 31)) and ACSM = dstLen_wait and AC_Bus2IP_Mst_Cmplt = '1') else
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
	
	-- the main controller of AC , arraycopy reader , writer
	process(Clk) begin
                if(rising_edge(Clk)) then
		if(Rst = '1') then
			ACSM <= idle;
			readerSM <= idle;
			writerSM <= idle;
		else
			ACSM <= next_ACSM;
			readerSM <= next_readerSM;
			writerSM <= next_writerSM;
		end if;
		end if;
	end process;
	
        -- original sensitivity list . modified since 2013.6.22
	--process(ACSM, ACEn, AC_Bus2IP_Mst_Cmplt, ACRdRemBytes, ACWrRemBytes, wrSize, NullPointerException,
        --ArrayStoreException, ArrayIndexOutOfBoundsException, cpyLength)begin
	process(ACSM, ACEn, AC_Bus2IP_Mst_Cmplt, ACRdRemBytes, ACWrRemBytes, NullPointerException, 
                        ArrayStoreException, ArrayIndexOutOfBoundsException, cpyLength)
	begin
		case ACSM is			
			when idle =>
				if(ACEn = '1') then
					if(NullPointerException = '1' or cpyLength = x"00000000") then
						next_ACSM <= idle;
					else
						next_ACSM <= srcTag_req;
					end if;
				else
					next_ACSM <= idle;
				end if;
			
			when srcTag_req =>
				next_ACSM <= srcTag_wait;
			
			when srcTag_wait =>
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					next_ACSM <= srcLen_req;
				else
					next_ACSM <= srcTag_wait;
				end if;
				
			when srcLen_req =>
				next_ACSM <= srcLen_wait;
				
			when srcLen_wait =>
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					next_ACSM <= dstTag_req;
				else
					next_ACSM <= srcLen_wait;
				end if;
			
			when dstTag_req =>
				next_ACSM <= dstTag_wait;
			
			when dstTag_wait =>
				if(AC_Bus2IP_Mst_Cmplt = '1') then	
					if(ArrayStoreException = '1') then
						next_ACSM <= idle;
					else
						next_ACSM <= dstLen_req;
					end if;
				else
					next_ACSM <= dstTag_wait;
				end if;
			
			when dstLen_req =>
				next_ACSM <= dstLen_wait;
				
			when dstLen_wait => 			
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					if(ArrayIndexOutOfBoundsException = '1') then
						next_ACSM <= idle;
					else
						next_ACSM <= copy;
					end if;
				else
					next_ACSM <= dstLen_wait;
				end if;
			
			when copy =>
				if(ACRdRemBytes = x"000" and (ACWrRemBytes = x"000") and AC_Bus2IP_Mst_Cmplt = '1') then
					next_ACSM <= idle;
				else
					next_ACSM <= copy;
				end if;
			
			when others =>
				next_ACSM <= idle;
		end case;
	end process;
	srcTagRd <= '1' when (ACSM = srcTag_req or ACSM = srcTag_wait) else
				'0';
	srcLenRd <= '1' when (ACSM = srcLen_req or ACSM = srcLen_wait) else
				'0';
	dstTagRd <= '1' when (ACSM = dstTag_req or ACSM = dstTag_wait) else
				'0';
	dstLenRd <= '1' when (ACSM = dstLen_req or ACSM = dstLen_wait) else
				'0';
	ACSM_Rd_req <= '1' when (ACSM = srcTag_req or ACSM = srcLen_req or ACSM = dstTag_req or ACSM = dstLen_req) else
				   '0';
	ACSM_Addr <= ACSM_Addr_reg;
	ACCmplt <= '1' when(ACSM = copy and ACRdRemBytes = x"000" and ACWrRemBytes = x"000" and AC_Bus2IP_Mst_Cmplt = '1') else
			   '1' when(NullPointerException = '1' or ArrayStoreException = '1' or ArrayIndexOutOfBoundsException = '1') else
			   '1' when(cpyLength = x"00000000" and ACEn = '1') else
			   '0';
			    
	
	-- process(ACSM, ACRdRemBytes, AC_Bus2IP_Mst_Cmplt, writerBurstCmplt, readerSM, rdSize, next_aryBufLen_SLV)
	process(ACSM, ACRdRemBytes, AC_Bus2IP_Mst_Cmplt, writerBurstCmplt, readerSM, next_aryBufLen_SLV)
	begin
		case readerSM is
			when idle => 
				if(ACSM = copy and ACRdRemBytes /= x"000") then
					next_readerSM <= sgnlWordRd_req;
				else
					next_readerSM <= idle;
				end if;
			
			when sgnlWordRd_req => 
				next_readerSM <= sgnlWordRd_wait;
			
			when sgnlWordRd_wait => 
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					if(ACRdRemBytes = x"000") then
						next_readerSM <= idle;
					else
						if(next_aryBufLen_SLV <= x"03") then
							next_readerSM <= sgnlWordRd_req;
						else
							next_readerSM <= waitWriter;
						end if;
					end if;
				else
					next_readerSM <= sgnlWordRd_wait;
				end if;
				
			when waitWriter => 	
				if(writerBurstCmplt = '1') then
					next_readerSM <= sgnlWordRd_req;
				else
					next_readerSM <= waitWriter;
				end if;
				
			when others =>
				next_readerSM <= idle;
				
		end case;
	end process;
	reader_Rd_req <= reader_Rd_req_reg;
	isReading <= '1' when(readerSM /= idle and readerSM /= waitWriter) else
				 '0';																-- capacity not enough or reading is finished
	readerBurstCmplt <= '1' when(isReading = '1' and AC_Bus2IP_Mst_Cmplt = '1' and ((x"03" < next_aryBufLen_SLV) or ACRdRemBytes = x"000")) else
						'0';
                        
	
	--process(writerSM, ACWrRemBytes, AC_Bus2IP_Mst_Cmplt, readerBurstCmplt, next_aryBufLen_SLV, wrSize)
	process(writerSM, ACWrRemBytes, AC_Bus2IP_Mst_Cmplt, readerBurstCmplt, next_aryBufLen_SLV )
	begin
		case writerSM is
			when idle =>
				if(readerBurstCmplt = '1') then
					next_writerSM <= sgnlWordWr_req;
				else
					next_writerSM <= idle;
				end if;

			when sgnlWordWr_req =>
				next_writerSM <= sgnlWordWr_wait;
			
			when sgnlWordWr_wait =>	
				if(AC_Bus2IP_Mst_Cmplt = '1') then
					if(next_aryBufLen_SLV = x"000") then
						if(ACWrRemBytes = x"000") then
							next_writerSM <= idle;
						else
							next_writerSM <= waitReader;						
						end if;
					elsif(next_aryBufLen_SLV < x"004") then
						if(ACWrRemBytes = next_aryBufLen_SLV) then		-- last Wr req.
							next_writerSM <= sgnlWordWr_req;
						else											-- Buffer remains less than 4 bytes and wait the reader for data alignment
							next_writerSM <= waitReader;
						end if;
					else
						next_writerSM <= sgnlWordWr_req;
					end if;
				else
					next_writerSM <= sgnlWordWr_wait;
				end if;

			when waitReader	=> 
				if(readerBurstCmplt = '1') then
					next_writerSM <= sgnlWordWr_req;
				else
					next_writerSM <= waitReader;
				end if;
				
			when others =>
				next_writerSM <= idle;
		end case;
	end process;
	writer_Wr_req <= writer_Wr_req_reg;
	isWriting <= '1' when(writerSM /= idle and writerSM /= waitReader) else
				 '0';
	writerBurstCmplt <= '1' when((ACWrRemBytes = x"000" or (ACWrRemBytes > next_aryBufLen_SLV and next_aryBufLen_SLV < x"004")) and isWriting = '1' and AC_Bus2IP_Mst_Cmplt = '1') else
						'0';

	-- flip-flops
	process(Clk) 
	begin
                if(rising_edge(Clk)) then
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
			writer_Addr_reg <= (others => '0');
			ACRdRemBytes <= (others => '0');
			ACWrRemBytes <= (others => '0');
			ACSM_Addr_reg <= (others => '0');
		else
			if(ACEn = '1') then
				src_reg <= src;
				srcPos_reg <= srcPOs;
				dst_reg <= dst;
				dstPos_reg <= dstPos;
				cpyLength_reg <= cpyLength;
				cpySize <= SHL(cpyLength(11 downto 0), logElementSize);
			end if;
			
                        case next_ACSM is -- modified since 2013.6.22
                            when srcTag_req =>
                                    ACSM_Addr_reg <= src - 8;
                            when srcLen_req => 
                                    ACSM_Addr_reg <= src_reg - 4;
                            when dstTag_req =>
                                    ACSM_Addr_reg <= dst_reg - 8;
                            when dstLen_req => 
                                    ACSM_Addr_reg <= dst_reg - 4;
                            when others => 
                                    ACSM_Addr_reg <= ACSM_Addr_reg;
                        end case;
			--if(next_ACSM = srcTag_req) then
			--	ACSM_Addr_reg <= src - 8;
			--elsif(next_ACSM = srcLen_req) then
			--	ACSM_Addr_reg <= src_reg - 4;
			--elsif(next_ACSM = dstTag_req) then
			--	ACSM_Addr_reg <= dst_reg - 8;
			--elsif(next_ACSM = dstLen_req) then
			--	ACSM_Addr_reg <= dst_reg - 4;
			--end if;
			
			if(next_writerSM = sgnlWordWr_req) then
				writer_Wr_req_reg <= '1';
				writeBE <= writeBE_L and writeBE_U;
				writer_Addr_reg <= next_writer_Addr(31 downto 2)&"00";
			else
				writer_Wr_req_reg <= '0';
			end if;
			
			if(next_readerSM = sgnlWordRd_req) then
				reader_Rd_req_reg <= '1';
				aryBufBE <= aryBufBE_L and aryBufBE_U;
				reader_Addr_reg <= next_reader_Addr(31 downto 2)&"00";
			else
				reader_Rd_req_reg <= '0';
			end if;
			
			srcStartAddr <= src_reg + SHL(srcPos_reg , logElementSize);
			dstStartAddr <= dst_reg + SHL(dstPos_reg , logElementSize);
			
			if(AC_Bus2IP_Mst_Cmplt = '1') then
				--if(srcTagRd = '1') then	
				--	srcType <= AC_Bus2IP_MstRd_d(0 to 7);
				--elsif(srcLenRd = '1') then
				--	srcLength <= AC_Bus2IP_MstRd_d(20 to 31);
				--elsif(dstTagRd = '1') then
				--	dstType <= AC_Bus2IP_MstRd_d(0 to 7);
				--elsif(dstLenRd = '1') then
				--	dstLength <= AC_Bus2IP_MstRd_d(20 to 31);
				--end if;
                                if(srcTagRd = '1') then
					srcType <= AC_Bus2IP_MstRd_d(0 to 7);
                                end if;
                                if(srcLenRd = '1') then
					srcLength <= AC_Bus2IP_MstRd_d(20 to 31);
                                end if;
                                if(dstTagRd = '1') then
					dstType <= AC_Bus2IP_MstRd_d(0 to 7);
                                end if;
                                if(dstLenRd = '1') then
					dstLength <= AC_Bus2IP_MstRd_d(20 to 31);
                                end if;
			end if;
			
			if(ACSM = dstLen_wait and AC_Bus2IP_Mst_Cmplt = '1') then
				ACRdRemBytes <= cpySize;
				ACWrRemBytes <= cpySize;
			elsif(isReading = '1') then
				if(readerSM = sgnlWordRd_req) then
					ACRdRemBytes <= ACRdRemBytes - rdSize;
				end if;	
			elsif(isWriting = '1') then
				if(writerSM = sgnlWordWr_req) then
					ACWrRemBytes <= ACWrRemBytes - wrSize;
				end if;	
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
		end if;
	end process;
	
	process(clk) begin
                if(rising_edge(clk)) then
		if(rst = '1') then
			wrSize <= (others => '0');
			rdSize <= (others => '0');
		else
			if(next_writerSM = sgnlWordWr_req or (writerSM = idle and readerBurstCmplt = '1')) then
				if(next_writer_Addr(31 downto 2) = dstEndAddr(31 downto 2)) then				-- the last wr req (and it also could be the first req)
					wrSize <= (x"00"&"00"&dstEndAddr(1 downto 0)) - (x"00"&"00"&next_writer_Addr(1 downto 0)) + 1;
				elsif(next_writer_Addr(31 downto 2) = dstStartAddr(31 downto 2)) then										-- the first wr req
					wrSize <= x"004" -( x"00"&"00"&next_writer_Addr(1 downto 0));
				else
					wrSize <= x"004";
				end if;
			end if;	
			
			if(next_readerSM = sgnlWordRd_req or (readerSM = idle and (ACSM = copy and ACRdRemBytes /= x"000"))) then
				if(next_reader_Addr(31 downto 2) = srcEndAddr(31 downto 2)) then				-- the last rd req (and it also could be the first req)
					rdSize <= (x"00"&"00"&srcEndAddr(1 downto 0)) - (x"00"&"00"&next_reader_Addr(1 downto 0)) + 1;
				elsif(next_reader_Addr(31 downto 2) = srcStartAddr(31 downto 2)) then										-- the first rd req
					rdSize <= x"004" - (x"00"&"00"&next_reader_Addr(1 downto 0));
				else
					rdSize <= x"004";
				end if;	
			end if;
		end if;
		end if;
	end process;
	
	srcEnd <= srcPos_reg + cpyLength_reg;
	dstEnd <= dstPos_reg + cpyLength_reg;
	next_reader_Addr <= cpySize - ACRdRemBytes + srcStartAddr;
	srcEndAddr <= cpySize + srcStartAddr - 1; -- addr of the last byte
	next_writer_Addr <= cpySize - ACWrRemBytes + dstStartAddr;
	dstEndAddr <= cpySize + dstStartAddr - 1; -- addr of the last byte
	
	-- char array buffer
	bufWrEn <= '1' when(isReading = '1' and AC_Bus2IP_Mst_Cmplt = '1') else
			   '0';
	bufRdEn <= '1' when(isWriting = '1' and AC_Bus2IP_Mst_Cmplt = '1') else
			   '0';
	bufInit <= '1' when(ACen = '1') else
			   '0';
	process(Clk, Rst) 
	begin
		if(Rst = '1') then
			charAryBuf <= (others => (others => '0'));
			SP <= 0;
		elsif(rising_edge(Clk)) then
			if (bufInit = '1' or bufWrEn = '1' or bufRdEn = '1') then
				aryBufLen <= next_aryBufLen;
			end if;
			
			if(bufInit = '1') then
				SP <= 0;
			elsif(bufWrEn = '1') then
				case aryBufBE is
					when "1111" =>
						charAryBuf(EP)     <= AC_Bus2IP_MstRd_d(0 to 7);
						charAryBuf((EP + 1) MOD 8)  <= AC_Bus2IP_MstRd_d(8 to 15);
						charAryBuf((EP + 2) MOD 8) <= AC_Bus2IP_MstRd_d(16 to 23);
						charAryBuf((EP + 3) MOD 8) <= AC_Bus2IP_MstRd_d(24 to 31);
					when "0111" =>
						charAryBuf(EP) 	   <= AC_Bus2IP_MstRd_d(8 to 15);
						charAryBuf((EP + 1) MOD 8) <= AC_Bus2IP_MstRd_d(16 to 23);
						charAryBuf((EP + 2) MOD 8) <= AC_Bus2IP_MstRd_d(24 to 31);
					when "0011" =>
						charAryBuf(EP)     <= AC_Bus2IP_MstRd_d(16 to 23);
						charAryBuf((EP + 1) MOD 8) <= AC_Bus2IP_MstRd_d(24 to 31);
					when "0001" =>
						charAryBuf(EP) 	   <= AC_Bus2IP_MstRd_d(24 to 31);
					when "1110" =>
						charAryBuf(EP) 	   <= AC_Bus2IP_MstRd_d(0 to 7);
						charAryBuf((EP + 1) MOD 8) <= AC_Bus2IP_MstRd_d(8 to 15);
						charAryBuf((EP + 2) MOD 8) <= AC_Bus2IP_MstRd_d(16 to 23);
					when "1100" =>
						charAryBuf(EP)     <= AC_Bus2IP_MstRd_d(0 to 7);
						charAryBuf((EP + 1) MOD 8) <= AC_Bus2IP_MstRd_d(8 to 15);
					when "1000" =>
						charAryBuf(EP)     <= AC_Bus2IP_MstRd_d(0 to 7);
					when others => null;						
				end case;
			elsif(bufRdEn = '1') then
				SP <= (SP + CONV_INTEGER(wrSize)) MOD 8;
			end if;
		end if;
	end process;
	
    -- there's a latch here , its sensitivity list is not complete , 2013.6.20
	process(bufInit, bufWrEn, aryBufBE, bufRdEn, aryBufLen, wrSize) begin       -- Do not add wrSize into this list
		if(bufInit = '1') then
			next_aryBufLen <= 0;
		elsif(bufWrEn = '1') then
			case aryBufBE is
				when "1111" =>
					next_aryBufLen <= (aryBufLen + 4) MOD 8;
				when "0111" =>
					next_aryBufLen <= (aryBufLen + 3) MOD 8;
				when "0011" =>
					next_aryBufLen <= (aryBufLen + 2) MOD 8;
				when "0001" =>
					next_aryBufLen <= (aryBufLen + 1) MOD 8;
				when "1110" =>
					next_aryBufLen <= (aryBufLen + 3) MOD 8;
				when "1100" =>
					next_aryBufLen <= (aryBufLen + 2) MOD 8;
				when "1000" =>
					next_aryBufLen <= (aryBufLen + 1) MOD 8;
				when others => null;						
			end case;
		elsif(bufRdEn = '1') then
			next_aryBufLen <= aryBufLen - CONV_INTEGER(wrSize);
		end if;
	end process;
	
	--process(cpySize, srcStartAddr, srcEndAddr, ACWrRemBytes, dstStartAddr, dstEndAddr, next_reader_Addr, next_writer_Addr)
        process(srcStartAddr, srcEndAddr, dstStartAddr, dstEndAddr, next_reader_Addr, next_writer_Addr)
	begin
		if(next_reader_Addr(31 downto 2) = srcStartAddr(31 downto 2)) then	
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
		
		if(next_reader_Addr(31 downto 2) = srcEndAddr(31 downto 2)) then
			case srcEndAddr(1 downto 0) is
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
		
		if(next_writer_Addr(31 downto 2) = dstStartAddr(31 downto 2)) then	
			case dstStartAddr(1 downto 0) is
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
		
		if(next_writer_Addr(31 downto 2) = dstEndAddr(31 downto 2)) then
			case dstEndAddr(1 downto 0) is
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
	
	EP <= (SP + aryBufLen) MOD 8;
	aryBufLen_SLV <= conv_std_logic_vector(aryBufLen, 7);
	next_aryBufLen_SLV <= conv_std_logic_vector(next_aryBufLen, 7);
	
	-- cs debug
	With readerSM Select
		debug_readerSM <= "00" when idle,
						  "01" when sgnlWordRd_req,
						  "10" when sgnlWordRd_wait,
						  "11" when waitWriter;
	
	With writerSM Select
		debug_writerSM <= "000" when idle,
						  "001" when waitReader,
						  "010" when sgnlWordWr_req,
						  "011" when sgnlWordWr_wait,
						  "111" when others;
	debug_ACRdRemBytes <= ACRdRemBytes;
	debug_srcEnd_addr <= srcEndAddr;
	debug_cpySize <= cpySize;
	debug_NullPointerException <= NullPointerException;
	debug_ArrayStoreException <= ArrayStoreException;
	debug_ArrayIndexOutOfBoundsException <= ArrayIndexOutOfBoundsException;
	debug_AC_Bus2IP_MstRd_d <= AC_Bus2IP_MstRd_d;
	debug_ACWrRemBytes <= ACWrRemBytes;
	debug_next_aryBufLen_SLV <= next_aryBufLen_SLV;
	debug_wrSize <= wrSize;
	debug_rdSize <= rdSize;
	debug_AC_SP <= conv_std_logic_vector(SP, 7);
	debug_AC_SP_next <= (others => '0');
end architecture rtl;

