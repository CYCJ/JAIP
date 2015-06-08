------------------------------------------------------------------------------
-- Filename     :       translation_ROM.vhd
-- Version      :       3.00
-- Author       :       Han-Wen Kuo
-- Date         :       Nov 2010
-- VHDL Standard:       VHDL'93
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2007. All rights reserved.                              **        
-- ** Multimedia Embedded System Lab, NCTU.                                 **  
-- ** Department of Computer Science and Information engineering            **
-- ** National Chiao Tung University, Hsinchu 300, Taiwan                   **
-- ***************************************************************************
--
----------------------------------Modified------------------------------------
------------------------------------------------------------------------------
-- Filename     :       translation_ROM.vhd
-- Version      :       
-- Author       :       
-- Date         :       
-- VHDL Standard:       VHDL'93
-- Describe     :       
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.config.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity translation_ROM is
    generic(
        RAMB_S18_AWIDTH             : integer := 10
    );
    port(
        Rst                         : in  std_logic;
        clk                         : in  std_logic;
        enable                      : in  std_logic;
        DOA                         : out std_logic_vector(15 downto 0);
        DOB                         : out std_logic_vector(15 downto 0);
        ADDRA                       : in  std_logic_vector(RAMB_S18_AWIDTH-1 downto 0);
        ADDRB                       : in  std_logic_vector(RAMB_S18_AWIDTH-1 downto 0)
    );
end entity translation_ROM;

architecture rtl of translation_ROM is

    signal DOA_tmp                  : std_logic_vector(15 downto 0);
    signal DOB_tmp                  : std_logic_vector(15 downto 0);

    begin
    
    DOA <= DOA_tmp;
    DOB <= DOB_tmp;
    
    bytecode_translation_ROM : RAMB16_S18_S18
    generic map(
        -- opd_num(4bit) is_complex(4bit) semitranslated_code(1byte)
            -- INIT_00 => X"0102" & -- X"0F" =>   , modified by fox
    		INIT_00 => 
                   X"0001" &      -- X"0F" =>    dconst_1     >>  ldimm_1
                   --X"0100" &      -- X"0E" =>    , modified by fox
                   X"0000" &      -- X"0E" =>    dconst_0     >> ldimm_0
                   X"0009" &      -- X"0D" =>    fconst_2     => ldimm_9
                   X"0008" &      -- X"0C" =>    fconst_1     => ldimm_8
                   X"0000" &      -- X"0B" =>    fconst_0     => ldimm_0
                    -- modified by fox -- 2013.7.26 
                   X"0001" &      -- X"0A" =>    lconst_1      >>  ldimm_1
                   X"0000" &      -- X"09" =>    lconst_0       >> ldimm_0
                   X"0005" &      -- X"08" =>    iconst_5     => ldimm_5
                   X"0004" &      -- X"07" =>    iconst_4     => ldimm_4
                   X"0003" &      -- X"06" =>    iconst_3     => ldimm_3
                   X"0002" &      -- X"05" =>    iconst_2     => ldimm_2
                   X"0001" &      -- X"04" =>    iconst_1     => ldimm_1
                   X"0000" &      -- X"03" =>    iconst_0     => ldimm_0
                   X"000C" &      -- X"02" =>    iconst_m1    => ldimm_12
                   X"0000" &      -- X"01" =>    aconst_null  => ldimm_0
                   X"00FF",       -- X"00" =>    nop          => nop    
                   
    		INIT_01 => 
                   X"0019" &      -- X"1F" =>    lload_1      >> Translation address is X"04"
                   X"0018" &      -- X"1E" =>    lload_0      >> Translation address is X"03"
                   X"001B" &      -- X"1D" =>    iload_3      => ldval_3       --verified
                   X"001A" &      -- X"1C" =>    iload_2      => ldval_2       --verified
                   X"0019" &      -- X"1B" =>    iload_1      => ldval_1       --verified
                   X"0018" &      -- X"1A" =>    iload_0      => ldval_0       --verified
                   X"1010" &      -- X"19" =>    aload        => ldval_opd
                   X"1010" &      -- X"18" =>    dload        => ldval_opd
                   X"1010" &      -- X"17" =>    fload        => ldval_opd
                   X"1010" &      -- X"16" =>    lload        => ldval_opd
                   X"1010" &      -- X"15" =>    iload        => ldval_opd
                   X"3114" &      -- X"14" =>    ldc2_w       => 
                   X"3114" &      -- X"13" =>    ldc_w        =>  
                   X"1110" &      -- X"12" =>    ldc          =>  
                   X"3028" &      -- X"11" =>    sipush       => ldopd2
                   X"1020",       -- X"10" =>    bipush       => ldopd  
                   
    		INIT_02 => 
                   X"01C9" &      -- X"2F" =>    laload       => not implement
                   X"01C9" &      -- X"2E" =>    iaload       => iaload
                   X"001B" &      -- X"2D" =>    aload_3      => ldval_3       --verified
                   X"001A" &      -- X"2C" =>    aload_2      => ldval_2       --verified
                   X"0019" &      -- X"2B" =>    aload_1      => ldval_1       --verified 
                   X"0018" &      -- X"2A" =>    aload_0      => ldval_0       --verified
                   X"001B" &      -- X"29" =>    dload_3      >> Translation address is X"06"
                   X"001A" &      -- X"28" =>    dload_2      >> Translation address is X"05"
                   X"0019" &      -- X"27" =>    dload_1      >> Translation address is X"04"
                   X"0018" &      -- X"26" =>    dload_0      >> Translation address is X"03"
                   X"001B" &      -- X"25" =>    fload_3      => ldval_3       --verified
                   X"001A" &      -- X"24" =>    fload_2      => ldval_2       --verified
                   X"0019" &      -- X"23" =>    fload_1      => ldval_1       --verified
                   X"0018" &      -- X"22" =>    fload_0      => ldval_0       --verified 
                   X"001B" &      -- X"21" =>    lload_3      >> Translation address is X"06"
                   X"001A",       -- X"20" =>    lload_2      >> Translation address is X"05"
                   
    		INIT_03 =>
                   X"0058" &      -- X"3F" =>    lstore_0     >> Translation address is X"07"
                   X"005B" &      -- X"3E" =>    istore_3     => stval_3       --verified
                   X"005A" &      -- X"3D" =>    istore_2     => stval_2       --verified
                   X"0059" &      -- X"3C" =>    istore_1     => stval_1       --verified
                   X"0058" &      -- X"3B" =>    istore_0     => stval_0       --verified
                   X"1050" &      -- X"3A" =>    astore       => stval_opd
                   X"1050" &      -- X"39" =>    dstore       => not implement
                   X"1050" &      -- X"38" =>    fstore       => stval_opd
                   X"1050" &      -- X"37" =>    lstore       => not implement
                   X"1050" &      -- X"36" =>    istore       => stval_opd
                   X"01CB" &      -- X"35" =>    saload       => 
                   X"01CB" &      -- X"34" =>    caload       => 				-- modified by C.C. Hsu
                   X"01CA" &      -- X"33" =>    baload       => 
                   X"01C9" &      -- X"32" =>    aaload       => 
                   X"01C9" &      -- X"31" =>    daload       => not implement
                   X"01C9",       -- X"30" =>    faload       => not implement
                       		
    		INIT_04 => 
                   X"014A" &      -- X"4F" =>    iastore      >> Translation address is X"11"
                   X"005B" &      -- X"4E" =>    astore_3     => stval_3       --verified
                   X"005A" &      -- X"4D" =>    astore_2     => stval_2       --verified
                   X"0059" &      -- X"4C" =>    astore_1     => stval_1       --verified
                   X"0058" &      -- X"4B" =>    astore_0     => stval_0       --verified
                   X"005B" &      -- X"4A" =>    dstore_3     >> Translation address is X"0A"
                   X"005A" &      -- X"49" =>    dstore_2     >> Translation address is X"09"
                   X"0059" &      -- X"48" =>    dstore_1     >> Translation address is X"08"
                   X"0058" &      -- X"47" =>    dstore_0     >> Translation address is X"07"_
                   X"005B" &      -- X"46" =>    fstore_3     => stval_3       --verified
                   X"005A" &      -- X"45" =>    fstore_2     => stval_2       --verified
                   X"0059" &      -- X"44" =>    fstore_1     => stval_1       --verified
                   X"0058" &      -- X"43" =>    fstore_0     => stval_0       --verified
                   X"005B" &      -- X"42" =>    lstore_3     >> Translation address is X"0A"
                   X"005A" &      -- X"41" =>    lstore_2     >> Translation address is X"09"
                   X"0059",       -- X"40" =>    lstore_1     >> Translation address is X"08"   
                     		 
    		INIT_05 =>
                   X"01CF" &      -- X"5F" =>    swap  
                   X"00FE" &      -- X"5E" =>    dup2_x2      => not implement
                   X"00FE" &      -- X"5D" =>    dup2_x1      => not implement
                   X"01CE" &      -- X"5C" =>    dup2        
                   X"01CD" &      -- X"5B" =>    dup_x2    
                   X"01CC" &      -- X"5A" =>    dup_x1     
                   X"0038" &      -- X"59" =>    dup           
                   X"010E" &      -- X"58" =>    pop2  
                   X"0078" &      -- X"57" =>    pop           
                   X"014C" &      -- X"56" =>    sastore      => 
                   X"014C" &      -- X"55" =>    castore      =>  -- modified by C.C. Hsu , refine the structure inside string object
                   X"014E" &      -- X"54" =>    bastore      => 
                   X"014A" &      -- X"53" =>    aastore      => 
                   X"014A" &      -- X"52" =>    dastore      => not implement 
                   X"014A" &      -- X"51" =>    fastore      => not implement
                   X"014A",       -- X"50" =>    lastore      => not implement    
                   		
    		INIT_06 => 
                   X"008A" &      -- X"6F" =>    ddiv         => not implement
                   X"008A" &      -- X"6E" =>    fdiv         => not implement
                   X"008A" &      -- X"6D" =>    ldiv         => not implement
                   X"008A" &      -- X"6C" =>    idiv         => div				  
                   X"0089" &      -- X"6B" =>    dmul         => not implement
                   X"0089" &      -- X"6A" =>    fmul         => not implement
                   X"0089" &      -- X"69" =>    lmul         => not implement
                   X"0089" &      -- X"68" =>    imul         => mul
                   X"0087" &      -- X"67" =>    dsub         => not implement
                   X"0087" &      -- X"66" =>    fsub         => not implement
                   X"0087" &      -- X"65" =>    lsub         => not implement
                   X"0087" &      -- X"64" =>    isub         => sub
                   X"0084" &      -- X"63" =>    dadd         => not implement
                   X"0084" &      -- X"62" =>    fadd         => not implement 
                   X"0084" &      -- X"61" =>    ladd         => not implement
                   X"0084",       -- X"60" =>    iadd         => add

    		INIT_07 => 
                   X"0083" &      -- X"7F" =>    land         => not implement
                   X"0083" &      -- X"7E" =>    iand         => and
                   X"008C" &      -- X"7D" =>    lushr        => not implement
                   X"008C" &      -- X"7C" =>    ushr         => ushr
                   X"008E" &      -- X"7B" =>    lshr         => not implement
                   X"008E" &      -- X"7A" =>    ishr         => shr
                   X"008D" &      -- X"79" =>    lshl         => not implement
                   X"008D" &      -- X"78" =>    ishl         => shl
                   X"010F" &      -- X"77" =>    dneg         => not implement
                   X"010F" &      -- X"76" =>    fneg         => not implement
                   X"010F" &      -- X"75" =>    lneg         => not implement
                   X"010F" &      -- X"74" =>    ineg         => 
                   X"008B" &      -- X"73" =>    drem         => not implement
                   X"008B" &      -- X"72" =>    frem         => not implement 
                   X"008B" &      -- X"71" =>    lrem         => not implement
                   X"008B",       -- X"70" =>    irem         => rem

    		INIT_08 =>
                   X"00FE" &      -- X"8F" =>    d2l          => not implement
                   X"00FE" &      -- X"8E" =>    d2i          => not implement
                   X"00FE" &      -- X"8D" =>    f2d          => not implement
                   X"00FE" &      -- X"8C" =>    f2l          => not implement
                   X"00FE" &      -- X"8B" =>    f2i          => not implement
                   X"00FE" &      -- X"8A" =>    l2d          => not implement
                   X"00FE" &      -- X"89" =>    l2f          => not implement
                   X"0078" &      -- X"88" =>    l2i          => not implement
                   X"00FE" &      -- X"87" =>    i2d          => not implement
                   X"00FE" &      -- X"86" =>    i2f          => not implement
                   X"00FE" &      -- X"85" =>    i2l          => not implement
                   X"312C" &      -- X"84" =>    iinc         
                   X"0082" &      -- X"83" =>    lxor         => not implement
                   X"0082" &      -- X"82" =>    ixor         => xor
                   X"0081" &      -- X"81" =>    lor          => not implement
                   X"0081",       -- X"80" =>    ior          => or

    		INIT_09 => 
                   X"3106" &      -- X"9F" =>    if_icmpeq    => if_cmpeq
                   X"3105" &      -- X"9E" =>    ifle         
                   X"3104" &      -- X"9D" =>    ifgt         
                   X"3103" &      -- X"9C" =>    ifge         
                   X"3102" &      -- X"9B" =>    iflt         
                   X"3101" &      -- X"9A" =>    ifne         
                   X"3100" &      -- X"99" =>    ifeq         
                   X"00FE" &      -- X"98" =>    dcmpg        => not implement
                   X"00FE" &      -- X"97" =>    dcmpl        => not implement
                   X"00FE" &      -- X"96" =>    fcmpg        => not implement
                   X"00FE" &      -- X"95" =>    fcmpl        => not implement
                   X"00FE" &      -- X"94" =>    lcmp         => not implement
                   X"00FE" &      -- X"93" =>    i2s          => not implement
                   X"00FE" &      -- X"92" =>    i2c          => not implement 
                   X"00FE" &      -- X"91" =>    i2b          => not implement
                   X"00FE",       -- X"90" =>    d2f          => not implement

    		INIT_0A => 
                   X"0177" &      -- X"AF" =>    dreturn      => Translation address is X"78"
                   X"0177" &      -- X"AE" =>    freturn      => Translation address is X"78"
                   X"0177" &      -- X"AD" =>    lreturn      => Translation address is X"78"
                   X"0177" &      -- X"AC" =>    ireturn      => Translation address is X"78" 
                   X"F180" &      -- X"AB" =>    lookupswith  
                   X"F160" &      -- X"AA" =>    tableswitch 
                   X"10FE" &      -- X"A9" =>    ret          => not implement
                   X"30FE" &      -- X"A8" =>    jsr          => not implement
                   X"316F" &      -- X"A7" =>    goto         => goto
                   X"310D" &      -- X"A6" =>    if_acmpne    => if_cmpne
                   X"310C" &      -- X"A5" =>    if_acmpeq    => if_cmpeq
                   X"310B" &      -- X"A4" =>    if_icmple    => if_cmple
                   X"310A" &      -- X"A3" =>    if_icmpgt    => if_cmpgt
                   X"3109" &      -- X"A2" =>    if_icmpge    => if_cmpge
                   X"3108" &      -- X"A1" =>    if_icmplt    => if_cmplt
                   X"3107",       -- X"A0" =>    if_icmpne    => if_cmpne

    		INIT_0B => 
                   --X"F0E7" &      -- X"BF" =>    athrow   
                   X"F16C" &      -- X"BF" =>    athrow   
                   X"012E" &      -- X"BE" =>    arraylength     
                   X"3118" &      -- X"BD" =>    anewarray      => 
                   X"111D" &      -- X"BC" =>    newarray       => newarray
                   X"3140" &      -- X"BB" =>    new            => Translation address is X"40"
                   X"00FE" &      -- X"BA" =>    (null)
                   X"F1C0" &      -- X"B9" =>    invokeinterface=> Translation address is X"C0"
                   X"31A0" &      -- X"B8" =>    invokestatic   => Translation address is X"B0"
                   X"31B0" &      -- X"B7" =>    invokespecial  => Translation address is X"B0"
                   X"31D0" &      -- X"B6" =>    invokevirtual  => Translation address is X"B0"
                   X"3145" &      -- X"B5" =>    putfield       => Translation address is X"60"
                   X"3124" &      -- X"B4" =>    getfield       => Translation address is X"90"
                   X"3128" &      -- X"B3" =>    putstatic      => Translation address is X"60"
                   X"3120" &      -- X"B2" =>    getstatic      => Translation address is X"90"
                   X"0170" &      -- X"B1" =>    return         => Translation address is X"70"
                   X"0177",       -- X"B0" =>    areturn        => Translation address is X"C0"

    		INIT_0C =>
                   X"00FE" &      -- X"CF" =>    (null)
                   X"00FE" &      -- X"CE" =>    (null)
                   X"00FE" &      -- X"CD" =>    (null)
                   X"00FE" &      -- X"CC" =>    (null)
                   X"00FE" &      -- X"CB" =>    (null)
                   X"00FE" &      -- X"CA" =>    breakpoint     => not implement
                   X"F0FE" &      -- X"C9" =>    jsr_w          => not implement
                   X"F0FE" &      -- X"C8" =>    goto_w         => not implement
                   X"316E" &      -- X"C7" =>    ifnonnull      => not implement
                   X"316D" &      -- X"C6" =>    ifnull         => not implement 
                   X"7190" &      -- X"C5" =>    multianewarray  -- implemented by using ISR , by fox
                   X"00FE" &      -- X"C4" =>    wide           => not implement
                   X"0199" &      -- X"C3" =>    monitorexit     
                   --X"0078" &      -- X"C3" =>    monitorexit     
                   X"0194" &      -- X"C2" =>    monitorenter   
                   --X"0078" &      -- X"C2" =>    monitorenter   
                   X"30FE" &      -- X"C1" =>    instanceof     => not implement
                   X"30FF",       -- X"C0" =>    checkcast      => not implement
						 
         INIT_0D =>X"00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE00FE",	
         
         INIT_0E =>X"F0FE" &      -- X"EF" =>
                   X"00FE" &      -- X"EE" =>
                   X"00FE" &      -- X"ED" =>
                   X"00FE" &      -- X"EC" =>
                   X"00FE" &      -- X"EB" =>
                   X"00FE" &      -- X"EA" =>
                   X"00FE" &      -- X"E9" =>
                   X"00FE" &      -- X"E8" =>
                   X"00FE" &      -- X"E7" =>
                   X"00FE" &      -- X"E6" => 
                   X"00FE" &      -- X"E5" =>
                   X"00FE" &      -- X"E4" =>
                   X"00FE" &      -- X"E3" =>    
                   X"00FE" &      -- X"E2" =>    
                   X"00FE" &      -- X"E1" =>   
                   X"00FE"        -- X"E0" =>	 
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