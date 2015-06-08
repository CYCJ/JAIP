------------------------------------------------------------------------------
-- Filename	:	translation_ROM.vhd
-- Version	:	3.00
-- Author	:	Han-Wen Kuo
-- Date		:	Nov 2010
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
-- Filename	:	translation_ROM.vhd
-- Version	:	
-- Author	:	
-- Date		:	
-- VHDL Standard:	VHDL'93
-- Describe	:	
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.config.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity translation_ROM is
	generic(
		RAMB_S18_AWIDTH			: integer := 10
	);
	port(
		Rst						: in  std_logic;
		clk						: in  std_logic;
		enable					: in  std_logic;
		DOA						: out std_logic_vector(15 downto 0);
		DOB						: out std_logic_vector(15 downto 0);
		ADDRA					: in  std_logic_vector(RAMB_S18_AWIDTH-1 downto 0);
		ADDRB					: in  std_logic_vector(RAMB_S18_AWIDTH-1 downto 0)
	);
end entity translation_ROM;

architecture rtl of translation_ROM is

	signal DOA_tmp				: std_logic_vector(15 downto 0);
	signal DOB_tmp				: std_logic_vector(15 downto 0);

	begin
	
	DOA <= DOA_tmp;
	DOB <= DOB_tmp;
	
	bytecode_translation_ROM : RAMB16_S18_S18
	generic map(
		-- opd_num(4bit) is_complex(4bit) semitranslated_code(1byte)
			INIT_00 => 
				X"0132" &	-- X"0F" =>	dconst_1	
				X"0131" &	-- X"0E" =>	dconst_0	
				X"0009" &	-- X"0D" =>	fconst_2	=> ldimm_9
				X"0008" &	-- X"0C" =>	fconst_1	=> ldimm_8
				X"0000" &	-- X"0B" =>	fconst_0	=> ldimm_0
				X"0130" &	-- X"0A" =>	lconst_1	
				X"0131" &	-- X"09" =>	lconst_0	
				X"0005" &	-- X"08" =>	iconst_5	=> ldimm_5
				X"0004" &	-- X"07" =>	iconst_4	=> ldimm_4
				X"0003" &	-- X"06" =>	iconst_3	=> ldimm_3
				X"0002" &	-- X"05" =>	iconst_2	=> ldimm_2
				X"0001" &	-- X"04" =>	iconst_1	=> ldimm_1
				X"0000" &	-- X"03" =>	iconst_0	=> ldimm_0
				X"000C" &	-- X"02" =>	iconst_m1	=> ldimm_12
				X"0000" &	-- X"01" =>	aconst_null  => ldimm_0
				X"00FF",	-- X"00" =>	nop		=> nop	
				
			INIT_01 => 
				X"0135" &	-- X"1F" =>	lload_1	
				X"0134" &	-- X"1E" =>	lload_0	
				X"001B" &	-- X"1D" =>	iload_3	=> ldval_3
				X"001A" &	-- X"1C" =>	iload_2	=> ldval_2
				X"0019" &	-- X"1B" =>	iload_1	=> ldval_1
				X"0018" &	-- X"1A" =>	iload_0	=> ldval_0 
				X"1010" &	-- X"19" =>	aload	=> ldval_opd
				X"1133" &	-- X"18" =>	dload
				X"1010" &	-- X"17" =>	fload	=> ldval_opd
				X"1133" &	-- X"16" =>	lload
				X"1010" &	-- X"15" =>	iload	=> ldval_opd
				X"31F0" &	-- X"14" =>	ldc2_w
				X"3114" &	-- X"13" =>	ldc_w
				X"1110" &	-- X"12" =>	ldc
				X"3028" &	-- X"11" =>	sipush	=> ldopd2
				X"1020",	-- X"10" =>	bipush	=> ldopd 
				
			INIT_02 => 
				X"015D" &	-- X"2F" =>	laload
				X"01C9" &	-- X"2E" =>	iaload
				X"001B" &	-- X"2D" =>	aload_3	=> ldval_3
				X"001A" &	-- X"2C" =>	aload_2	=> ldval_2
				X"0019" &	-- X"2B" =>	aload_1	=> ldval_1
				X"0018" &	-- X"2A" =>	aload_0	=> ldval_0
				X"0137" &	-- X"29" =>	dload_3	
				X"0136" &	-- X"28" =>	dload_2	
				X"0135" &	-- X"27" =>	dload_1	
				X"0134" &	-- X"26" =>	dload_0	
				X"001B" &	-- X"25" =>	fload_3	=> ldval_3
				X"001A" &	-- X"24" =>	fload_2	=> ldval_2
				X"0019" &	-- X"23" =>	fload_1	=> ldval_1
				X"0018" &	-- X"22" =>	fload_0	=> ldval_0
				X"0137" &	-- X"21" =>	lload_3	
				X"0136",	-- X"20" =>	lload_2	
				
			INIT_03 =>
				X"0139" &	-- X"3F" =>	lstore_0	
				X"005B" &	-- X"3E" =>	istore_3	=> stval_3
				X"005A" &	-- X"3D" =>	istore_2	=> stval_2
				X"0059" &	-- X"3C" =>	istore_1	=> stval_1
				X"0058" &	-- X"3B" =>	istore_0	=> stval_0
				X"1050" &	-- X"3A" =>	astore	=> stval_opd
				X"1138" &	-- X"39" =>	dstore	
				X"1050" &	-- X"38" =>	fstore	=> stval_opd
				X"1138" &	-- X"37" =>	lstore	
				X"1050" &	-- X"36" =>	istore	=> stval_opd
				X"01CB" &	-- X"35" =>	saload
				X"01CB" &	-- X"34" =>	caload
				X"01CA" &	-- X"33" =>	baload
				X"01C9" &	-- X"32" =>	aaload
				X"015D" &	-- X"31" =>	daload
				X"01C9",	-- X"30" =>	faload
							
			INIT_04 => 
				X"014A" &	-- X"4F" =>	iastore
				X"005B" &	-- X"4E" =>	astore_3	=> stval_3
				X"005A" &	-- X"4D" =>	astore_2	=> stval_2
				X"0059" &	-- X"4C" =>	astore_1	=> stval_1
				X"0058" &	-- X"4B" =>	astore_0	=> stval_0
				X"013C" &	-- X"4A" =>	dstore_3	
				X"013B" &	-- X"49" =>	dstore_2	
				X"013A" &	-- X"48" =>	dstore_1	
				X"0139" &	-- X"47" =>	dstore_0	
				X"005B" &	-- X"46" =>	fstore_3	=> stval_3
				X"005A" &	-- X"45" =>	fstore_2	=> stval_2
				X"0059" &	-- X"44" =>	fstore_1	=> stval_1
				X"0058" &	-- X"43" =>	fstore_0	=> stval_0
				X"013C" &	-- X"42" =>	lstore_3	
				X"013B" &	-- X"41" =>	lstore_2	
				X"013A",	-- X"40" =>	lstore_1	
							
			INIT_05 =>
				X"01CF" &	-- X"5F" =>	swap  
				X"013D" &	-- X"5E" =>	dup2_x2		=> not implement
				X"013F" &	-- X"5D" =>	dup2_x1
				X"01CE" &	-- X"5C" =>	dup2		
				X"01CD" &	-- X"5B" =>	dup_x2	
				X"01CC" &	-- X"5A" =>	dup_x1	
				X"0038" &	-- X"59" =>	dup		
				X"010E" &	-- X"58" =>	pop2  
				X"0078" &	-- X"57" =>	pop		
				X"014C" &	-- X"56" =>	sastore
				X"014C" &	-- X"55" =>	castore
				X"014E" &	-- X"54" =>	bastore
				X"014A" &	-- X"53" =>	aastore
				X"018A" &	-- X"52" =>	dastore
				X"014A" &	-- X"51" =>	fastore
				X"018A",	-- X"50" =>	lastore
						
			INIT_06 => 
				X"008A" &	-- X"6F" =>	ddiv		=> not implement
				X"008A" &	-- X"6E" =>	fdiv		=> not implement
				X"0153" &	-- X"6D" =>	ldiv
				X"008A" &	-- X"6C" =>	idiv		=> div				
				X"0089" &	-- X"6B" =>	dmul		=> not implement
				X"0089" &	-- X"6A" =>	fmul		=> not implement
				X"0152" &	-- X"69" =>	lmul
				X"0089" &	-- X"68" =>	imul		=> mul
				X"0087" &	-- X"67" =>	dsub		=> not implement
				X"0087" &	-- X"66" =>	fsub		=> not implement
				X"0151" &	-- X"65" =>	lsub
				X"0087" &	-- X"64" =>	isub		=> sub
				X"0084" &	-- X"63" =>	dadd		=> not implement
				X"0084" &	-- X"62" =>	fadd		=> not implement 
				X"0150" &	-- X"61" =>	ladd
				X"0084",	-- X"60" =>	iadd		=> add

			INIT_07 => 
				X"0158" &	-- X"7F" =>	land
				X"0083" &	-- X"7E" =>	iand		=> and
				X"0157" &	-- X"7D" =>	lushr
				X"008C" &	-- X"7C" =>	ushr		=> ushr
				X"0156" &	-- X"7B" =>	lshr
				X"008E" &	-- X"7A" =>	ishr		=> shr
				X"0155" &	-- X"79" =>	lshl
				X"008D" &	-- X"78" =>	ishl		=> shl
				X"010F" &	-- X"77" =>	dneg		=> not implement
				X"010F" &	-- X"76" =>	fneg		=> not implement
				X"015B" &	-- X"75" =>	lneg
				X"010F" &	-- X"74" =>	ineg
				X"008B" &	-- X"73" =>	drem		=> not implement
				X"008B" &	-- X"72" =>	frem		=> not implement 
				X"0154" &	-- X"71" =>	lrem
				X"008B",	-- X"70" =>	irem		=> rem

			INIT_08 =>
				X"00FE" &	-- X"8F" =>	d2l		=> not implement
				X"00FE" &	-- X"8E" =>	d2i		=> not implement
				X"00FE" &	-- X"8D" =>	f2d		=> not implement
				X"00FE" &	-- X"8C" =>	f2l		=> not implement
				X"00FE" &	-- X"8B" =>	f2i		=> not implement
				X"00FE" &	-- X"8A" =>	l2d		=> not implement
				X"00FE" &	-- X"89" =>	l2f		=> not implement
				X"0078" &	-- X"88" =>	l2i		=> not implement
				X"00FE" &	-- X"87" =>	i2d		=> not implement
				X"00FE" &	-- X"86" =>	i2f		=> not implement
				X"00FE" &	-- X"85" =>	i2l		=> not implement
				X"312C" &	-- X"84" =>	iinc		
				X"015A" &	-- X"83" =>	lxor
				X"0082" &	-- X"82" =>	ixor	=> xor
				X"0159" &	-- X"81" =>	lor
				X"0081",	-- X"80" =>	ior		=> or

			INIT_09 => 
				X"3106" &	-- X"9F" =>	if_icmpeq	=> if_cmpeq
				X"3105" &	-- X"9E" =>	ifle		
				X"3104" &	-- X"9D" =>	ifgt		
				X"3103" &	-- X"9C" =>	ifge		
				X"3102" &	-- X"9B" =>	iflt		
				X"3101" &	-- X"9A" =>	ifne		
				X"3100" &	-- X"99" =>	ifeq		
				X"00FE" &	-- X"98" =>	dcmpg		=> not implement
				X"00FE" &	-- X"97" =>	dcmpl		=> not implement
				X"00FE" &	-- X"96" =>	fcmpg		=> not implement
				X"00FE" &	-- X"95" =>	fcmpl		=> not implement
				X"015D" &	-- X"94" =>	lcmp
				X"00FE" &	-- X"93" =>	i2s			=> not implement
				X"00FE" &	-- X"92" =>	i2c			=> not implement
				X"00FE" &	-- X"91" =>	i2b			=> not implement
				X"00FE",	-- X"90" =>	d2f			=> not implement

			INIT_0A => 
				X"01E0" &	-- X"AF" =>	dreturn
				X"0177" &	-- X"AE" =>	freturn
				X"01E0" &	-- X"AD" =>	lreturn
				X"0177" &	-- X"AC" =>	ireturn
				X"F180" &	-- X"AB" =>	lookupswitch
				X"F160" &	-- X"AA" =>	tableswitch
				X"10FE" &	-- X"A9" =>	ret			=> not implement
				X"30FE" &	-- X"A8" =>	jsr			=> not implement
				X"316F" &	-- X"A7" =>	goto
				X"310D" &	-- X"A6" =>	if_acmpne	=> if_cmpne
				X"310C" &	-- X"A5" =>	if_acmpeq	=> if_cmpeq
				X"310B" &	-- X"A4" =>	if_icmple	=> if_cmple
				X"310A" &	-- X"A3" =>	if_icmpgt	=> if_cmpgt
				X"3109" &	-- X"A2" =>	if_icmpge	=> if_cmpge
				X"3108" &	-- X"A1" =>	if_icmplt	=> if_cmplt
				X"3107",	-- X"A0" =>	if_icmpne	=> if_cmpne

			INIT_0B => 
				X"F16C" &	-- X"BF" =>	athrow  ??
				X"012E" &	-- X"BE" =>	arraylength
				X"3118" &	-- X"BD" =>	anewarray
				X"111D" &	-- X"BC" =>	newarray
				X"3140" &	-- X"BB" =>	new
				X"00FE" &	-- X"BA" =>	(null)
				X"F1C0" &	-- X"B9" =>	invokeinterface  ??
				X"31A0" &	-- X"B8" =>	invokestatic
				X"31B0" &	-- X"B7" =>	invokespecial
				X"31D0" &	-- X"B6" =>	invokevirtual
				X"3145" &	-- X"B5" =>	putfield
				X"3124" &	-- X"B4" =>	getfield
				X"3128" &	-- X"B3" =>	putstatic
				X"3120" &	-- X"B2" =>	getstatic
				X"0170" &	-- X"B1" =>	return
				X"0177",	-- X"B0" =>	areturn

			INIT_0C =>
				X"00FE" &	-- X"CF" =>	(null)
				X"00FE" &	-- X"CE" =>	(null)
				X"00FE" &	-- X"CD" =>	(null)
				X"00FE" &	-- X"CC" =>	(null)
				X"00FE" &	-- X"CB" =>	(null)
				X"00FE" &	-- X"CA" =>	breakpoint	=> not implement
				X"F0FE" &	-- X"C9" =>	jsr_w		=> not implement
				X"F0FE" &	-- X"C8" =>	goto_w		=> not implement
				X"316E" &	-- X"C7" =>	ifnonnull	=> ifne
				X"316D" &	-- X"C6" =>	ifnull		=> ifeq
				X"7190" &	-- X"C5" =>	multianewarray  -- implemented by using ISR , by fox
				X"00FE" &	-- X"C4" =>	wide		=> not implement
				X"0199" &	-- X"C3" =>	monitorexit  ??	
				X"0194" &	-- X"C2" =>	monitorenter  ??
				X"30FE" &	-- X"C1" =>	instanceof	=> not implement
				X"30FF",	-- X"C0" =>	checkcast	=> not implement
						
		INIT_0D =>X"00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE",	
		
		INIT_0E =>
				X"F0FE" &	-- X"EF" =>
				X"00FE" &	-- X"EE" =>
				X"00FE" &	-- X"ED" =>
				X"00FE" &	-- X"EC" =>
				X"00FE" &	-- X"EB" =>
				X"00FE" &	-- X"EA" =>
				X"00FE" &	-- X"E9" =>
				X"00FE" &	-- X"E8" =>
				X"00FE" &	-- X"E7" =>
				X"00FE" &	-- X"E6" => 
				X"00FE" &	-- X"E5" =>
				X"00FE" &	-- X"E4" =>
				X"00FE" &	-- X"E3" =>	
				X"00FE" &	-- X"E2" =>	
				X"00FE" &	-- X"E1" =>   
				X"00FE"		-- X"E0" =>	
	)		
	port map (
		DIA   => (others => '0'),
		DIPA  => (others => '0'),
		ADDRA => ADDRA,
		DOA   => DOA_tmp,
		DIB   => (others => '0'), 
		DIPB  => (others => '0'),
		ADDRB => ADDRB,  
		DOB   => DOB_tmp,
		CLKA  => clk,  
		CLKB  => clk,   
		ENA   => enable,
		ENB   => enable, 
		SSRA  => Rst,
		SSRB  => Rst,
		WEA   => '0',
		WEB   => '0'	
	);
					
end architecture rtl;