-- trilobot_entity.vhd: Trilobot driver entity
-- Copyright (C) 2009 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Michal Růžek <xruzek01 AT stud.fit.vutbr.cz>
-- 
-- LICENSE TERMS
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in
--    the documentation and/or other materials provided with the
--    distribution.
-- 3. All advertising materials mentioning features or use of this software
--    or firmware must display the following acknowledgement: 
--
--      This product includes software developed by the University of
--      Technology, Faculty of Information Technology, Brno and its 
--      contributors. 
--
-- 4. Neither the name of the Company nor the names of its contributors
--    may be used to endorse or promote products derived from this
--    software without specific prior written permission.
-- 
-- This software or firmware is provided ``as is'', and any express or implied
-- warranties, including, but not limited to, the implied warranties of
-- merchantability and fitness for a particular purpose are disclaimed.
-- In no event shall the company or contributors be liable for any
-- direct, indirect, incidental, special, exemplary, or consequential
-- damages (including, but not limited to, procurement of substitute
-- goods or services; loss of use, data, or profits; or business
-- interruption) however caused and on any theory of liability, whether
-- in contract, strict liability, or tort (including negligence or
-- otherwise) arising in any way out of the use of this software, even
-- if advised of the possibility of such damage.
-- 
-- $Id$
-- 
--  
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;


entity SDCARD is
    port ( 
        -- Reset a synchronizace
        RESET     : in std_logic;
        CLK     : in std_logic;
        -- Datova a adresova sbernice
        DATA_IN  : in std_logic_vector(7 downto 0);
        DATA_OUT : out std_logic_vector(7 downto 0);
        ADDR     : in std_logic_vector(2 downto 0);
        WRITE_EN : in std_logic;
        READ_EN  : in std_logic;
        WAIT_n   : out std_logic;
        ACK      : out std_logic;
        -- Rozhrani SD karty
        SD_CLK   : out std_logic;
        SD_CS    : out std_logic;
        SD_MOSI  : out std_logic;
        SD_MISO  : in std_logic
    );
end SDCARD;


architecture behav of sdcard is

    -- SPI
    component spi
    port ( 
        -- Reset a synchronizace
        RESET    : in std_logic;
        CLK      : in std_logic;
          
        -- Datova a adresova sbernice
        DATA_IN  : in std_logic_vector(7 downto 0);
        DATA_OUT : out std_logic_vector(7 downto 0);
        WRITE_EN : in std_logic;
        READY    : out std_logic;
                          
        -- Rozhrani SD karty
        SCLK     : out std_logic;
        MOSI     : out std_logic;
        MISO     : in std_logic
    );
    end component;
    
    signal spi_data_out     : std_logic_vector(7 downto 0);
    signal spi_data_in      : std_logic_vector(7 downto 0);
    signal spi_write_en     : std_logic;
    signal spi_ready        : std_logic;
    signal spi_ready_out    : std_logic;
    signal spi_sd_data_out  : std_logic;
    
    signal spi_data_out_00  : std_logic;
    signal spi_data_out_01  : std_logic;
    signal spi_data_out_FF  : std_logic;

    -- zbytek
    signal count       : std_logic_vector(8 downto 0);
    signal count_rst   : std_logic;
    signal count_inc   : std_logic;
    signal count_FF    : std_logic;
    
    signal reg0             : std_logic_vector(5 downto 0);    
    signal reg1             : std_logic_vector(7 downto 0);
    signal reg2             : std_logic_vector(7 downto 0);
    signal reg3             : std_logic_vector(7 downto 0);
    signal reg4             : std_logic_vector(7 downto 0);
    signal reg_rst          : std_logic;

--    signal status               : std_logic_vector(7 downto 0); -- status registr
    signal control              : std_logic_vector(7 downto 0); -- ridici registr

    type tstate is (S_AAA, S_RESET, S_RESET2, S_RESET3,
    S_CMD0, S_CMD0_2, S_CMD0_R1, S_CMD0_R1_test, S_CMD0_R1_test2,
    S_CMD1, S_CMD1_2, S_CMD1_R1, S_CMD1_R1_test, S_CMD1_R1_test2,
    S_CMD17, S_CMD17_2, S_CMD17_R1, S_CMD17_R1_test, S_CMD17_START, S_CMD17_STARTtest, S_CMD17_R1_test2,
    S_READ, S_READ_test,
    S_CRC1, S_CRC1a, S_CRC2, S_CRC2a,    
    S_READY, S_HALT);
    signal present_state, next_state : tstate;




    
    type tcmdstate is (S_CMD, S_CMDa, S_CMD_2, S_CMD_2a, S_CMD_3, S_CMD_3a, S_CMD_4, S_CMD_4a, S_CMD_5, S_CMD_5a, S_CMD_6, S_CMD_6a, S_R1, S_R1a, SS_READY);
    signal cmd_present, cmd_next : tcmdstate;
    
    signal cmd_ready        : std_logic;
    signal cmd_r1           : std_logic;
    signal cmd_command      : std_logic;
    
    signal command0         : std_logic_vector(7 downto 0);
    signal command1         : std_logic_vector(7 downto 0);
    signal command2         : std_logic_vector(7 downto 0);
    signal command3         : std_logic_vector(7 downto 0);
    signal command4         : std_logic_vector(7 downto 0);

    signal clk_div               : std_logic;  
    signal clk_div_reg           : std_logic_vector(3 downto 0);
   

begin

    process(RESET,CLK)
    begin
        if RESET='1' then
            CLK_DIV_reg <= (others=>'0');
        elsif CLK'event and CLK='1' then
            CLK_DIV_reg <= clk_div_reg + 1;
        end if;
    end process;
    
    clk_div <= clk_div_reg(1);

	karta_spi : spi
	port map (
        RESET       => RESET,
        CLK         => clk_div,
          
        -- Datova a adresova sbernice
        DATA_IN     => spi_data_in,
        DATA_OUT    => spi_data_out,
        WRITE_EN    => spi_write_en,
        READY       => spi_ready_out,
          
        -- Rozhrani SD karty
        SCLK        => SD_CLK,
        MOSI        => spi_sd_data_out,
        MISO        => SD_MISO
	);
	
	process(CLK)
	begin
	   if CLK'event and CLK='1' then
	       spi_ready <= spi_ready_out;
	   end if;
	end process;
	
	-- pokud neni povoleno odesilani, pripojim na vystup log 1
    SD_MOSI <= spi_sd_data_out;

    -- zapis do registru
    process(CLK, reg_rst)
    begin
        if reg_rst='1' then
            control <= (others=>'0');
        elsif CLK'event and CLK='1' then
            if WRITE_EN='1' then
                case ADDR is
                    when "000" => reg0 <= DATA_IN(5 downto 0);  -- Prikaz
                    when "001" => reg1 <= DATA_IN;  -- Argument nejvyssi bajt
                    when "010" => reg2 <= DATA_IN;
                    when "011" => reg3 <= DATA_IN;
                    when "100" => reg4 <= DATA_IN;  -- Argument nejnizsi bajt
                    when "101" => control <= DATA_IN;   -- ridici registr
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    DATA_OUT <= spi_data_out;
    --adresovy dekoder na vystupu
--    with ADDR select
--        DATA_OUT <= "00" & reg0 when "000",
--                    reg1 when "001",
--                    reg2 when "010",
--                    reg3 when "011",
--                    reg4 when "100",
--                    control when "101",
--                    status when "110",
--                    spi_data_out when others;

--------------------------------------------------------------------------------
-- komunikace s SPI jednotkou

    SD_SPI_FSM: process(cmd_present, cmd_command, cmd_r1, command0, spi_ready, command1, command2, command3, command4) 
    begin
        spi_data_in <= "00000000";
        spi_write_en <= '0';
        cmd_ready <= '0';        

        case cmd_present is

            when SS_READY =>
                cmd_ready <= '1';
                cmd_next<= SS_READY;
                if cmd_command='1' then
                    cmd_next <= S_CMD;
                elsif cmd_r1='1' then
                    cmd_next <= S_R1;
                end if;
            
            
            when S_CMD =>  -- kod prikazu
                spi_data_in <= command0;
                spi_write_en <= '1';
                cmd_next <= S_CMD;
                if spi_ready='0' then
                    cmd_next <= S_CMDa;
                end if;
            when S_CMDa =>
                cmd_next <= S_CMDa;
               
                if spi_ready='1' then
                    cmd_next <= S_CMD_2;
                end if;

            when S_CMD_2 =>  -- druhy bajt 4. cast adresy
                spi_data_in <= command1;
                spi_write_en <= '1';
                cmd_next <= S_CMD_2;
                if spi_ready='0' then
                    cmd_next <= S_CMD_2a;
                end if;
            when S_CMD_2a =>
                cmd_next <= S_CMD_2a;
                if spi_ready='1' then
                    cmd_next <= S_CMD_3;
                end if;

            when S_CMD_3 =>  -- treti bajt 3. cast adresy
                spi_data_in <= command2;
                spi_write_en <= '1';
                cmd_next <= S_CMD_3;
                if spi_ready='0' then
                    cmd_next <= S_CMD_3a;
                end if;
            when S_CMD_3a =>
                cmd_next <= S_CMD_3a;
                if spi_ready='1' then
                    cmd_next <= S_CMD_4;
                end if;

            when S_CMD_4 =>  -- ctvrty bajt 2. cast adresy
                spi_data_in <= command3;
                spi_write_en <= '1';
                cmd_next <= S_CMD_4;                
                if spi_ready='0' then
                    cmd_next <= S_CMD_4a;
                end if;
            when S_CMD_4a =>
                cmd_next <= S_CMD_4a;                
                if spi_ready='1' then
                    cmd_next <= S_CMD_5;
                end if;

            when S_CMD_5 =>  -- paty bajt 1. cast adresy
                spi_data_in <= command4;
                spi_write_en <= '1';
                cmd_next <= S_CMD_5;
                if spi_ready='0' then
                    cmd_next <= S_CMD_5a;
                end if;
            when S_CMD_5a =>
                cmd_next <= S_CMD_5a;
                if spi_ready='1' then
                    cmd_next <= S_CMD_6;
                end if;

            when S_CMD_6 =>  -- sesty bajt (CRC)
                spi_data_in <= X"95";
                spi_write_en <= '1';
                cmd_next <= S_CMD_6;
                if spi_ready='0' then
                    cmd_next <= S_CMD_6a;
                end if;
            when S_CMD_6a =>
                cmd_next <= S_CMD_6a;
                if spi_ready='1' then
                    cmd_next <= SS_READY;
                end if;


            -- cekam na odpoved R1 nebo pouze prijimam nejaky bajt a odesilam "FF"
            when S_R1 =>
                spi_data_in <= X"FF";
                spi_write_en <= '1';
                cmd_next <= S_R1;
                if spi_ready='0' then
                    cmd_next <= S_R1a;
                end if;
            when S_R1a =>
                cmd_next <= S_R1a;
                if spi_ready='1' then
                    cmd_next <= SS_READY;
                end if;

            when others =>
                cmd_next <= SS_READY;
                
        end case;
    end process;

    -- prepinani stavu FSM
    process(RESET,CLK)
    begin
        if RESET='1' then
            cmd_present <= SS_READY;
        elsif CLK'event and CLK='1' then
            cmd_present <= cmd_next;
        end if;
    end process;

--------------------------------------------------------------------------------

    -- registr pocitadlo
    process (count_rst,CLK)
    begin
        if count_rst='1' then
            count <= (others=>'0');
        elsif CLK'event and CLK='1' then
            if count_inc='1' then
                count <= count + 1;             
            end if;
        end if;
    end process;
    
    count_FF <= '1' when count="111111111" else '0';
    spi_data_out_00 <= '1' when spi_data_out=X"00" else '0';
    spi_data_out_01 <= '1' when spi_data_out=X"01" else '0';
    spi_data_out_FF <= '1' when spi_data_out=X"FF" else '0';

    SD_FSM : process (present_state, count, reg0,reg1,reg2,reg3,reg4,spi_data_out,cmd_ready, control, count_FF, spi_data_out_01, spi_data_out_00, spi_data_out_FF, READ_EN)
    begin
        SD_CS  <= '1';
        count_rst <= '0';
        count_inc <= '0';
        reg_rst <= '0';
        cmd_command <= '0';
        cmd_r1 <= '0';
        command0 <= (others=>'1');
        command1 <= (others=>'1');
        command2 <= (others=>'1');
        command3 <= (others=>'1');
        command4 <= (others=>'1');
--        status <= X"00";
        WAIT_n <= '1';
        ACK <= '0';

        case present_state is
            when S_AAA =>
--                status <= X"01";
                count_rst <= '1';
                reg_rst <= '1';
                next_state <= S_RESET;
                
            -- po resetu musim pockat minimalne 74 taktu, nez prejdu do dalsiho stavu
            when S_RESET =>
--                status <= X"02";
                cmd_r1 <= '1';
                next_state <= S_RESET;
                if cmd_ready='0' then
                    next_state <= S_RESET2;
                end if;

            when S_RESET2 =>
--                status <= X"03";
                next_state <= S_RESET2;
                if cmd_ready='1' then
                    next_state <= S_RESET3;
                end if;
            when S_RESET3 =>
--                status <= X"04";
                count_inc <= '1';
                next_state <= S_RESET;            
                if count_FF='1' then
                    next_state <= S_CMD0;
                end if;
                            
            
            --------------------------------------------------------------------
            -- prikaz CMD0 - softwarovy reset
            when S_CMD0 =>
--                status <= X"05";
                SD_CS <= '0';
                cmd_command <= '1';
                command0 <= X"40";
                command1 <= X"00";
                command2 <= X"00";
                command3 <= X"00";
                command4 <= X"00";
                next_state <= S_CMD0;
                if cmd_ready='0' then
                    next_state <= S_CMD0_2;
                end if;
            -- cekam na dokonceni odesilani
            when S_CMD0_2 =>
--                status <= X"06";
                SD_CS <= '0';
                command0 <= X"40";
                command1 <= X"00";
                command2 <= X"00";
                command3 <= X"00";
                command4 <= X"00";
                next_state <= S_CMD0_2;
                if cmd_ready='1' then
                    next_state <= S_CMD0_R1;
                end if;
            -- prijmu odpoved R1                
            when S_CMD0_R1 =>
--                status <= X"07";
                SD_CS <= '0';
                cmd_r1 <= '1';
                next_state <= S_CMD0_R1;
                if cmd_ready='0' then
                    next_state <= S_CMD0_R1_test;
                end if;
            -- vyhodnotim odpoved R1
            when S_CMD0_R1_test =>
--                status <= X"08";
                SD_CS <= '0';
                next_state <= S_CMD0_R1_test;
                if cmd_ready='1' then
                    next_state <= S_CMD0_R1_test2;
                end if;
            when S_CMD0_R1_test2 =>
                next_state <= s_CMD0_R1;
                if spi_data_out_01='1' then -- jsem v iddle stavu
                    next_state <= S_CMD1;
                end if;


            --------------------------------------------------------------------
            -- prikaz CMD1 - inicializace karty
            when S_CMD1 =>
---                status <= X"09";
                SD_CS <= '0';
                cmd_command <= '1';
                command0 <= X"41";
                command1 <= X"00";
                command2 <= X"00";
                command3 <= X"00";
                command4 <= X"00";
                next_state <= S_CMD1;
                if cmd_ready='0' then
                    next_state <= S_CMD1_2;
                end if;
            --cekam na dokonceni odesilani
            when S_CMD1_2 =>
--                status <= X"0A";
                SD_CS <= '0';
                command0 <= X"41";
                command1 <= X"00";
                command2 <= X"00";
                command3 <= X"00";
                command4 <= X"00";
                next_state <= S_CMD1_2;
                if cmd_ready='1' then
                    next_state <= S_CMD1_R1;
                end if;
            -- prijmu odpoved R1
            when S_CMD1_R1 =>
--                status <= X"0B";
                SD_CS <= '0';
                cmd_r1 <= '1';
                next_state <= S_CMD1_R1;
                if cmd_ready='0' then
                    next_state <= S_CMD1_R1_test;
                end if;
            -- vyhodnotim odpoved R1                 
            when S_CMD1_R1_test =>
--                status <= X"0C";
                SD_CS <= '0';
                next_state <= S_CMD1_R1_test;
                if cmd_ready='1' then
                    next_state <= S_CMD1_R1_test2;
                end if;
            when S_CMD1_R1_test2 =>                
                next_state <= S_CMD1_R1;
                if spi_data_out_00='1' then
                    next_state <= S_READY;
                elsif spi_data_out_01='1' then
                    next_state <= S_CMD1;
                end if;
            --------------------------------------------------------------------
            -- prikaz CMD17 - cteni z karty
            when S_CMD17 =>
--                status <= X"0D";
                reg_rst <= '1'; -- vymazu prikaz z registru, aby se po dokonceni znovu nespustil
                SD_CS <= '0';
                cmd_command <= '1';
                command0 <= "01" & reg0;
                command1 <= reg1;
                command2 <= reg2;
                command3 <= reg3;
                command4 <= reg4;
                next_state <= S_CMD17;
                if cmd_ready='0' then
                    next_state <= S_CMD17_2;
                end if;
            --cekam na dokonceni odesilani
            when S_CMD17_2 =>
--                status <= X"0E";
                SD_CS <= '0';
                command0 <= "01" & reg0;
                command1 <= reg1;
                command2 <= reg2;
                command3 <= reg3;
                command4 <= reg4;
                next_state <= S_CMD17_2;
                if cmd_ready='1' then
                    next_state <= S_CMD17_R1;
                end if;
           -- prijmu odpoved R1
            when S_CMD17_R1 =>
--                status <= X"0F";
                SD_CS <= '0';
                cmd_r1 <= '1';
                next_state <= S_CMD17_R1;
                if cmd_ready='0' then
                    next_state <= S_CMD17_R1_test;
                end if;
            -- vyhodnotim odpoved R1                 
            when S_CMD17_R1_test =>
--                status <= X"10";
                SD_CS <= '0';
                next_state <= S_CMD17_R1_test;
                if cmd_ready='1' then
                    next_state <= S_CMD17_R1_test2;
                end if;
            when S_CMD17_R1_test2 =>
                next_state <= S_READY;
                if spi_data_out_FF='1' then -- zatim jsem nedostal odpoved
                    next_state <= S_CMD17_R1;
                end if;


            when S_READ =>
                WAIT_n <= '0';
--                status <= X"11";
                SD_CS <= '0';
                cmd_r1 <= '1';  -- prijmu jeden bajt
                reg_rst <= '1'; -- vymazu prikaz z registru, aby se po dokonceni znovu nespustil
                next_state <= S_READ;
                if cmd_ready='0' then
                    next_state <= S_READ_test;
                end if;

            when S_READ_test =>
                WAIT_n <= '0';
--                status <= X"12";
                SD_CS <= '0';
                next_state <= S_READ_test;
                if cmd_ready='1' then
                    next_state <= S_READY;
                    ACK <= '1';
                end if;
            

            -- Radic je volny a ceka na nejaky prikaz na vstupu. Akce se odstartuje zapisem do registru reg0
            when S_READY =>
--                status <= X"13";
                SD_CS <= '0';
                next_state <= S_READY;
                if control(0)='1' then   -- odeslat prikaz
                    next_state <= S_CMD17;
                elsif READ_EN='1' then   -- precte bajt
                    next_state <= S_READ;
                    WAIT_n <= '0';
                end if;


            when S_HALT =>
                next_state <= S_HALT;
              
            when others =>
                next_state <= S_HALT;
        end case;
    end process;



    -- prepinani stavu u FSM	
	process (RESET,CLK)
	begin
	   if RESET='1' then
	       present_state <= S_AAA;
	   elsif CLK'event and CLK='1' then
	       present_state <= next_state;
	   end if;
	end process;

end behav;
