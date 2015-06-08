------------------------------------------------------------------------------
-- Filename	:	ALU.vhd
-- Version	:	1.06
-- Author	:	Hou-Jen Ko
-- Date		:	July 2007
-- VHDL Standard:	VHDL'93
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2007. All rights reserved.							**		
-- ** Multimedia Embedded System Lab, NCTU.								**  
-- ** Department of Computer Science and Information engineering			**
-- ** National Chiao Tung University, Hsinchu 300, Taiwan				**
-- ***************************************************************************
--
----------------------------------Modified------------------------------------
------------------------------------------------------------------------------
-- Filename	:	ALU.vhd
-- Version	:	1.00
-- Author	:	Jun Fu Wang
-- Date		:	August 2013
-- VHDL Standard:	VHDL'93
-----------------------------------Update-------------------------------------
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.config.all;

entity LALU is
	generic(
		width					: integer := 64
	);
	port(
		Rst						: in  std_logic;
		clk						: in  std_logic;
		ALU_op					: in  std_logic_vector(3 downto 0);
		LALUopd1, LALUopd2		: in  std_logic_vector(63 downto 0);
		ALU_result_U				: out std_logic_vector(31 downto 0);
		ALU_result_L				: out std_logic_vector(31 downto 0);
		alu_stall_L				: out std_logic
	);
end entity LALU;

architecture rtl of LALU is  

	component Lbshifter port (
		din			: in std_logic_vector(63 downto 0);
		off			: in std_logic_vector(5 downto 0);
		op  		: in std_logic_vector(1 downto 0);
		dout		: out std_logic_vector(63 downto 0)
	);		
	end component;	
	
	component divider_64 port (
		aclk: in std_logic;
		aclken: in std_logic;
		s_axis_dividend_tvalid: in std_logic;
		s_axis_divisor_tvalid: in std_logic; 
		s_axis_dividend_tready: out std_logic;
		s_axis_divisor_tready: out std_logic;
		m_axis_dout_tvalid: out std_logic;
		s_axis_dividend_tdata: in std_logic_vector(63 downto 0);
		s_axis_divisor_tdata: in std_logic_vector(63 downto 0);
		m_axis_dout_tdata: out std_logic_vector(127 downto 0));
	end component;	
	
	COMPONENT mulu32
	PORT (
		clk : IN STD_LOGIC;
		a : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		b : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		p : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
	);
	END COMPONENT;	
	
	signal tmpL					: std_logic_vector(63 downto 0);
	signal tmpM1					: std_logic_vector(63 downto 0);
	signal tmpM2					: std_logic_vector(63 downto 0);
	signal Result_mul127				: std_logic_vector(127 downto 0);	

	
	signal ALU_result			: std_logic_vector(63 downto 0);
	signal Result_shifter		: std_logic_vector(63 downto 0);  
	signal rdy					: std_logic;
	signal rfd					: std_logic;
	signal dividend				: std_logic_vector(63 downto 0);
	signal divisor				: std_logic_vector(63 downto 0);
	signal quotient				: std_logic_vector(63 downto 0);
	signal remainder				: std_logic_vector(63 downto 0);
	--signal fractional			: std_logic_vector(27 downto 0);
	
	signal latency				: std_logic_vector(6 downto 0);
	signal mul_div_rem_flag		: std_logic;
	signal mul_div_rem_EN		: std_logic;	
	signal ce_reg				: std_logic;
	signal Result_mul			: std_logic_vector(127 downto 0);
	signal nd					: std_logic;
	signal nd_reg				: std_logic;
	signal nd_en					: std_logic;
begin
	alu_stall_L   <= '0' when latency = "0000001" else
				'1' when latency /= "0000000" else
				mul_div_rem_flag;				-- when latency = "000000"
				
	ce_reg	<= '0' when latency = "0000001" else
				'1' when latency /= "0000000" else
				mul_div_rem_flag;				-- when latency = "000000"

	mul_div_rem_flag <= '1' when ALU_op = ALU_mul or ALU_op = ALU_div or ALU_op = ALU_rem else
						'0' ;
						
	mul_div_rem_EN   <= mul_div_rem_flag when(latency = "0000000") else
						'0';
	
	nd <='1' when	ALU_op = ALU_div or ALU_op = ALU_rem else '0';
	nd_en <= nd and not nd_reg;
	
	process (clk,Rst) begin
		if(Rst = '1') then
			nd_reg <='0';
		elsif ( rising_edge (clk)) then
			if(nd = '1') then			
				nd_reg <='1';			
			else
				nd_reg <='0';
			end if;
		end if;
	end process;
	
	shift2 : Lbshifter
	port map(
		din	=> LALUopd2,
		off	=> LALUopd1(5 downto 0),
		op	=> ALU_op(1 downto 0),
		dout	=> Result_shifter
	);

	divider64 : divider_64
		port map (
			aclk => clk,
			aclken => ce_reg,
			s_axis_dividend_tvalid => nd_reg,
			s_axis_divisor_tvalid => nd_reg,
			s_axis_dividend_tready => rfd,
			m_axis_dout_tvalid => rdy,
			s_axis_dividend_tdata(63 downto 0) => LALUopd2(63 downto 0),
			s_axis_divisor_tdata(63 downto 0) => LALUopd1(63 downto 0),
			m_axis_dout_tdata(127 downto 64) => quotient(63 downto 0),
			m_axis_dout_tdata(63 downto 0) => remainder(63 downto 0)
		);		
	
	multiplier0 : mulu32
	PORT MAP (
		clk => clk,
		a => LALUopd1(31 downto 0),
		b => LALUopd2(31 downto 0),
		p => tmpL
	);	
	
	multiplier1 : mulu32
	PORT MAP (
		clk => clk,
		a => LALUopd1(63 downto 32),
		b => LALUopd2(31 downto 0),
		p => tmpM1
	);	
	
	multiplier2 : mulu32
	PORT MAP (
		clk => clk,
		a => LALUopd1(31 downto 0),
		b => LALUopd2(63 downto 32),
		p => tmpM2
	); 
	Result_mul127 <=(x"00000000"&tmpM2(31 downto 0)&x"00000000" ) + (x"00000000"&tmpM1(31 downto 0)&x"00000000" ) + (X"0000000000000000" & tmpL);
  
	process(ALU_op, LALUopd1, LALUopd2,remainder,quotient,Result_shifter,Result_mul127) begin
		case ALU_op is
			when ALU_nop=>
				ALU_result <= LALUopd1;
			when ALU_or =>
				ALU_result <= LALUopd1 or LALUopd2;
			when ALU_xor =>
				ALU_result <= LALUopd1 xor LALUopd2;
			when ALU_and =>
				ALU_result <= LALUopd1 and LALUopd2;
			when ALU_add =>
				ALU_result <= conv_std_logic_vector(signed(LALUopd1) + signed(LALUopd2),64);			
			when ALU_cmp =>
				if (signed(LALUopd1) > signed(LALUopd2)) then
					ALU_result <= x"FFFFFFFF00000000";
				elsif (signed(LALUopd1) < signed(LALUopd2)) then
					ALU_result <= x"0000000100000000";
				else 
					ALU_result <= x"0000000000000000";
				end if;
			when ALU_sub =>
				ALU_result <= conv_std_logic_vector(signed(LALUopd2) - signed(LALUopd1),64);
			when ALU_sub_r =>
				ALU_result <= conv_std_logic_vector(signed(LALUopd1) - signed(LALUopd2),64);
			-- for shifter
			when ALU_ushr =>
				ALU_result <= Result_shifter;
			when ALU_shl =>
				ALU_result <= Result_shifter;
			when ALU_shr =>
				ALU_result <= Result_shifter;
			-- divider 	
			when ALU_div =>
					ALU_result <= quotient;	
			when ALU_rem =>
					ALU_result <= remainder;	
			--multipler
			when ALU_mul =>
				ALU_result <= Result_mul127(63 downto 0);			
			when others => ALU_result <= (others => '0');
		end case;
	end process;

	ALU_result_U <= ALU_result (63 downto 32);
	ALU_result_L <= ALU_result (31 downto 0);
	process(clk, Rst) begin
		if(Rst = '1') then
				latency <= "0000000";
		elsif(rising_edge(clk)) then

				if(mul_div_rem_EN = '1') then
					if(ALU_op = ALU_mul) then
						latency <= "0001000";
					else	-- ALU_div ALU_rem
						latency <= "1000101" ;
					end if;
				elsif(latency /= "0000000") then
					latency <= latency - '1' ;
				-- elsif (rdy ='1') then -- it means the cal is finishing
					-- latency <="000001";
				end if;

		end if;	
	end process;
			
			
	
end architecture rtl;
