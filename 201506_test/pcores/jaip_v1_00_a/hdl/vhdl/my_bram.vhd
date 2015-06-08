	library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_arith.all;
	use ieee.std_logic_unsigned.all;

	entity my_bram is
		port(CLK						: in std_logic; 
			----------------------------------------------------------------
			-- port A
			----------------------------------------------------------------
			Addr_A					: in std_logic_vector(0 to 7);
			WE_A						: in std_logic; -- read/write control
			Data_In_A				: in std_logic_vector(0 to 159);
			Data_Out_A				: out std_logic_vector(0 to 159)
		);
	end my_bram;

	architecture Behavioral of my_bram is
	type RAM is array (0 to 255) of std_logic_vector(0 to 159);
	signal CacheMEM: RAM := (others => (others => ('0')));
	signal Data_Out_A_tmp : std_logic_vector(0 to 159);
	begin
	process(CLK)
	begin
		if CLK'event and CLK = '1' then
			if WE_A = '1' then
				-- Synchronous Write
				CacheMEM(CONV_INTEGER(unsigned(Addr_A))) <= Data_In_A;
			end if;
			Data_Out_A <= CacheMEM(CONV_INTEGER(unsigned(Addr_A)));
		end if;
	end process;
	
	end Behavioral;