	library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_arith.all;
	use ieee.std_logic_unsigned.all;

	entity my_bram_as_rd is
		port(
			----------------------------------------------------------------
			-- port A
			----------------------------------------------------------------
			CLK_A					: in std_logic; 
			EN_A					: in std_logic;
			WE_A					: in std_logic; -- read/write control
			Addr_A					: in std_logic_vector(0 to 7);
			Data_In_A				: in std_logic_vector(0 to 159);
			Data_Out_A				: out std_logic_vector(0 to 159);
			
			----------------------------------------------------------------
			-- port B
			----------------------------------------------------------------
			CLK_B					: in std_logic; 
			EN_B					: in std_logic;
			WE_B					: in std_logic; -- read/write control
			Addr_B					: in std_logic_vector(0 to 7);
			Data_In_B				: in std_logic_vector(0 to 159);
			Data_Out_B				: out std_logic_vector(0 to 159)
			
		);
	end my_bram_as_rd;

	architecture Behavioral of my_bram_as_rd is
	type RAM is array (0 to 255) of std_logic_vector(0 to 159);
	shared variable CacheMEM: RAM;
	begin
	process(CLK_A)
	begin
		if CLK_A'event and CLK_A = '1' then
			if EN_A = '1' then
				if WE_A = '1' then
					-- Synchronous Write
					CacheMEM(CONV_INTEGER(unsigned(Addr_A))) := Data_In_A;
				end if;
				Data_Out_A <= CacheMEM(CONV_INTEGER(unsigned(Addr_A)));	
			end if;
		end if;
	end process;
	
	process(CLK_B)
	begin
		if CLK_B'event and CLK_B = '1' then
			if EN_B = '1' then
				if WE_B = '1' then
					-- Synchronous Write
					CacheMEM(CONV_INTEGER(unsigned(Addr_B))) := Data_In_B;
				end if;
				Data_Out_B <= CacheMEM(CONV_INTEGER(unsigned(Addr_B)));	
			end if;
		end if;
	end process;
				
	end Behavioral;