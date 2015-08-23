library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_ARITH.ALL;
use ieee.std_logic_UNSIGNED.ALL;


entity KEYBOARD is
	port (
		CLK				: in  std_logic;
		RESET			: in  std_logic;
		-- rozhrani pro komunikaci s procesorem
		ADDR			: in  std_logic_vector(15 downto 0);
		DATA_OUT		: out std_logic_vector(7 downto 0);
		-- rozhrani pro komunikaci s PS2 klavesnici pripojenou k FPGA
		K_CLK  			: inout std_logic;
		K_DATA 			: inout std_logic
	);
end entity;


architecture behav of KEYBOARD is

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

   for ps2kb: PS2_controller use entity work.PS2_controller(half);
   
	signal PS2_DATA_OUT		: std_logic_vector(7 downto 0);
	signal PS2_DATA_OUT_VLD	: std_logic;

   	type reg5x8 is array (0 to 7) of std_logic_vector(4 downto 0);
	signal keys				: reg5x8;
	signal mask0,mask3,mask4,mask6,mask7	: std_logic_vector(4 downto 0);

    signal data_mx			: std_logic_vector(4 downto 0);
    signal key_release		: std_logic;
    
	signal key_E0			: std_logic;	-- priznak, ktery maji nektere klavesy

	signal key_backspace	: std_logic;
	signal key_capslock		: std_logic;
	signal key_tecka		: std_logic;
	signal key_carka		: std_logic;
	signal key_plus			: std_logic;
	signal key_minus		: std_logic;
	signal key_krat			: std_logic;
	signal key_deleno		: std_logic;
	signal key_up			: std_logic;
	signal key_down			: std_logic;
	signal key_left			: std_logic;
	signal key_right		: std_logic;

   
begin

	ps2kb: PS2_controller
	port map (
		RST => RESET,
        CLK => CLK,
   
        PS2_CLK  => K_CLK,
        PS2_DATA => K_DATA,

        DATA_IN  => (others=>'0'),
        WRITE_EN => '0',

        DATA_OUT => PS2_DATA_OUT,
        DATA_VLD => PS2_DATA_OUT_VLD,

        DATA_ERR => open
    );
    
    -- vystup pro procesor
    DATA_OUT <= "111" & data_mx;

	-- maska s ostatnimi klavesami
	mask0 <= key_deleno & "111" & (key_backspace and key_capslock and key_up and key_down and key_left and key_right);
	mask3 <= key_left & "11" & key_capslock & '1';
	mask4 <= key_down & key_up & key_right & '1' & key_backspace;
	mask6 <= '1' & key_minus & key_plus & "11";
	mask7 <= key_krat & key_carka & key_tecka & (key_tecka and key_carka and key_plus and key_minus and key_krat and key_deleno) & '1';

	-- podle horni casti adresy na vystup pripojim patricny datovy radek
	with ADDR(15 downto 8) select
	data_mx <= (keys(0) and mask0) when "11111110",
	           keys(1) when "11111101",
	           keys(2) when "11111011",
	           (keys(3) and mask3) when "11110111",
	           (keys(4) and mask4) when "11101111",
	           keys(5) when "11011111",
	           (keys(6) and mask6) when "10111111",
	           (keys(7) and mask7) when others;

	-- stisknuta klavesa se signalizuje logickou 0, uvolnena klavesa logickou 1
	process(RESET,CLK)
	begin
		if RESET='1' then
			keys <= (others=>"11111");
			key_backspace <= '1';
			key_capslock <= '1';
			key_tecka <= '1';
			key_carka <= '1';
			key_plus <= '1';
			key_minus <= '1';
			key_krat <= '1';
			key_deleno <= '1';
			key_up <='1';
			key_down <='1';
			key_left <='1';
			key_right <='1';

			key_release <= '0';
		elsif CLK'event and CLK='1' then
			if PS2_DATA_OUT_VLD='1' then
				key_release <= '0'; -- priznak uvolneni je platny vzdy pro nasledujici znak. Nyni ho smazu, ale smazani se provede az po skonceni tohoto procesu
				key_E0 <= '0';
	
				case key_E0 & PS2_DATA_OUT is
	
					when X"012" => -- Caps Shift (levy shift) 
						keys(0)(0) <= key_release;
					when X"01A" => -- Z 
						keys(0)(1) <= key_release;
					when X"022" => -- X 
						keys(0)(2) <= key_release;
					when X"021" => -- C 
						keys(0)(3) <= key_release;
					when X"02A" => -- V 
						keys(0)(4) <= key_release;
	
					when X"01C" => -- A
						keys(1)(0) <= key_release;
					when X"01B" => -- S
						keys(1)(1) <= key_release;
					when X"023" => -- D
						keys(1)(2) <= key_release;
					when X"02B" => -- F
						keys(1)(3) <= key_release;
					when X"034" => -- G
						keys(1)(4) <= key_release;
	
					when X"015" => -- Q
						keys(2)(0) <= key_release;
					when X"01D" => -- W
						keys(2)(1) <= key_release;
					when X"024" => -- E
						keys(2)(2) <= key_release;
					when X"02D" => -- R
						keys(2)(3) <= key_release;
					when X"02C" => -- T
						keys(2)(4) <= key_release;
	
					when X"016" | X"069" => -- 1
						keys(3)(0) <= key_release;
					when X"01E" | X"072" => -- 2
						keys(3)(1) <= key_release;
					when X"026" | X"07A" => -- 3
						keys(3)(2) <= key_release;
					when X"025" | X"06B" => -- 4
						keys(3)(3) <= key_release;
					when X"02E" | X"073" => -- 5
						keys(3)(4) <= key_release;
	
					when X"045" | X"070" => -- 0
						keys(4)(0) <= key_release;
					when X"046" | X"007D" => -- 9
						keys(4)(1) <= key_release;
					when X"03E" | X"075" => -- 8
						keys(4)(2) <= key_release;
					when X"03D" | X"06C" => -- 7
						keys(4)(3) <= key_release;
					when X"036" | X"074" => -- 6
						keys(4)(4) <= key_release;
	
					when X"04D" => -- P
						keys(5)(0) <= key_release;
					when X"044" => -- O
						keys(5)(1) <= key_release;
					when X"043" => -- I
						keys(5)(2) <= key_release;
					when X"03C" => -- U
						keys(5)(3) <= key_release;
					when X"035" => -- Y
						keys(5)(4) <= key_release;
	
					when X"05A" | X"15A" => -- Enter
						keys(6)(0) <= key_release;
					when X"04B" => -- L
						keys(6)(1) <= key_release;
					when X"042" => -- K
						keys(6)(2) <= key_release;
					when X"03B" => -- J
						keys(6)(3) <= key_release;
					when X"033" => -- H
						keys(6)(4) <= key_release;
	
					when X"029" => -- Space
						keys(7)(0) <= key_release;
					when X"059" => -- Symbol Shift (pravy shift) 
						keys(7)(1) <= key_release;
					when X"03A" => -- M
						keys(7)(2) <= key_release;
					when X"031" => -- N
						keys(7)(3) <= key_release;
					when X"032" => -- B
						keys(7)(4) <= key_release;
	
	   				when X"079" => -- +
						key_plus <= key_release;
	   				when X"07B" => -- -
						key_minus <= key_release;
	   				when X"07C" => -- *
						key_krat <= key_release;
	   				when X"14A" => -- /
						key_deleno <= key_release;
						
					when X"041" => -- ,
						key_carka <= key_release;
					when X"049" => -- .
						key_tecka <= key_release;
	
	                when X"175" => -- Key up
						key_up <= key_release;
	                when X"172" => -- Key down
						key_down <= key_release;
	                when X"16B" => -- Key left
						key_left <= key_release;
	                when X"174" => -- Key right
						key_right <= key_release;
	                when X"066" => -- Backspace
						key_backspace <= key_release;
	                when X"058" => -- Caps Lock
						key_capslock <= key_release;
	
					when X"0E0" => -- E0
						key_E0 <= '1';
	
					when X"0F0" | X"1F0" => -- uvolneni klavesy
						key_release <= '1';
						key_E0 <= key_E0; -- priznak E0 zopakuji i pro priste
					
					when others =>
						null;
				end case;
			end if;
		end if;
	end process;



end architecture behav; 
