library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity sdcard_spi is
    port ( 
        RESET       : in std_logic;
        CLK         : in std_logic;
        -- Datova a adresova sbernice
        DATA_IN     : in std_logic_vector(7 downto 0);
        DATA_OUT    : out std_logic_vector(7 downto 0);
        WRITE_EN    : in std_logic;
        READY       : out std_logic; -- signalizace pripravenosti ke komunikaci
        -- Rozhrani SD karty
        SCLK        : out std_logic;
        MOSI        : out std_logic;
        MISO        : in std_logic
    );
end sdcard_spi;

architecture behav of sdcard_spi is

    -- SPI signaly
	signal spi_data        : std_logic_vector(7 downto 0); -- datovy IO registr
	signal spi_data_in_reg : std_logic;                    -- zachytny registr na vstupu. Vzorkuje s nastupnou hranou hodin

    signal spi_rotate      : std_logic;                    -- rotace datoveho registru 
    signal spi_clk_en      : std_logic;                    -- registr povolujici vystupni hodiny
    signal spi_last        : std_logic;                    -- priznak ze se odesila posledni bit

    signal spi_data_wr     : std_logic;                    -- povoleni zapisu do spi_data registru
    signal spi_output_en   : std_logic;                    -- povolovaci signal vystupu
    
    type tspistate is (S_WAIT,S_WRITE,S_SPI0,S_SPI1,S_SPI2,S_SPI3,S_SPI4,S_SPI5,S_SPI6,S_SPI7);
    signal spi_present, spi_next : tspistate;


begin
    -- povoleni hodin do pametove karty
    SCLK <= CLK when spi_clk_en='1' else '0';

    -- na vystup do SD karty pripojim MSB    
    MOSI <= spi_data(7) when spi_output_en='1' else '1';
    
    -- pripojim na vystup datovy registr spi_data
    DATA_OUT <= spi_data;
    
    -- registr povolujici vystupni hodiny
    process(RESET,CLK)
    begin
        if RESET='1' then
            spi_clk_en <= '0';
        elsif CLK'event and CLK='0' then
            if spi_last='1' then -- pokud odesilam posledni bit, zablokuji vystupni hodiny
                spi_clk_en <= '0';
                spi_output_en <= '0';
            elsif spi_data_wr='1' then -- pri zapisu do datoveho registru povolim hodiny, protoze se bude odesilat
                spi_clk_en <= '1';
                spi_output_en <= '1';
            end if;
        end if;
    end process;

    -- zachytny registr na vstupu. Vzorkuje pri nastupne hrane hodin.
    process(CLK)
    begin
        if CLK'event and CLK='1' then
            spi_data_in_reg <= MISO;
        end if;
    end process;


    -- SPI datovy registr                                          
    process(CLK)
    begin
        if CLK'event and CLK='0' then
            if spi_rotate='1' then   -- posunu vystupni data doleva a na 0. bit prilozim vstupni hodnotu
                spi_data <= spi_data(6 downto 0) & spi_data_in_reg;
            elsif spi_data_wr='1' then     -- zapisu do registru data, ktera chci odeslat
                spi_data <= DATA_IN;            
            end if; 
        end if;
    end process;

    -- FSM, ktery zajistuje odeslani/prijem bajtu
    fsm_spi : process (spi_present,WRITE_EN)
    begin
        spi_rotate <= '0';
        spi_last <= '0';
        READY <= '0';
        spi_data_wr <= '0';
        
        case spi_present is
            when S_WAIT =>
                READY <= '1';   -- signalizuji, ze SPI je pripraveno k odesilani
                spi_next <= S_WAIT;
                if WRITE_EN='1' then
                    spi_next <= S_WRITE;
                end if;
            when S_WRITE =>
                spi_next <= S_SPI0;
                READY <= '1';
                spi_data_wr <= '1';
            when S_SPI0 =>
                spi_next <= S_SPI1;
                spi_rotate <= '1';
            when S_SPI1 =>
                spi_next <= S_SPI2;
                spi_rotate <= '1';
            when S_SPI2 =>
                spi_next <= S_SPI3;
                spi_rotate <= '1';
            when S_SPI3 =>
                spi_next <= S_SPI4;
                spi_rotate <= '1';
            when S_SPI4 =>
                spi_next <= S_SPI5;
                spi_rotate <= '1';
            when S_SPI5 =>
                spi_next <= S_SPI6;
                spi_rotate <= '1';
            when S_SPI6 =>
                spi_next <= S_SPI7;
                spi_rotate <= '1';
            when S_SPI7 =>
                spi_next <= S_WAIT;
                spi_rotate <= '1';
                spi_last <= '1';
            when others =>
                spi_next <= S_WAIT;
        end case;
    end process;
    
    -- prepinani stavu u FSM	
	process (RESET,CLK)
	begin
	   if RESET='1' then
	       spi_present <= S_WAIT;
	   elsif CLK'event and CLK='1' then
	       spi_present <= spi_next;
	   end if;
	end process;
    
    
end architecture;