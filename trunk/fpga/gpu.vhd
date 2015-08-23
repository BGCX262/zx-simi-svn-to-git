library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_ARITH.ALL;
use ieee.std_logic_UNSIGNED.ALL;
use work.vga_controller_cfg.all;


entity GPU is
    port (
        CLK         : in  std_logic;
        RESET       : in  std_logic;
        -- okraj (BORDER)
        BORDER_IN   : in  std_logic_vector(7 downto 0);
        BORDER_WR   : in  std_logic;
        -- signaly VGA radice
        VGA_VSYNC   : out  std_logic;
        VGA_HSYNC   : out  std_logic;
        VGA_RED     : out std_logic_vector(2 downto 0);
        VGA_GREEN   : out std_logic_vector(2 downto 0);
        VGA_BLUE    : out std_logic_vector(2 downto 0);
        -- signaly pro komunikaci s pameti
        ADDR        : out std_logic_vector(13 downto 0);
        READ_EN     : out std_logic;
        DATA_IN     : in  std_logic_vector(7 downto 0);
        DATA_IN_VLD : in  std_logic;

        REFRESH     : out std_logic -- povoleni refresh pameti
    );
end entity;

architecture behav of GPU is
    constant RESOLUTION_WIDTH   : integer := 640;
    constant RESOLUTION_HEIGHT  : integer := 480;
    constant PIXEL_WIDTH            : integer := 2;
    constant PIXEL_HEIGHT       : integer := 2;
    
    -- rozmer kreslici plochy
    constant SCREEN_WIDTH   : integer := 256*PIXEL_WIDTH;
    constant SCREEN_HEIGHT  : integer := 192*PIXEL_HEIGHT;
    -- sirka okraju
    constant BORDER_WIDTH   : integer := (RESOLUTION_WIDTH-SCREEN_WIDTH)/2;
    constant BORDER_HEIGHT  : integer := (RESOLUTION_HEIGHT-SCREEN_HEIGHT)/2; 

  component BUFG
      port (
         I: in  std_logic;
         O: out std_logic
      );
   end component;

    -- adresove vodice  
    signal addr_data        : std_logic_vector(13 downto 0);
    signal addr_atrib       : std_logic_vector(13 downto 0);

    signal data             : std_logic_vector(7 downto 0); -- aktualni zobrazovana data
    signal data1            : std_logic_vector(7 downto 0);   -- data registr1 
    signal data2            : std_logic_vector(7 downto 0);   -- data registr2
    signal data_fetch_vld   : std_logic;    -- signal zapis do registru
    
    signal data_bit         : std_logic;    -- aktualni datovy bit, ktery se vykresluje

    signal read_en_vld      : std_logic;    -- povoleni vystupu READ_EN

    signal atrib            : std_logic_vector(7 downto 0); -- atributy aktualne zobrazovanych dat
    signal atrib1           : std_logic_vector(7 downto 0); -- atributy registr1
    signal atrib2           : std_logic_vector(7 downto 0); -- atributy registr2
    signal atrib_fetch_vld  : std_logic;    -- signál zápis do registru

    signal clk_reg          : std_logic;
    signal clk_d2           : std_logic;

    signal color            : std_logic_vector(3 downto 0); -- atribut s barvou, ktera se bude kreslit (signal) 

    signal border           : std_logic_vector(2 downto 0); -- okraj
    
    signal flash            : std_logic_vector(4 downto 0); -- inkrementovany registr pro blikani obrazu (flash)     

    signal col_reg          : std_logic_vector(8 downto 0);
    signal col_rst          : std_logic;

    signal row_reg          : std_logic_vector(8 downto 0);
    signal row_rst          : std_logic;

    signal vsync            : std_logic;
    signal hsync            : std_logic;    
    signal vsync_old        : std_logic;
    signal hsync_old        : std_logic;

    type t_state_sdram is (S_WAIT, S_DATA_REQ, S_DATA_WAIT, S_ATRIB_REQ);
    signal sdram_present, sdram_next : t_state_sdram;

    type t_state_draw is (D_HBORDER, D_VBORDER, D_MIDDLE, D_MIDDLE_PREFETCH);
    signal draw_present, draw_next : t_state_draw;

    signal isettings : std_logic_vector(60 downto 0); --nastaveni rezimu VGA
    signal ROW          : std_logic_vector(11 downto 0);
    signal COL          : std_logic_vector(11 downto 0);
    signal RED          : std_logic_vector(2 downto 0);
    signal GREEN        : std_logic_vector(2 downto 0);
    signal BLUE         : std_logic_vector(2 downto 0);

begin
    -- nastaveni grafickeho rezimu
    SetMode(r640x480x60, isettings);

    -- napojeni signalu na VGA rozhrani
    vga: entity work.vga_controller(arch_vga_controller)
    generic map (REQ_DELAY => 0) -- data jsou k dispozici ihned pomoci kombinacni logiky
    port map (
        CLK    => clk_reg,
        RST    => RESET,
        ENABLE => '1',
        MODE   => isettings,

        DATA_RED    => RED,
        DATA_GREEN  => GREEN,
        DATA_BLUE   => BLUE,
        ADDR_COLUMN => COL,
        ADDR_ROW    => ROW,

        VGA_RED   => VGA_RED,
        VGA_BLUE  => VGA_BLUE,
        VGA_GREEN => VGA_GREEN,
        VGA_HSYNC => hsync,
        VGA_VSYNC => vsync,

        -- H/V Status
        STATUS_H  => open,
        STATUS_V  => open
    );

    VGA_HSYNC <= hsync;
    VGA_VSYNC <= vsync;


    -- aktualni adresa dat
    addr_data <= '0' & row_reg(7+PIXEL_HEIGHT-1 downto 6+PIXEL_HEIGHT-1) & row_reg(2+PIXEL_HEIGHT-1 downto 0+PIXEL_HEIGHT-1) & row_reg(5+PIXEL_HEIGHT-1 downto 3+PIXEL_HEIGHT-1) & col_reg(7+PIXEL_WIDTH-1 downto 3+PIXEL_WIDTH-1); 
    addr_atrib <= "0110" & row_reg(7+PIXEL_HEIGHT-1 downto 6+PIXEL_HEIGHT-1) & row_reg(5+PIXEL_HEIGHT-1 downto 3+PIXEL_HEIGHT-1) & col_reg(7+PIXEL_WIDTH-1 downto 3+PIXEL_WIDTH-1); 


    process(RESET,CLK)
    begin
        if RESET = '1' then
            border <= "000";    -- cerny okraj
        elsif CLK'event and CLK='1' then
            if BORDER_WR='1' then
                border <= BORDER_IN(2 downto 0);
            end if;
        end if;
    end process;

    -- podle sudeho/licheho znaku zobrazuju data bud z registru data1 nebo data2
    data <= data1 when COL(4)='1' else data2;

    -- obsluha datoveho registru 1
    process(CLK)
    begin
        if CLK'event and CLK='1' then
            if data_fetch_vld='1' and COL(4)='0' then
                data1 <= DATA_IN;
            end if;
        end if;
    end process;

    -- obsluha datoveho registru 2
    process(CLK)
    begin
        if CLK'event and CLK='1' then
            if data_fetch_vld='1' and COL(4)='1' then
                data2 <= DATA_IN;
            end if;
        end if;
    end process;

    -- podle sudeho/licheho znaku pouzivam atribut bud z registru atrib1 nebo atrib2
    atrib <= atrib1 when COL(4)='1' else atrib2;

    -- obsluha atributoveho registru 1
    process(CLK)
    begin
        if CLK'event and CLK='1' then
            if atrib_fetch_vld='1' and COL(4)='0' then
                atrib1 <= DATA_IN;
            end if;
        end if;
    end process;

    -- obsluha atributoveho registru 2
    process(CLK)
    begin
        if CLK'event and CLK='1' then
            if atrib_fetch_vld='1' and COL(4)='1' then
                atrib2 <= DATA_IN;
            end if;
        end if;
    end process;



    -- vyberu aktualni bit podle adresy sloupce
    process(COL,data)
    begin
        case COL(3 downto 1) is
            when "000" => data_bit <= data(7);
            when "001" => data_bit <= data(6);
            when "010" => data_bit <= data(5);
            when "011" => data_bit <= data(4);
            when "100" => data_bit <= data(3);
            when "101" => data_bit <= data(2);
            when "110" => data_bit <= data(1);
            when "111" => data_bit <= data(0);
            when others => null;
        end case;
    end process;



    -- pri kazde vertikalni synchronizaci inkrementuji registr zajistujici blikani
    flash_counter : process(CLK)
    begin
        if (CLK'event and CLK = '1') then
            vsync_old <= vsync;
            if (vsync_old='0' and VSYNC='1') then
                flash <= flash + 1;
            end if;
        end if;
    end process;


    -- multiplexor, ktery na vystup vybira aktualni barvu
    mx_color_output : process (color)
    begin
        RED <= "000";
        GREEN <= "000";
        BLUE <= "000";

        case color is
            when "0001" => -- modra
                BLUE <= "111";
            when "0010" => -- tmave cervena
                RED <= "110";               
            when "0011" => -- tmave fialova
                RED <= "110";
                BLUE <= "110";
            when "0100" => -- tmave zelena
                GREEN <= "110";
            when "0101" => -- tmave cyan
                GREEN <= "110";
                BLUE <= "110";
            when "0110" => -- tmave zluta
                RED <= "110";
                GREEN <= "110";
            when "0111" => -- seda
                RED <= "110";
                GREEN <= "110";
                BLUE <= "110";

            when "1001" => -- modra
                BLUE <= "111";
            when "1010" => -- svetle cervena
                RED <= "111";               
            when "1011" => -- svetle fialova
                RED <= "111";
                BLUE <= "111";
            when "1100" => -- svetle zelena
                GREEN <= "111";
            when "1101" => -- svetle cyan
                GREEN <= "111";
                BLUE <= "111";
            when "1110" => -- svetle zluta
                RED <= "111";
                GREEN <= "111";
            when "1111" => -- bila
                RED <= "111";
                GREEN <= "111";
                BLUE <= "111";
                
            when others => null;
        end case;       
    end process;
        


    -- prepnuti next state do sdram_present
    sync_logic : process(RESET, CLK)
    begin
        if (RESET = '1') then
            sdram_present <= S_WAIT;
            draw_present <= D_HBORDER;
        elsif (CLK'event AND CLK = '1') then
            sdram_present <= sdram_next;
            draw_present <= draw_next;
        end if;
    end process sync_logic;


    -- registr radku
    process (CLK,row_rst,HSYNC)
    begin
        if (row_rst = '1') then
            row_reg <= (others => '0');
        elsif (CLK'event and CLK = '1') then
            hsync_old <= HSYNC;
            if (hsync_old='0' and HSYNC='1') then
                row_reg <= row_reg + 1;
            end if;
        end if;
    end process;

    process(RESET,CLK)
    begin
        if RESET='1' then
            clk_reg <= '0';    
        elsif CLK'event and CLK='1' then
            clk_reg <= not clk_reg;
        end if;
    end process;

    clk_d2_bufg : BUFG
    port map (
        I => clk_reg,
        O => clk_d2
    );


    -- registr sloupce
    process(col_rst,clk_d2)
    begin
        if (col_rst = '1') then
            col_reg <= (others => '0');
        elsif (clk_d2'event and clk_d2 = '1') then
            col_reg <= col_reg + 1;
        end if;
    end process;

    -- automat zajistujici vykreslovani
    FSM_DRAW : process (draw_present, border, ROW, COL, VSYNC, data_bit, flash, atrib)
    begin
        row_rst <= '0';
        col_rst <= '0';
        read_en_vld <= '0';
        
        color <= '0' & border; -- vychozi rezim kresleni je okraj
        REFRESH <= '0';
                
        case (draw_present) is

            when D_HBORDER => -- horizontalni okraj
                draw_next <= D_HBORDER;
                row_rst <= '1'; -- drzim pocitadlo radku v resetu
                if ROW = BORDER_HEIGHT then
                    draw_next <= D_VBORDER;
                end if;
                
            when D_VBORDER => -- vertikalni okraj
                draw_next <= D_VBORDER;
                col_rst <= '1';
                if ROW(1 downto 0)="00" then
                    REFRESH <= '1';
                end if;
                if VSYNC = '0' then -- pri vertikalni synchronizaci zacnu kreslit horni okraj
                    draw_next <= D_HBORDER;
                elsif (ROW = SCREEN_HEIGHT+BORDER_HEIGHT) then -- radek je mimo oblast, zacnu kreslit horizontalni kraj
                    draw_next <= D_HBORDER;
                elsif (COL = BORDER_WIDTH-8*PIXEL_WIDTH) then -- sloupec uz je v kreslitelne oblasti, zacnu ho kreslit
                    draw_next <= D_MIDDLE_PREFETCH;
                end if;

            when D_MIDDLE_PREFETCH => -- jeste se kresli levy okraj, ale nacitaji se uz data
                draw_next <= D_MIDDLE_PREFETCH;
                read_en_vld <= '1'; -- povolim vystupni signal READ_EN
                if COL = BORDER_WIDTH then
                    draw_next <= D_MIDDLE;
                end if;

            when D_MIDDLE => -- kreslim i nacitam data
                draw_next <= D_MIDDLE;
                read_en_vld <= '1'; -- povolim vystupni signal READ_EN
                if (data_bit xor (flash(4) and atrib(7))) = '0'
                then -- pozadi
                    color <= atrib(6 downto 3);
                else -- popredi
                    color <= atrib(6) & atrib(2 downto 0);
                end if;

                if (COL = SCREEN_WIDTH+BORDER_WIDTH) then
                    draw_next <= D_VBORDER;
                end if;
                
        
            when others =>
                draw_next <= D_HBORDER;     
        end case;

    end process;

    -- FSM zajistujici komunikaci s SDRAM
    fsm_sdram : process(sdram_present, COL, read_en_vld, DATA_IN_VLD, addr_data, addr_atrib)
    begin
        READ_EN <= '0';
        ADDR <= addr_data;
        data_fetch_vld <= '0';
        atrib_fetch_vld <= '0';

        case (sdram_present) is
            when S_WAIT =>
                sdram_next <= S_WAIT;
                if (COL(3 downto 0) = "0001" and read_en_vld='1') then
                    sdram_next <= S_DATA_REQ;
                end if;
            when S_DATA_REQ =>
                ADDR <= addr_data;
                data_fetch_vld <= '1'; -- zapis nactenych dat do pomocneho registru
                sdram_next <= S_DATA_REQ;
                if (DATA_IN_VLD = '0') then
                    READ_EN <= '1';
                end if;
                if (DATA_IN_VLD = '1') then
                    sdram_next <= S_ATRIB_REQ;
                end if;
                
            when S_ATRIB_REQ =>
                ADDR <= addr_atrib;     
                atrib_fetch_vld <= '1'; -- zapis nactenych atributu do pomocneho registru
                sdram_next <= S_ATRIB_REQ;
                if (DATA_IN_VLD = '0') then
                    READ_EN <= '1';
                end if;
                if (DATA_IN_VLD = '1') then
                    sdram_next <= S_WAIT;
                end if;
                
    
            when others =>
                sdram_next <= S_WAIT;
        end case;
    end process;

end architecture behav; 