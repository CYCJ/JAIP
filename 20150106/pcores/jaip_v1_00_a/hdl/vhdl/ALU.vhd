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
-- Version	:	2.00
-- Author	:	Kuan-Nian Su
-- Date		:	July 2008
-- VHDL Standard:	VHDL'93
-----------------------------------Update-------------------------------------
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.config.all;

entity ALU is
	generic(
		width					: integer := 32
	);
	port(
		Rst						: in  std_logic;
		clk						: in  std_logic;
		Long_flag   				: in  std_logic;
		ALU_op					: in  std_logic_vector(3 downto 0);
		branch_op				: in  std_logic_vector(3 downto 0);
		ALUopd1, ALUopd2			: in  std_logic_vector(31 downto 0);
		Reg_A, Reg_B				: in  std_logic_vector(31 downto 0);
		ALU_result				: out std_logic_vector(31 downto 0);
		branch					: out std_logic ;
		alu_stall				: out std_logic
	);
end entity ALU;

architecture rtl of ALU is  
	component bshifter port (
		din			: in std_logic_vector(width-1 downto 0);
		off			: in std_logic_vector(4 downto 0);
		op  		: in std_logic_vector(1 downto 0);
		dout		: out std_logic_vector(width-1 downto 0)
	);		
	end component;

	component multiplier port (
		clk		: in std_logic;
	a			: IN std_logic_VECTOR(15 downto 0);
	b			: IN std_logic_VECTOR(15 downto 0);
	p			: OUT std_logic_VECTOR(31 downto 0));
	end component;
	
	component divider port (
		dividend	: in std_logic_VECTOR(31 downto 0);
		divisor	: in std_logic_VECTOR(31 downto 0);
		quotient		: out  std_logic_VECTOR(31 downto 0);
		fractional		: out std_logic_VECTOR(31 downto 0);
		clk		: in std_logic;
		rfd		: out std_logic ;
	ce		: in std_logic
			);
	end component;
	
	signal Result_shifter			: std_logic_vector(31 downto 0);   
	
	signal latency				: std_logic_vector(5 downto 0);
	
	signal quat_reg				: std_logic_vector(31 downto 0);
	signal remd_reg				: std_logic_vector(31 downto 0);
	signal rfd_reg					: std_logic;
	signal ce_reg					: std_logic;
	
	signal tmpL					: std_logic_vector(31 downto 0);
	signal tmpH					: std_logic_vector(31 downto 0);
	signal tmpM1					: std_logic_vector(31 downto 0);
	signal tmpM2					: std_logic_vector(31 downto 0);
	signal Result_mul				: std_logic_vector(63 downto 0);
	signal Result_mul_32			: std_logic_vector(31 downto 0);
	
	signal mul_div_rem_flag		: std_logic;
	signal mul_div_rem_EN			: std_logic;
	
	begin
					
	alu_stall   <= '0' when latency = "000001" else
				'1' when latency /= "000000" else
				mul_div_rem_flag;				-- when latency = "000000"
				
	ce_reg	<= '0' when latency = "000001" else
				'1' when latency /= "000000" else
				mul_div_rem_flag;				-- when latency = "000000"
				
	mul_div_rem_flag <= '1' when ALU_op = ALU_mul or ALU_op = ALU_div or ALU_op = ALU_rem else
						'0' ;
						
	mul_div_rem_EN   <= mul_div_rem_flag when(latency = "000000") else
						'0';

	shift0 : bshifter
	port map(
		din	=> ALUopd2,
		off	=> ALUopd1(4 downto 0),
		op	=> ALU_op(1 downto 0),
		dout	=> Result_shifter
	);
	
	divider0 : divider
	port map (
		dividend => ALUopd2,
		divisor  => ALUopd1,
		quotient => quat_reg,
		fractional	=> remd_reg,
		clk	=> clk,
		rfd	=> rfd_reg,
	ce	=> ce_reg 
	);
	
	multiplier0 : multiplier  port map (
		clk => cLk,
		a => ALUopd1(15 downto 0),
		b => ALUopd2(15 downto 0),
		p => tmpL
	);	
	multiplier1 : multiplier  port map (
		clk => cLk,
		a => ALUopd1(31 downto 16),
		b => ALUopd2(31 downto 16),
		p => tmpH
	);   
	multiplier2 : multiplier  port map (
		clk => cLk,
		a => ALUopd1(31 downto 16),
		b => ALUopd2(15 downto 0),
		p => tmpM1
	); 
	multiplier3 : multiplier  port map (
		clk => cLk,
		a => ALUopd1(15 downto 0),
		b => ALUopd2(31 downto 16),
		p => tmpM2
	);

	Result_mul <= (tmpH & X"00000000") + (X"0000" & tmpM1 & X"0000") +
				(X"0000" & tmpM2 & X"0000") + (X"00000000" & tmpL);

	Result_mul_32 <= (tmpM1(15 downto 0) & X"0000") + (tmpM2(15 downto 0) & X"0000") + tmpL;
	
	process(branch_op, Reg_A, Reg_B) 
		variable zero		: std_logic;
		variable less		: std_logic;
	begin
		if(branch_op(3) = '0') then
			-- if(A > B) then
			if(signed(Reg_A) > signed(Reg_B)) then -- for +A & -B
				less := '1';
			else
				less := '0';
			end if;
			if(Reg_A = Reg_B) then
				zero := '1';
			else
				zero := '0';
			end if;
		else
			-- if(0 > A) then
			if(Reg_A(31) = '1') then -- for negative int
				less := '1';
			else
				less := '0';
			end if;
				if(Reg_A = 0) then
				zero := '1';
			else
				zero := '0';
			end if;		
		end if;

		case branch_op(2 downto 0) is
			when "000" =>	-- eq
				if(zero = '1') then
					branch <= '1';
				else
					branch <= '0';
				end if;
			when "001" =>	-- ne
				if(zero = '0') then
					branch <= '1';
				else
					branch <= '0';
				end if;		
			when "010" =>	-- lt
				if(less = '1') then
					branch <= '1';
				else
					branch <= '0';
				end if;	
			when "011" =>	-- ge
				if(less = '0') then
					branch <= '1';
				else
					branch <= '0';
				end if;							
			when "100" =>	-- gt
				if(less = '0' and zero = '0') then
					branch <= '1';
				else
					branch <= '0';
				end if;							
			when "101" =>	-- le
				if(less = '1' or zero = '1') then
					branch <= '1';
				else
					branch <= '0';
				end if; 
			when "110" =>
				branch <= '1';
			when others =>
			branch <= '0';							
	end case;	

	end process;

	process(Long_flag, ALU_op, ALUopd1, ALUopd2, Result_shifter, Result_mul, quat_reg, remd_reg,Result_mul_32) begin
		if (Long_flag = '0') then
			case ALU_op is
				when ALU_nop=>
					ALU_result <= ALUopd1;
				when ALU_or =>
					ALU_result <= ALUopd1 or ALUopd2;
				when ALU_xor =>
					ALU_result <= ALUopd1 xor ALUopd2;
				when ALU_and =>
					ALU_result <= ALUopd1 and ALUopd2;
				when ALU_add =>
					ALU_result <= conv_std_logic_vector(signed(ALUopd1) + signed(ALUopd2),32);			
				when ALU_sub =>
					ALU_result <= conv_std_logic_vector(signed(ALUopd2) - signed(ALUopd1),32);
				when ALU_sub_r =>
					ALU_result <= conv_std_logic_vector(signed(ALUopd1) - signed(ALUopd2),32);
				when ALU_ushr =>
					ALU_result <= Result_shifter;
				when ALU_shl =>
					ALU_result <= Result_shifter;
				when ALU_shr =>
					ALU_result <= Result_shifter;
				when ALU_mul =>
					ALU_result <= Result_mul(31 downto 0);
				--ALU_result <= Result_mul_32;
				when ALU_div =>
					ALU_result <= quat_reg;
				when ALU_rem =>
					ALU_result <= remd_reg;	
				when others => ALU_result <= (others => '0');
			end case;
		else
			ALU_result <= ALUopd1;
		end if;
	end process;
	
	process(clk) begin
		if(rising_edge(clk)) then
			if(Rst = '1') then
				latency <= "000000";
			else 
				if(mul_div_rem_EN = '1') then
					if(ALU_op = ALU_mul) then
						latency <= "000100";
					else	-- ALU_div ALU_rem
						latency <= "100101" ;
					end if;
				elsif(latency /= "000000") then
					latency <= latency - '1' ;
				end if; 
			end if; 
		end if; 
	end process;
	
end architecture rtl;
