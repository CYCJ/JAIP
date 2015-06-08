library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity cache_storage is
	generic (
		CPU_DATA_WIDTH	:	integer		:=32;	
		TAG_SIZE		:	integer		:=13;	-- unit : bit  
		INDEX_SIZE		:	integer		:=8;	-- unit : bit
		OFFSET_SIZE		:	integer		:=5;	-- unit : bit
		ASSOCIATIVITY	:	integer		:=2; -- 1 = direct mapped , 4: 4-way set associative
		WRITE_STRATEGY	:	integer		:=0  -- 0:write_through , 1:copy_back
	);
	port(
		clk				: in std_logic;
		rst				: in std_logic;
		we				: in std_logic_vector(5 downto 0); -- read/write control
			-- for port A
		set_index 		: in std_logic_vector(INDEX_SIZE-1 downto 0);
		-- data input
		valid_in		: in std_logic;
		reference_in	: in std_logic;
		dirty_in		: in std_logic;
		tag_in			: in std_logic_vector (TAG_SIZE-1 downto 0) ;
		data_in			: in std_logic_vector (CPU_DATA_WIDTH-1 downto 0) ;
		counter			: in std_logic_vector(3 downto 0);  
		cache_offset	: in std_logic_vector(2 downto 0);
 		Cmem_IP2B_Mst_BE   : in std_logic_vector(3 downto 0);  
		-- for port B , cache coherence use , 2013.10.1
		COOR2JAIP_wr_ack_dly      : in  std_logic;
		COOR2JAIP_wr_cmplt        : out std_logic;
		COOR2JAIP_info1_cache_dly : in	std_logic_vector(TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto 0);
		COOR2JAIP_info2_cache_dly : in	std_logic_vector(CPU_DATA_WIDTH-1 downto 0);
		-- data output
		valid_out		: out std_logic;
		reference_out	: out std_logic;
		dirty_out		: out std_logic;
		tag_out			: out std_logic_vector (TAG_SIZE-1 downto 0) ;
		--data_out		: out std_logic_vector (2**(OFFSET_SIZE+3)-1 downto 0)
		data_out		: out std_logic_vector (CPU_DATA_WIDTH-1 downto 0)
	);

 
end cache_storage;

architecture Behavioral of cache_storage is


    component RAMB16_S36_S36 port (
		-- port A
        DOA                    : out std_logic_vector(31 downto 0);
        DIA                    : in  std_logic_vector(31 downto 0);
        DIPA                   : in  std_logic_vector(3 downto 0);
        DOPA                   : out std_logic_vector(3 downto 0);
        ADDRA                  : in  std_logic_vector(8 downto 0);
        SSRA                   : in  std_logic;
        CLKA                   : in  std_logic;
        ENA                    : in  std_logic;
        WEA                    : in  std_logic;
		-- port B
        DOB                    : out std_logic_vector(31 downto 0);
        DIB                    : in  std_logic_vector(31 downto 0);
        DIPB                   : in  std_logic_vector(3 downto 0);
        DOPB                   : out std_logic_vector(3 downto 0);
        ADDRB                  : in  std_logic_vector(8 downto 0);
        SSRB                   : in  std_logic;
        CLKB                   : in  std_logic;
        ENB                    : in  std_logic;
        WEB                    : in  std_logic
	);
    end component;
	
	
	constant ONE_CACHE_BLOCK_SIZE : integer := 2**(OFFSET_SIZE+3);
	constant additionalBit        : integer := 1+1+1+TAG_SIZE;
	constant HOW_MANY_CACHE_BLOCK	: integer := (2**INDEX_SIZE);
	type RAM is array
		(HOW_MANY_CACHE_BLOCK-1 downto 0) of std_logic_vector( ONE_CACHE_BLOCK_SIZE-1 downto 0 );
	type A_RAM is array
		(HOW_MANY_CACHE_BLOCK-1 downto 0) of std_logic_vector( additionalBit-1 downto 0 );	
	type data_array   is array (integer range 0 to 3) of std_logic_vector(31 downto 0);
	type bit_array    is array (integer range 0 to 3) of std_logic;
			
	signal storage	:	RAM ;
	signal Astroage :   A_RAM;
	signal blockDataIn	: std_logic_vector( ONE_CACHE_BLOCK_SIZE-1 downto 0 );
	signal blockDataOut	: std_logic_vector( ONE_CACHE_BLOCK_SIZE-1 downto 0 );	
	signal additionalDataIn  : std_logic_vector( additionalBit-1 downto 0 );
	signal additionalDataOut : std_logic_vector( additionalBit-1 downto 0 );
	
	
	signal	block_addrA	: std_logic_vector (8 downto 0);
	signal	block_addrB	: std_logic_vector (8 downto 0);	
	signal	dataInB				: std_logic_vector (31 downto 0);

	signal dataInA_BE_filter           : data_array;
	signal dataOutA	                   : data_array;
	signal dataOutB                    : data_array;
	signal block_weA                   : bit_array;
	signal block_weB                   : bit_array;
	--for multi-core coordinator, cache coherence, 2013.10.1
	constant Idle		: std_logic_vector (1 downto 0) :="00";
	constant CheckHit	: std_logic_vector (1 downto 0) :="01";
	constant Writedata	: std_logic_vector (1 downto 0) :="10";
	constant Cmplt		: std_logic_vector (1 downto 0) :="11";	 
	signal cacheCohe_state      :std_logic_vector(1 downto 0);
	signal cacheCohe_state_nxt  :std_logic_vector(1 downto 0); 
	signal cacheCohe_check_hit  : std_logic;
	signal cacheCohe_addi_DO : std_logic_vector( additionalBit-1 downto 0 );
	
begin

		additional_bit:
		process (we,valid_in,dirty_in,reference_in,tag_in,clk,additionalDataOut)
		begin
			case we(3 downto 0) is
				when "1111" =>
					additionalDataIn(additionalBit-1)	       <= valid_in;
					additionalDataIn(additionalBit-2)	       <= dirty_in;
					additionalDataIn(additionalBit-3)	       <= reference_in;
					additionalDataIn(additionalBit-4 downto 0) <= tag_in;
				when "0010" =>
					additionalDataIn(additionalBit-1)	       <= additionalDataOut(additionalBit-1);
					additionalDataIn(additionalBit-2)	       <= dirty_in;
					additionalDataIn(additionalBit-3)	       <= additionalDataOut(additionalBit-3);
					additionalDataIn(additionalBit-4 downto 0) <= additionalDataOut(additionalBit-4 downto 0);					
				when others => 
					additionalDataIn(additionalBit-1)	       <= additionalDataOut(additionalBit-1);
					additionalDataIn(additionalBit-2)	       <= additionalDataOut(additionalBit-2);
					additionalDataIn(additionalBit-3)	       <= additionalDataOut(additionalBit-3);
					additionalDataIn(additionalBit-4 downto 0) <= additionalDataOut(additionalBit-4 downto 0);
			end case;		
		end process additional_bit;

		 
		
		-- note 2013.9.25 , address B is used for support cache coherence 
		block_addrA <=			(set_index(5 downto 0) & counter(2 downto 0))	when we(5 downto 4)	= "01" -- cache miss
						else	(set_index(5 downto 0) & cache_offset) 	; --	when we(5 downto 4)	= "11" -- cache hit;
	
		D1 : for i in 0 to 3 generate
		dataInA_BE_filter(i)(31 downto 24)  <= data_in (31 downto 24) when Cmem_IP2B_Mst_BE(3) = '1' or we(5 downto 4)	= "01" else
											dataOutA(i) (31 downto 24);
		dataInA_BE_filter(i)(23 downto 16)  <= data_in (23 downto 16) when Cmem_IP2B_Mst_BE(2) = '1' or we(5 downto 4)	= "01" else
											dataOutA(i) (23 downto 16);
		dataInA_BE_filter(i)(15 downto 8)   <= data_in (15 downto 8) when Cmem_IP2B_Mst_BE(1) = '1' or we(5 downto 4)	= "01" else
											dataOutA(i) (15 downto 8);
		dataInA_BE_filter(i)( 7 downto 0)   <= data_in (7 downto 0) when Cmem_IP2B_Mst_BE(0) = '1' or we(5 downto 4)	= "01" else
											dataOutA(i) (7 downto 0);		
		end generate D1;									
				
		-- note since 2013.9.26 
		--block_weA <= '1' when to_integer(unsigned(we))>= 1 else '0';
		--block_weA <= '1' when we(5 downto 4) = "11" or we(5 downto 4) = "01" else '0';
		block_weA(0)   <= '1' when (we(5 downto 4) = "11" or we(5 downto 4) = "01") and set_index(7 downto 6)="00" else '0'; 	
		block_weA(1)   <= '1' when (we(5 downto 4) = "11" or we(5 downto 4) = "01") and set_index(7 downto 6)="01" else '0';
		block_weA(2)   <= '1' when (we(5 downto 4) = "11" or we(5 downto 4) = "01") and set_index(7 downto 6)="10" else '0';
		block_weA(3)   <= '1' when (we(5 downto 4) = "11" or we(5 downto 4) = "01") and set_index(7 downto 6)="11" else '0';		
		
			G1 : for idx in 0 to 3 generate
			RAM_array : RAMB16_S36_S36
			port map(
				-- port A
				ADDRA	=> block_addrA,
				DIPA	=> (others=>'0') ,
				DIA		=> dataInA_BE_filter(idx) , 
				DOA		=> dataOutA(idx) ,
				CLKA	=> clk,
				SSRA	=> rst,
				ENA 	=> '1',
				WEA		=> block_weA(idx),
				-- port B
				ADDRB	=> block_addrB, 
				DIPB	=> (others=>'0') ,
				DIB		=> dataInB , 
				DOB		=> dataOutB(idx),
				CLKB 	=> clk,
				SSRB 	=> rst,
				ENB     => '1',
				WEB     => block_weB(idx)
			);			
		    end generate G1;
		
		
		additioin_write : 
		process (clk)
		begin
			if(rising_edge(clk)) then		
					-- valid_bit_we="1" or dirty_bit_we="1" or refer_bit_we="1" or tag_bit_we="1" or data_bit_we="1"
				if( to_integer(unsigned(we))>= 1  ) then
					-- Synchronous write
					Astroage(to_integer(unsigned(set_index)))	<= additionalDataIn; 
				end if;
			end if;
		end process additioin_write;	
		additionalDataOut <= Astroage(to_integer(unsigned(set_index)));
		
		
		
--------------------------------------------------------------------------------		
--for multi-core coordinator, cache coherence, 2013.10.1   
--------------------------------------------------------------------------------
 
    process(clk) begin
		if(rising_edge(clk)) then
        if(rst = '1') then
            cacheCohe_state   <= Idle;
        else
			cacheCohe_state   <= cacheCohe_state_nxt;
		end if;
		end if;
    end process;   

	process(COOR2JAIP_wr_ack_dly,cacheCohe_check_hit,cacheCohe_state)
	begin
		cacheCohe_state_nxt <= cacheCohe_state;
		case cacheCohe_state is
			when Idle =>
				if(COOR2JAIP_wr_ack_dly = '1') then
					cacheCohe_state_nxt <= CheckHit; 
				end if;
			when CheckHit =>
				if(cacheCohe_check_hit = '1') then
					cacheCohe_state_nxt <=Writedata;
				else
					cacheCohe_state_nxt <=Cmplt;
				end if;
			when Writedata =>
				cacheCohe_state_nxt <=Cmplt; 
			when others => cacheCohe_state_nxt <= Idle;
		end case; 
	end process;
	
	COOR2JAIP_wr_cmplt <= '1' when (cacheCohe_state = Cmplt) else '0';
    cacheCohe_addi_DO  <=	Astroage(
								to_integer(unsigned(COOR2JAIP_info1_cache_dly(INDEX_SIZE+OFFSET_SIZE-1 downto OFFSET_SIZE)))
							);

	--determine hit or not
  	cacheCohe_check_hit<= '1' when (COOR2JAIP_info1_cache_dly(TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto INDEX_SIZE+OFFSET_SIZE)
									= cacheCohe_addi_DO(additionalBit-4 downto 0)  
									and cacheCohe_addi_DO(additionalBit-1) = '1' )
					else  '0';
						  
		block_weB(0)   <= '1' when cacheCohe_state = Writedata and set_index(7 downto 6)="00"	else '0';
		block_weB(1)   <= '1' when cacheCohe_state = Writedata and set_index(7 downto 6)="01"	else '0';
		block_weB(2)   <= '1' when cacheCohe_state = Writedata and set_index(7 downto 6)="10"	else '0';
		block_weB(3)   <= '1' when cacheCohe_state = Writedata and set_index(7 downto 6)="11"	else '0';		
		block_addrB <= COOR2JAIP_info1_cache_dly(INDEX_SIZE+OFFSET_SIZE-1 downto 2);
		dataInB <= COOR2JAIP_info2_cache_dly; 
						  
						  
						  
------------------- distribute to each output data----------------------
		valid_out		<= additionalDataOut(additionalBit-1);
		dirty_out		<= additionalDataOut(additionalBit-2);
		reference_out	<= additionalDataOut(additionalBit-3);
		tag_out			<= additionalDataOut(additionalBit-4 downto 0) ;
		data_out		<= dataOutA(0) when set_index(7 downto 6)="00" else 
		                   dataOutA(1) when set_index(7 downto 6)="01" else 
						   dataOutA(2) when set_index(7 downto 6)="10" else 
						   dataOutA(3);
		
end Behavioral;