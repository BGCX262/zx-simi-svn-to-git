library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_ARITH.ALL;
use ieee.std_logic_UNSIGNED.ALL;


entity MOUSE is
    port (
        CLK             : in  std_logic;
        RESET           : in  std_logic;
        -- komunikace s procesorem        
        ADDR            : in  std_logic_vector(15 downto 0);
        DATA_OUT        : out std_logic_vector(7 downto 0);
        -- signaly pro komunikaci s PS2 vystupem z FPGA     
        M_CLK           : inout std_logic;
        M_DATA          : inout std_logic
    );
end entity;


architecture behav of MOUSE is

    -- PS/2 controller
    component PS2_controller is
        port ( 
         -- Reset a synchronizace
         RST     : in   std_logic;
         CLK     : in   std_logic;
   
         -- Rozhrani PS/2
         PS2_CLK  : inout std_logic;
         PS2_DATA : inout std_logic;
    
         -- Vstup (zapis do zarizeni)
         DATA_IN  : in  std_logic_vector(7 downto 0); 
         WRITE_EN : in  std_logic;
   
         -- Vystup (cteni ze zarizeni)
         DATA_OUT : out  std_logic_vector(7 downto 0); 
         DATA_VLD : out  std_logic;
   
         DATA_ERR : out  std_logic
        );
    end component;

    for ps2mouse: PS2_controller use entity work.PS2_controller(full);
   
    signal PS2_DATA_OUT     : std_logic_vector(7 downto 0);
    signal PS2_DATA_IN      : std_logic_vector(7 downto 0);
    signal PS2_WRITE_EN     : std_logic;
    signal PS2_DATA_OUT_VLD : std_logic;
    
    type t_state is (S_RESET, S_WAIT, S_ENABLE_DATA_REPORTING1, S_ENABLE_DATA_REPORTING2, S_BYTE2, S_BYTE3, S_CHANGE);
    signal present_state, next_state : t_state;

    signal K_ADDR           : std_logic_vector(1 downto 0);
    
    signal BYTE1            : std_logic_vector(7 downto 0);    
    signal BYTE1_NOT        : std_logic_vector(2 downto 0);
    signal BYTE1_VLD        : std_logic;

    signal BYTE2            : std_logic_vector(7 downto 0);
    signal BYTE2_VLD        : std_logic;
    
    signal BYTE3            : std_logic_vector(7 downto 0);
    signal BYTE3_VLD        : std_logic;

    signal CHANGE           : std_logic;
    
    -- registry kempston mys
    signal K_AXIS_X         : std_logic_vector(7 downto 0);
    signal K_AXIS_Y         : std_logic_vector(7 downto 0);
    signal K_BUTTON         : std_logic_vector(2 downto 0);

begin

    ps2mouse: PS2_controller
    port map (
        RST => RESET,
        CLK => CLK,
   
        PS2_CLK  => M_CLK,
        PS2_DATA => M_DATA,

        DATA_IN  => PS2_DATA_IN,
        WRITE_EN => PS2_WRITE_EN,

        DATA_OUT => PS2_DATA_OUT,
        DATA_VLD => PS2_DATA_OUT_VLD,

        DATA_ERR => open
    );
    
    K_ADDR <= ADDR(10) & ADDR(8);
    
    with K_ADDR select
        DATA_OUT <= "11111" & K_BUTTON(2 downto 0) when "00",
                    K_AXIS_X when "01",
                    K_AXIS_Y when "11",
                    X"00" when others;


    BYTE1_NOT <= not BYTE1(2 downto 0);
    
    -- kempston mouse registr se stavem tlacitek 
    process(RESET,CLK)
    begin
        if RESET='1' then
            K_BUTTON <= (others=>'1'); 
        elsif CLK'event and CLK='1' then
            if CHANGE='1' then
                K_BUTTON(0) <= BYTE1_NOT(1);
                K_BUTTON(1) <= BYTE1_NOT(0);
                K_BUTTON(2) <= BYTE1_NOT(2);
            end if;
        end if;
    end process;
    
    -- kempston mouse osa X
    process(RESET,CLK)
    begin
        if RESET='1' then
            K_AXIS_X <= (others=>'0'); 
        elsif CLK'event and CLK='1' then
            if CHANGE='1' then
                K_AXIS_X <= K_AXIS_X + BYTE2; 
            end if;
        end if;
    end process;

    -- kempston mouse osa Y
    process(RESET, CLK)
    begin
        if RESET='1' then
            K_AXIS_Y <= (others=>'0'); 
        elsif CLK'event and CLK='1' then
            if CHANGE='1' then
                K_AXIS_Y <= K_AXIS_Y + BYTE3; 
            end if;
        end if;
    end process;


    -- prvni zachytny registr
    process(CLK)
    begin
        if CLK'event and CLK='1' then
            if BYTE1_VLD='1' then
                BYTE1 <= PS2_DATA_OUT;
            end if;
        end if;
    end process;

    -- druhy zachytny registr
    process(CLK)
    begin
        if CLK'event and CLK='1' then
            if BYTE2_VLD='1' then
                BYTE2 <= PS2_DATA_OUT;
            end if;
        end if;
    end process;

    -- treti zachytny registr
    process(CLK)
    begin
        if CLK'event and CLK='1' then
            if BYTE3_VLD='1' then
                BYTE3 <= PS2_DATA_OUT;
            end if;
        end if;
    end process;
    
    

    FSM_MOUSE: process (present_state, PS2_DATA_OUT_VLD, PS2_DATA_OUT, BYTE1)
    begin
        PS2_DATA_IN <= X"00";
        PS2_WRITE_EN <= '0';
        BYTE1_VLD <= '0';
        BYTE2_VLD <= '0';
        BYTE3_VLD <= '0';
        CHANGE <= '0';
        
        case(present_state) is
            when S_RESET =>
                next_state <= S_ENABLE_DATA_REPORTING1;
                
            when S_ENABLE_DATA_REPORTING1 =>
                PS2_DATA_IN <= X"F4";
                PS2_WRITE_EN <= '1';
                next_state <= S_ENABLE_DATA_REPORTING2;
                
            when S_ENABLE_DATA_REPORTING2 =>
                next_state <= S_ENABLE_DATA_REPORTING2;                
                if PS2_DATA_OUT_VLD='1' and PS2_DATA_OUT=X"FA" then
                    next_state <= S_WAIT;
                end if;            
                
            when S_WAIT =>                
                BYTE1_VLD <= '1'; -- budu zachytavat data do prvniho registru
                next_state <= S_WAIT;                
                if PS2_DATA_OUT_VLD='1' and BYTE1(3)='1' then
                    next_state <= S_BYTE2;
                end if;

            when S_BYTE2 =>
                BYTE2_VLD <= '1'; -- budu zachytavat data do druheho registru
                next_state <= S_BYTE2;
                if PS2_DATA_OUT_VLD='1' then
                    next_state <= S_BYTE3;
                end if;

            when S_BYTE3 =>
                BYTE3_VLD <= '1'; -- budu zachytavat data do tretiho registru
                next_state <= S_BYTE3;
                if PS2_DATA_OUT_VLD='1' then
                    next_state <= S_CHANGE;
                end if;

            when S_CHANGE =>
                CHANGE <= '1';
                next_state <= S_WAIT;                
                            
            when others =>
                next_state <= S_RESET;
        end case;
    end process;   


    
    process (RESET,CLK)
    begin
        if RESET='1' then
            present_state <= S_RESET;
        elsif CLK'event and CLK='1' then
            present_state <= next_state;
        end if;
    
    end process;



end architecture behav; 