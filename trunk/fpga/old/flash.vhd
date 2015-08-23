library IEEE;
Library UNISIM;
use UNISIM.vcomponents.all;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_ARITH.ALL;
use ieee.std_logic_UNSIGNED.ALL;

entity FLASH is
    port (
        CLK      : in  STD_LOGIC;
        RESET    : in  STD_LOGIC;
        WAIT_n   : out std_logic;
        -- rozhrani po komunikaci s pameti
        DATA_OUT : out  STD_LOGIC_VECTOR (7 downto 0);
        ADDR     : out  STD_LOGIC_VECTOR (22 downto 0);
        WR       : out  STD_LOGIC;
        ACK      : in   STD_LOGIC
    );
end FLASH;
 
architecture Behavioral of FLASH is

    signal MISO           : std_logic;
    signal MOSI           : std_logic;
    signal CSB            : std_logic;
    signal CLK_PAUSE      : std_logic;
    signal FLASH_CLK0     : std_logic;
    signal FLASH_CLK      : std_logic_vector(3 downto 0);
    signal FLASH_DATA_IN  : std_logic_vector(7 downto 0);
    signal DATA_OUT_REG : std_logic_vector(7 downto 0);
    
    signal ADDR_REG       : std_logic_vector(22 downto 0);
    signal ADDR_INC       : std_logic;
    
    signal READY          : std_logic;
    
    type t_state_flash is (S_RESET, S_START, S_CMD, S_ADDR_HIGH, S_ADDR_MIDDLE, S_ADDR_LOW, S_DONT_CARE, S_DATA, S_DATA_WR, S_DONE);
	signal flash_present, flash_next : t_state_flash;

begin

    ADDR <= ADDR_REG;
    DATA_OUT <= DATA_OUT_REG;
    
    FLASH_CLK0 <= FLASH_CLK(0);
    
    READY <= '1' when FLASH_CLK(3 downto 0)="1111" else '0';

    SPI_ACCESS_inst: SPI_ACCESS
    generic map (
        SIM_DEVICE => "3S400AN",
        SIM_MEM_FILE => "dizzy.hexa"
    )
    port map  (
        MISO => MISO,   -- 1-bit SPI output data
        MOSI => MOSI,   -- 1-bit SPI input data    
        CSB  => CSB,  -- 1-bit SPI chip enable
        CLK  => FLASH_CLK0   -- 1-bit SPI clock input
    );
    
   
    process(RESET,CLK)
    begin
        if RESET='1' then
            FLASH_CLK <= (others=>'1');
        elsif CLK'event and CLK='1' then
            if CLK_PAUSE='0' then
                FLASH_CLK <= FLASH_CLK + 1;
            end if;
        end if;
    end process;

    with FLASH_CLK(3 downto 1) select
        MOSI <= FLASH_DATA_IN(7) when "000",
                      FLASH_DATA_IN(6) when "001",
                      FLASH_DATA_IN(5) when "010",
                      FLASH_DATA_IN(4) when "011",
                      FLASH_DATA_IN(3) when "100",
                      FLASH_DATA_IN(2) when "101",
                      FLASH_DATA_IN(1) when "110",
                      FLASH_DATA_IN(0) when others;


    -- aktualne vysilany bit
--    process (CLK)
--    begin
--        if CLK'event and CLK='1' then
--            case FLASH_CLK(3 downto 0) is
--                when "0001" => MOSI <= FLASH_DATA_IN(7);
--                when "0011" => MOSI <= FLASH_DATA_IN(6);
--                when "0101" => MOSI <= FLASH_DATA_IN(5);
--                when "0111" => MOSI <= FLASH_DATA_IN(4);
--                when "1001" => MOSI <= FLASH_DATA_IN(3);
--                when "1011" => MOSI <= FLASH_DATA_IN(2);
--                when "1101" => MOSI <= FLASH_DATA_IN(1);
--                when "1111" => MOSI <= FLASH_DATA_IN(0);
--                when others => null;
--            end case;
--        end if;
--    end process;

    -- prijimani bajtu bit po bitu
    process(RESET,FLASH_CLK0)
    begin
        if RESET='1' then
            DATA_OUT_REG <= (others=>'0');
        elsif FLASH_CLK0'event and FLASH_CLK0='1' then
            DATA_OUT_REG <= DATA_OUT_REG(6 downto 0) & MISO;
        end if;
    end process;
    
    -- pokud je bajt nacten kompletne, tak ho ulozim do docasneho registru
--    process(CLK)
--    begin
--        if CLK'event and CLK='1' then
--            if FLASH_CLK(3 downto 0)="1111" then
--                DATA_OUT <= DATA_OUT_REG(7 downto 0);
--            end if;
--        end if;
--    end process;


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
    
    process(flash_present, FLASH_CLK, ADDR_REG, ACK, READY) 
    begin
        CSB <= '0'; -- karta je aktivni
        FLASH_DATA_IN <= X"00";
        WR <= '0';
        CLK_PAUSE <= '0';
        ADDR_INC <= '0';
        WAIT_n <= '0';
        
        --adresy, ktere si odpovidaji
        --0x046
        --0x14A
        --adresy, ktere nefunguji
        --RAM: 29A  Radic: 392  rozdíl F8
        
        case flash_present is

            when S_RESET =>
                CSB <= '1'; -- karta neni aktivni
                flash_next <= S_START;
                CLK_PAUSE <= '1'; -- pozastavm hodinovy signal
            
            when S_START =>
                flash_next<= S_CMD;
                
            -- prikaz FAST READ
            when S_CMD =>
                FLASH_DATA_IN <= X"0B";
                if READY='1' then
                    flash_next <= S_ADDR_HIGH;
                else
                    flash_next <= S_CMD;
                end if;

            -- page 1024 nejvyssi bajt                
            when S_ADDR_HIGH =>
                FLASH_DATA_IN <= X"0F";
                if READY='1' then
                    flash_next <= S_ADDR_MIDDLE;
                else
                    flash_next <= S_ADDR_HIGH;
                end if;

            -- page 1024 prostredni bajt
            when S_ADDR_MIDDLE =>
                FLASH_DATA_IN <= X"82";
                if READY='1' then
                    flash_next <= S_ADDR_LOW;
                else
                    flash_next <= S_ADDR_MIDDLE;
                end if;

            -- page 1024 nejnizsi bajt
            when S_ADDR_LOW =>
                FLASH_DATA_IN <= X"F8";
                if READY='1' then
                    flash_next <= S_DONT_CARE;
                else
                    flash_next <= S_ADDR_LOW;
                end if;

            -- don't care bajt           
            when S_DONT_CARE =>
                if READY='1' then
                    flash_next <= S_DATA;
                else
                    flash_next <= S_DONT_CARE;
                end if;

            -- cekam na nacteni celeho bajtu
            when S_DATA => 
--              if ADDR_REG = "00000011000000000000000" then --VRAM
--              if ADDR_REG = "00000101000000000000000" then -- ROM 16K
                if ADDR_REG = "00000110000000000000000" then -- ROM 32K
                    flash_next <= S_DONE;
                elsif READY='1' then -- bajt je kompletne nacten, muzu ho zapsat do SDRAM
                    flash_next <= S_DATA_WR;
                else
                    flash_next <= S_DATA;
                end if;

            -- zapis dat do SDRAM
            when S_DATA_WR =>
                if ACK='1' then
                    flash_next <= S_DATA;
                    ADDR_INC <= '1';
                else
                    WR <= '1';
                    CLK_PAUSE <= '1';
                    flash_next <= S_DATA_WR;
                end if;
                
            when S_DONE =>
                CSB <= '1';
                CLK_PAUSE <= '1';
                WAIT_n <= '1';
                flash_next <= S_DONE;
                
            when others =>
                flash_next <= S_RESET;
        end case;
    end process;

end Behavioral;

