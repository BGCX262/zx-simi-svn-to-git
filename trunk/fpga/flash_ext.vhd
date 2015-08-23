library IEEE;
Library UNISIM;
use UNISIM.vcomponents.all;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_ARITH.ALL;
use ieee.std_logic_UNSIGNED.ALL;

entity FLASH_EXT is
    port (
        CLK      : in  STD_LOGIC;
        RESET    : in  STD_LOGIC;
        WAIT_n   : out std_logic;
        -- externi FLASH
        MISO     : in std_logic;
        MOSI     : out std_logic;
        CSB      : out std_logic;
        SCLK     : out std_logic;
        -- rozhrani po komunikaci s pameti
        DATA_OUT : out  STD_LOGIC_VECTOR (7 downto 0);
        ADDR     : out  STD_LOGIC_VECTOR (22 downto 0);
        WR       : out  STD_LOGIC;
        ACK      : in   STD_LOGIC
    );
end FLASH_EXT;
 
architecture Behavioral of FLASH_EXT is

    component spi is
    Port (
        RESET    : in std_logic;
        CLK      : in std_logic;
        --
        DATA_IN  : in std_logic_vector(7 downto 0);
        DATA_OUT : out std_logic_vector(7 downto 0);
        WRITE_EN : in std_logic;
        READY    : out std_logic;
        -- SPI rozhrani
        MOSI     : out std_logic;
        MISO     : in  std_logic;
        SCLK     : out std_logic
    );
    end component;
    
    




    signal spi_data_in  : std_logic_vector(7 downto 0);
   
    signal ADDR_REG       : std_logic_vector(22 downto 0);
    signal ADDR_INC       : std_logic;
    signal ADDR_SET_TAP   : std_logic;
    
    signal spi_ready          : std_logic;
    signal spi_write_en   : std_logic;
    
    type t_state_flash is (S_RESET, S_START, S_CMD, S_CMD2, S_ADDR_HIGH, S_ADDR_HIGH2, S_ADDR_MIDDLE, S_ADDR_MIDDLE2, S_ADDR_LOW, S_ADDR_LOW2, S_DONT_CARE, S_DONT_CARE2, S_DATA, S_DATA2, S_DATA_WR, S_DONE);
	signal flash_present, flash_next : t_state_flash;

begin


	flash_spi : spi
	port map (
        RESET       => RESET,
        CLK         => CLK,
        -- Datova a adresova sbernice
        DATA_IN     => spi_data_in,
        DATA_OUT    => DATA_OUT,
        WRITE_EN    => spi_write_en,
        READY       => spi_ready,
        -- Rozhrani SD karty
        SCLK        => SCLK,
        MOSI        => MOSI,
        MISO        => MISO
	);


    ADDR <= ADDR_REG;

    



    -- adresa pameti
    process(RESET,CLK)
    begin
        if RESET='1' then
--          ADDR_REG <= "00000010100000000000000"; -- VRAM
            ADDR_REG <= "00000100000000000000000"; -- ROM
        elsif CLK'event and CLK='1' then
            if ADDR_INC='1' then
                ADDR_REG <= ADDR_REG + 1;
            end if;
        end if;
    end process;
    
    process(RESET,CLK)
    begin
        if RESET='1' then
            flash_present <= S_RESET;
        elsif CLK'event and CLK='1' then
            flash_present <= flash_next;
        end if;
    end process;
    
    process(flash_present, ADDR_REG, ACK, spi_ready) 
    begin
        CSB <= '0'; -- karta je aktivni
        spi_data_in <= X"00";
        WR <= '0';
        ADDR_INC <= '0';
        WAIT_n <= '0';
        spi_write_en <= '0';
        
        --adresy, ktere si odpovidaji
        --0x046
        --0x14A
        --adresy, ktere nefunguji
        --RAM: 29A  Radic: 392  rozdíl F8
        
        case flash_present is

            when S_RESET =>
                CSB <= '1'; -- karta neni aktivni
                flash_next <= S_START;
            
            when S_START =>
                flash_next<= S_CMD;
                
            -- prikaz FAST READ
            when S_CMD =>
                spi_data_in <= X"0B";
                spi_write_en <= '1';
                flash_next <= S_CMD;
                if spi_ready='0' then
                    flash_next <= S_CMD2;
                end if;
            
            when S_CMD2 =>
                flash_next <= S_CMD2;
                if spi_ready='1' then
                    flash_next <= S_ADDR_HIGH;
                end if;                

            -- page 1024 nejvyssi bajt                
            when S_ADDR_HIGH =>
                spi_data_in <= X"00";
                spi_write_en <= '1';
                flash_next <= S_ADDR_HIGH;
                if spi_ready='0' then
                    flash_next <= S_ADDR_HIGH2;
                end if;

            when S_ADDR_HIGH2 =>
                flash_next <= S_ADDR_HIGH2;
                if spi_ready='1' then
                    flash_next <= S_ADDR_MIDDLE;
                end if;

            -- page 1024 prostredni bajt
            when S_ADDR_MIDDLE =>
                spi_data_in <= X"00";
                spi_write_en <= '1';
                flash_next <= S_ADDR_MIDDLE;
                if spi_ready='0' then
                    flash_next <= S_ADDR_MIDDLE2;
                end if;

            when S_ADDR_MIDDLE2 =>
                flash_next <= S_ADDR_MIDDLE2;
                if spi_ready='1' then
                    flash_next <= S_ADDR_LOW;
                end if;

            -- page 1024 nejnizsi bajt
            when S_ADDR_LOW =>
                spi_data_in <= X"00";
                spi_write_en <= '1';
                flash_next <= S_ADDR_LOW;
                if spi_ready='0' then
                    flash_next <= S_ADDR_LOW2;
                end if;
            when S_ADDR_LOW2 =>
                flash_next <= S_ADDR_LOW2;
                if spi_ready='1' then
                    flash_next <= S_DONT_CARE;
                end if;

            -- don't care bajt           
            when S_DONT_CARE =>
                spi_write_en <= '1';
                flash_next <= S_DONT_CARE;
                if spi_ready='0' then
                    flash_next <= S_DONT_CARE2;
                end if;
            when S_DONT_CARE2 =>
                flash_next <= S_DONT_CARE2;
                if spi_ready='1' then
                    flash_next <= S_DATA;
                end if;

            -- cekam na nacteni celeho bajtu
            when S_DATA =>     
                flash_next <= S_DATA;
                if ADDR_REG = "00000111100000000000000" then -- ROM 32K
                    flash_next <= S_DONE;
                else
                    spi_write_en <= '1';
                    if spi_ready='0' then
                        flash_next <= S_DATA2;
                    end if;
                end if;
            when S_DATA2 =>     
                flash_next <= S_DATA2;
                if spi_ready='1' then -- bajt je kompletne nacten, muzu ho zapsat do SDRAM
                    flash_next <= S_DATA_WR;
                end if;
 
            -- zapis dat do SDRAM
            when S_DATA_WR =>
                flash_next <= S_DATA_WR;
                WR <= '1';
                if ACK='1' then
                    flash_next <= S_DATA;
                    ADDR_INC <= '1';
                end if;
                
            when S_DONE =>
                CSB <= '1';
                WAIT_n <= '1';
                flash_next <= S_DONE;
                
            when others =>
                flash_next <= S_RESET;
        end case;
    end process;

end Behavioral;

