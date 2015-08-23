library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity spi is
    port (
        RESET    : in std_logic;
        CLK      : in std_logic;
        -- vstup/vystup
        DATA_IN  : in std_logic_vector(7 downto 0);
        DATA_OUT : out std_logic_vector(7 downto 0);
        WRITE_EN : in std_logic;
        READY    : out std_logic;
        -- SPI rozhrani
        MOSI     : out std_logic;
        MISO     : in  std_logic;
        SCLK     : out std_logic
    );
end spi;

architecture Behavioral of spi is

    signal READY_SIG      : std_logic;
    signal FLASH_CLK      : std_logic_vector(3 downto 0);
    signal FLASH_CLK0     : std_logic;

    signal DATA_OUT_REG   : std_logic_vector(7 downto 0);
    signal DATA_IN_REG    : std_logic_vector(7 downto 0);
    
    signal CLK_PAUSE      : std_logic;
 
    type tstate is (S_WAIT, S_SEND);
	signal present_state, next_state : tstate;

begin
    DATA_OUT <= DATA_OUT_REG;
    
    READY_SIG <= '1' when FLASH_CLK(3 downto 0)="1111" else '0';

    FLASH_CLK0 <= FLASH_CLK(0);
    SCLK <= FLASH_CLK(0); 
    
    process(present_state,WRITE_EN,READY_SIG)
    begin
        CLK_PAUSE <= '1';
        READY <= '0';
        
        case present_state is
            when S_WAIT =>
                READY <= '1';
                if WRITE_EN='1' then
                    next_state <= S_SEND;
                    CLK_PAUSE <= '0';
                else
                    next_state <= S_WAIT;
                end if;
                
            when S_SEND =>
                if READY_SIG='1' then
                    next_state <= S_WAIT;
                else
                    next_state <= S_SEND;
                    CLK_PAUSE <= '0';
                end if;
            
        end case;
    end process;
    
    process(RESET,CLK)
    begin
        if RESET='1' then
            present_state <= S_WAIT;
        elsif CLK'event and CLK='1' then
            present_state <= next_state;
        end if;
    end process;
   
   

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
    
    --vstupni registr
    process(RESET,CLK)
    begin
        if RESET='1' then
            DATA_IN_REG <= (others=>'0');
        elsif CLK'event and CLK='1' then
            if WRITE_EN='1' then
                DATA_IN_REG <= DATA_IN;
            end if;
        end if;
    end process;

    --prepinam na vystup bity datoveho registru
    with FLASH_CLK(3 downto 1) select
        MOSI <= DATA_IN_REG(7) when "000",
                DATA_IN_REG(6) when "001",
                DATA_IN_REG(5) when "010",
                DATA_IN_REG(4) when "011",
                DATA_IN_REG(3) when "100",
                DATA_IN_REG(2) when "101",
                DATA_IN_REG(1) when "110",
                DATA_IN_REG(0) when others;

    -- prijimani bajtu bit po bitu
    process(RESET,FLASH_CLK0)
    begin
        if RESET='1' then
            DATA_OUT_REG <= (others=>'0');
        elsif FLASH_CLK0'event and FLASH_CLK0='1' then
            DATA_OUT_REG <= DATA_OUT_REG(6 downto 0) & MISO;
        end if;
    end process;
    
    
    

end Behavioral;

