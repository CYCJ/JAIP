library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library UNISIM;
use UNISIM.vcomponents.all;
entity GC_table is
	generic (
	TableS_bit     			: integer:=11;--current design about this maximum value  is 11
	REF_bit					: integer:=22;
	SIZE_bit				: integer:=20;
	NEXT_bit                : integer:=11;
	COUNT_bit				: integer:=5
	);
	port(
	Rst                     : in  std_logic;
	clk						: in  std_logic; 
	----------------------------------------------------------------
	-- port A
	----------------------------------------------------------------	
    Addr_A					: in  std_logic_vector(TableS_bit-1 downto 0);
	WE_A					: in  std_logic; -- read/write control
	Data_In_A				: in  std_logic_vector(REF_bit+NEXT_bit+SIZE_bit+COUNT_bit-1 downto 0);
	Data_Out_A				: out std_logic_vector(REF_bit+NEXT_bit+SIZE_bit+COUNT_bit-1 downto 0);
	----------------------------------------------------------------
	-- port B
	----------------------------------------------------------------
	Addr_B					: in  std_logic_vector(TableS_bit-1 downto 0);	
	WE_B					: in  std_logic; 
	Data_In_B				: in  std_logic_vector(REF_bit+NEXT_bit+SIZE_bit+COUNT_bit-1 downto 0);
	Data_Out_B				: out std_logic_vector(REF_bit+NEXT_bit+SIZE_bit+COUNT_bit-1 downto 0)	
	);
	end GC_table;

architecture Behavioral of GC_table is
	--constant HOW_MANY_COLUMN : integer := 2**(TableS_bit);
	
	--type RAM is array ( 0 to HOW_MANY_COLUMN-1) of std_logic_vector(REF_bit+NEXT_bit+SIZE_bit+COUNT_bit-1 downto 0);	
	--signal  MEM_storage: RAM := (others => (others => ('0')));
	--shared variable MEM_storage: RAM;
	type data_array   is array (integer range 0 to 7) of std_logic_vector(7 downto 0);
	type we_array     is array (integer range 0 to 7) of std_logic;
	
	signal RAM_input_A            : data_array;	
	signal G1_addr_A              : std_logic_vector (TableS_bit-1 downto 0);
	signal RAM_output_A           : data_array;
	signal WE_A_In                : we_array;
	
	signal RAM_input_B            : data_array;	
	signal G1_addr_B              : std_logic_vector (TableS_bit-1 downto 0);
	signal RAM_output_B           : data_array;
	signal WE_B_In                : we_array;

	
begin
	----------------------------------------------------------------
	-- port A
	----------------------------------------------------------------
	G1_addr_A       <= Addr_A(TableS_bit-1 downto 0);
	RAM_input_A(0)  <= Data_In_A(7 downto 0);
	RAM_input_A(1)  <= Data_In_A(15 downto 8);
	RAM_input_A(2)  <= Data_In_A(23 downto 16);
	RAM_input_A(3)  <= Data_In_A(31 downto 24);
	RAM_input_A(4)  <= Data_In_A(39 downto 32);
	RAM_input_A(5)  <= Data_In_A(47 downto 40);
	RAM_input_A(6)  <= Data_In_A(55 downto 48);
	RAM_input_A(7)  <= "000000"&Data_In_A(REF_bit+NEXT_bit+SIZE_bit+COUNT_bit-1 downto 56);
	
	Data_Out_A      <= RAM_output_A(7)(1 downto 0)&RAM_output_A(6)&RAM_output_A(5)&RAM_output_A(4)&
					   RAM_output_A(3)&RAM_output_A(2)&RAM_output_A(1)&RAM_output_A(0);
	
	----------------------------------------------------------------
	-- port B
	----------------------------------------------------------------
	G1_addr_B       <= Addr_B(TableS_bit-1 downto 0);
	RAM_input_B(0)  <= Data_In_B(7 downto 0);
	RAM_input_B(1)  <= Data_In_B(15 downto 8);
	RAM_input_B(2)  <= Data_In_B(23 downto 16);
	RAM_input_B(3)  <= Data_In_B(31 downto 24);
	RAM_input_B(4)  <= Data_In_B(39 downto 32);
	RAM_input_B(5)  <= Data_In_B(47 downto 40);
	RAM_input_B(6)  <= Data_In_B(55 downto 48);
	RAM_input_B(7)  <= "000000"&Data_In_B(REF_bit+NEXT_bit+SIZE_bit+COUNT_bit-1 downto 56);	
	
	Data_Out_B      <= RAM_output_B(7)(1 downto 0)&RAM_output_B(6)&RAM_output_B(5)&RAM_output_B(4)&
					   RAM_output_B(3)&RAM_output_B(2)&RAM_output_B(1)&RAM_output_B(0);
	
    G1 : for idx in 0 to 7 generate
		WE_A_In(idx) <= '1' when WE_A ='1' else '0';
		WE_B_In(idx) <= '1' when WE_B ='1' else '0';
         RAM_array : RAMB16_S9_S9
         port map(     
				-- port A
				ADDRA	=> G1_addr_A,
				DIPA	=> (others=>'0') ,
				DIA		=> RAM_input_A(idx) , 
				DOA		=> RAM_output_A(idx) ,
				CLKA	=> clk,
				SSRA	=> Rst,
				ENA 	=> '1',
				WEA		=> WE_A_In(idx),
				-- port B
				ADDRB	=> G1_addr_B, 
				DIPB	=> (others=>'0') ,
				DIB		=> RAM_input_B(idx) , 
				DOB		=> RAM_output_B(idx),
				CLKB 	=> clk,
				SSRB 	=> Rst,
				ENB     => '1',
				WEB     => WE_B_In(idx)
         );
    end generate G1;
	  
end Behavioral;