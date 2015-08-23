library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_ARITH.ALL;
use ieee.std_logic_UNSIGNED.ALL;


entity SMDMA is
    port(
        RESET       : in std_logic;
        CLK         : in std_logic;
        --signaly pro komunikaci s procesorem
        CPU_RD      : in std_logic;
        CPU_WR      : in std_logic;
        CPU_WAIT_n  : out std_logic;
        CPU_ADDR    : in std_logic_vector(15 downto 0);
        CPU_DATA_IN : in std_logic_vector(7 downto 0);
        -- sdilene signaly
        ADDR        : out std_logic_vector(22 downto 0);
        DIN         : in std_logic_vector(7 downto 0);
        DOUT        : out std_logic_vector(7 downto 0);
        --signaly pro komunikaci s pameti
        MEM_DIN_RD      : out std_logic;
        MEM_DIN_VLD     : in std_logic;
        MEM_DOUT_WR     : out std_logic;
        MEM_DOUT_VLD    : in std_logic;
        --signaly pro komunikaci s IO zarizenimi
        IORQ_DIN_RD     : out std_logic;
        IORQ_DIN_VLD    : in std_logic;
        IORQ_DOUT_WR    : out std_logic;
        IORQ_DOUT_VLD   : in std_logic
    );
end SMDMA;


architecture behv of SMDMA is

    signal ADDRA            : std_logic_vector(22 downto 0);
    signal ADDRA_INC        : std_logic;
    signal ADDRA0_SET       : std_logic;
    signal ADDRA1_SET       : std_logic;
    signal ADDRA2_SET       : std_logic;
    
    signal ADDRB            : std_logic_vector(22 downto 0);
    signal ADDRB_INC        : std_logic;
    signal ADDRB0_SET       : std_logic;
    signal ADDRB1_SET       : std_logic;
    signal ADDRB2_SET       : std_logic;

    
    signal DATA             : std_logic_vector(7 downto 0);
    signal DATA_SET         : std_logic;
    signal DATA_MEM_SET     : std_logic;

    signal CONFIG           : std_logic_vector(7 downto 0);
    -- 0 - povolit inkrementaci A
    -- 1 - povolit inkrementaci B
    signal CONFIG_SET       : std_logic;
    
    signal LENGTH           : std_logic_vector(15 downto 0);
    signal LENGTH_DEC       : std_logic;
    signal LENGTH_ZERO      : std_logic;
    signal LENGTH0_SET      : std_logic;
    signal LENGTH1_SET      : std_logic;
    
    signal READ_REQ         : std_logic;

    
    type t_state is (S_WAIT, S_WRITE1, S_WRITE2, S_WRITEN1, S_WRITEN2,S_WRITEN3,S_WRITEN4,S_READ1,S_READ2);
    signal present_state, next_state : t_state;

begin

    -- registr adresa A
    process(RESET,CLK)
    begin
        if RESET='1' then
            ADDRA <= (others=>'0');
        elsif CLK'event and CLK='1' then
            if ADDRA0_SET='1' then      -- nejnizsi bajt
                ADDRA(7 downto 0) <= CPU_DATA_IN;
            elsif ADDRA1_SET='1' then   -- prostredni bajt 
                ADDRA(15 downto 8) <= CPU_DATA_IN;
            elsif ADDRA2_SET='1' then   -- nejvyssi bajt
                ADDRA(22 downto 16) <= CPU_DATA_IN(6 downto 0);
            elsif ADDRA_INC='1' and CONFIG(0)='1' then
                ADDRA <= ADDRA + 1;
            end if;
        end if;
    end process;

    -- registr adresa B
    process(RESET,CLK)
    begin
        if RESET='1' then
            ADDRB <= (others=>'0');
            ADDRB <= "00000101000000000000000"; --zacatek TAP oblasti
        elsif CLK'event and CLK='1' then
            if ADDRB0_SET='1' then      -- nejnizsi bajt
                ADDRB(7 downto 0) <= CPU_DATA_IN;
            elsif ADDRB1_SET='1' then   -- prostredni bajt 
                ADDRB(15 downto 8) <= CPU_DATA_IN;
            elsif ADDRB2_SET='1' then   -- nejvyssi bajt
                ADDRB(22 downto 16) <= CPU_DATA_IN(6 downto 0);
            elsif ADDRB_INC='1' and CONFIG(4)='1' then
                ADDRB <= ADDRB + 1;
            end if;
        end if;
    end process;

    DOUT <= DATA;

    -- datovy registr pro docasne ulozeni bajtu
    process(RESET,CLK)
    begin
        if RESET='1' then
            DATA <= (others=>'0');
        elsif CLK'event and CLK='1' then
            if DATA_SET='1' then
                DATA <= CPU_DATA_IN;
            elsif DATA_MEM_SET='1' then
                DATA <= DIN;
            end if;
        end if;
    end process;

    -- konfiguracni registr
    process(RESET,CLK)
    begin
        if RESET='1' then
            CONFIG <= (others=>'0');
            CONFIG <= X"10";
        elsif CLK'event and CLK='1' then
            if CONFIG_SET='1' then
                CONFIG <= CPU_DATA_IN;
            end if;
        end if;
    end process;
    
    
    -- registr s delkou bloku, ktery se ma prenest
    process(RESET,CLK)
    begin
        if RESET='1' then
            LENGTH <= (others=>'0');
        elsif CLK'event and CLK='1' then
            if LENGTH0_SET='1' then
                LENGTH(7 downto 0) <= CPU_DATA_IN;
            elsif LENGTH1_SET='1' then
                LENGTH(15 downto 8) <= CPU_DATA_IN;
            elsif LENGTH_DEC='1' then
                LENGTH <= LENGTH - 1;
            end if;
        end if;
    end process;    

    -- dekodovani adresy od procesoru a zapis hodnoty do registru
    process(CPU_ADDR, CPU_WR)
    begin
        ADDRA0_SET <= '0';
        ADDRA1_SET <= '0';
        ADDRA2_SET <= '0';
        
        ADDRB0_SET <= '0';
        ADDRB1_SET <= '0';
        ADDRB2_SET <= '0';
        
        DATA_SET <= '0';
       
        LENGTH0_SET <= '0';
        LENGTH1_SET <= '0';
        
        CONFIG_SET <= '0';

        if CPU_ADDR(7 downto 0)=X"F3" and CPU_WR='1' then
            case CPU_ADDR(15 downto 8) is
                when X"00" => ADDRA0_SET <= '1';
                when X"01" => ADDRA1_SET <= '1'; 
                when X"02" => ADDRA2_SET <= '1'; 
                when X"03" => DATA_SET <= '1';
                when X"04" => ADDRB0_SET <= '1';
                when X"05" => ADDRB1_SET <= '1';
                when X"06" => ADDRB2_SET <= '1';
                when X"07" => LENGTH0_SET <= '1';
                when X"08" => LENGTH1_SET <= '1';
                when X"09" => CONFIG_SET <= '1';
                when others => null;
            end case;
        end if;
    end process;
    
    LENGTH_ZERO <= '1' when LENGTH=X"0000" else '0';
    
    -- priznak, ze CPU chce cist data z pameti
    READ_REQ <= '1' when CPU_ADDR(7 downto 0)=X"F3" and CPU_RD='1'
                    else '0';
    
    
    
    process(present_state, DATA_SET, LENGTH1_SET, ADDRA, DATA, ADDRB, LENGTH_ZERO, READ_REQ, CONFIG, MEM_DIN_VLD, MEM_DOUT_VLD)
    begin
        ADDRA_INC <= '0';
        ADDRB_INC <= '0';
        LENGTH_DEC <= '0';
        ADDR <= ADDRA;
        DATA_MEM_SET <= '0';
        CPU_WAIT_n <= '0';

        MEM_DIN_RD <= '0';
        MEM_DOUT_WR <= '0';

        IORQ_DIN_RD <= '0';
        IORQ_DOUT_WR <= '0';
        
        case (present_state) is
            when S_WAIT =>
                CPU_WAIT_n <= '1';
                next_state <= S_WAIT;
                if DATA_SET='1' then -- ulozim jeden bajt
                    next_state <= S_WRITE1;
                elsif LENGTH1_SET='1' then -- ulozim cely blok pameti
                    next_state <= S_WRITEN1;
                elsif READ_REQ='1' then
                    next_state <=  S_READ1; -- prectu jeden bajt z pameti a vystavim ho na vystup
                    CPU_WAIT_n <= '0';
                end if;

            when S_READ1 =>
                ADDR <= ADDRB; -- zdrojova adresa
                DATA_MEM_SET <= '1'; -- zapisu si prijaty bajt z pameti do registru
                next_state <= S_READ1;
                MEM_DIN_RD <= '1';
                if MEM_DIN_VLD='1' then
                    next_state <= S_READ2;
                end if;
            when S_READ2 =>
                ADDRB_INC <= '1';
                next_state <= S_WAIT;                            

            when S_WRITE1 =>
                ADDR <= ADDRA; 
                next_state <= S_WRITE1;
                if CONFIG(1)='0' then
                    MEM_DOUT_WR <= '1';
                    if MEM_DOUT_VLD='1' then
                        next_state <= S_WRITE2;
                    end if;
                end if;
                if CONFIG(1)='1' then
                    IORQ_DOUT_WR <= '1';
                    if IORQ_DOUT_VLD='1' then
                        next_state <= S_WRITE2;
                    end if;                    
                end if;
               
            when S_WRITE2 =>
                ADDRA_INC <= '1';
                next_state <= S_WAIT;            
                
            when S_WRITEN1 => -- nactu bajt z pameti
                ADDR <= ADDRB;
                DATA_MEM_SET <= '1';
                next_state <= S_WRITEN1;
                if CONFIG(5)='0' then
                    MEM_DIN_RD <= '1';
                    if MEM_DIN_VLD='1' then
                        next_state <= S_WRITEN4;
                    end if;
                end if;
                if CONFIG(5)='1' then
                    IORQ_DIN_RD <= '1';
                    if IORQ_DIN_VLD='1' then
                        next_state <= S_WRITEN4;
                    end if;
                end if;
            when S_WRITEN4 =>
                ADDRB_INC <= '1';
                LENGTH_DEC <= '1';
                next_state <= S_WRITEN2;
             
            when S_WRITEN2 => -- ulozim bajt z pameti
                ADDR <= ADDRA; 
                next_state <= S_WRITEN2;
                if CONFIG(1)='0' then
                    MEM_DOUT_WR <= '1';
                    if MEM_DOUT_VLD='1' then
                        next_state <= S_WRITEN3;
                    end if;
                end if;
                if CONFIG(1)='1' then
                    IORQ_DOUT_WR <= '1';
                    if IORQ_DOUT_VLD='1' then
                        next_state <= S_WRITEN3;
                    end if;
                end if;
            when S_WRITEN3 =>
                ADDRA_INC <= '1';
                next_state <= S_WRITEN1;
                if LENGTH_ZERO='1' then
                    next_state <= S_WAIT;
                end if;
                        
            
            when others =>
                next_state <= S_WAIT;
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

end architecture;