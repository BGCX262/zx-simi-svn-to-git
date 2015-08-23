-- top_level.vhd : 
-- Copyright (C) 2009 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): 
--                                                            ;
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
Library UNISIM;
use UNISIM.vcomponents.all;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_ARITH.ALL;
use ieee.std_logic_UNSIGNED.ALL;

use work.sdram_controller_cfg.all;


entity top_level is
    port (
        -- hodiny
        SMCLK     : in std_logic;
        CLK       : in std_logic;
        RESET     : in std_logic;
        -- SDRAM
        RA        : out std_logic_vector(14 downto 0);
        RD        : inout std_logic_vector(7 downto 0) := (others => 'Z');
        RDQM      : out std_logic;
        RCS       : out std_logic;
        RRAS      : out std_logic;
        RCAS      : out std_logic;
        RWE       : out std_logic;
        RCLK      : out std_logic;
        RCKE      : out std_logic;
        -- VGA
        BLUE_V    : out std_logic_vector(2 downto 0);
        GREEN_V   : out std_logic_vector(2 downto 0);
        RED_V     : out std_logic_vector(2 downto 0);
        VSYNC_V   : out std_logic;
        HSYNC_V   : out std_logic;
        -- SD Card
        SD_CLK    : out std_logic;
        SD_CS     : out std_logic;
        SD_MOSI   : out std_logic;
        SD_MISO   : in std_logic;        
        -- PS/2 mouse
        M_DATA    : inout std_logic := 'Z';
        M_CLK     : inout std_logic := 'Z';
        -- PS/2 keyboard
        K_DATA    : inout std_logic := 'Z';
        K_CLK     : inout std_logic := 'Z';
        --SPEAKER
        SPEAK_OUT : out std_logic;
        -- unused X
        X         : inout std_logic_vector(40 downto 1)
    );
end entity;


architecture top_level_arch of top_level is    

    -- Timing
    component BUFG
    port (
         I: in  std_logic;
         O: out std_logic
      );
    end component;
   
	component OBUF
		port (
			O : out STD_ULOGIC;
			I : in STD_ULOGIC
		);
	end component;


    -- -----------------------------------------------------------------------
    -- SDRAM pamet
    -- -----------------------------------------------------------------------
    signal sdram_ra     : std_logic_vector(13 downto 0);


 	type t_state_sdram is (S_WAIT, S_REFRESH, S_GPU_READ, S_T80_READ, S_T80_WRITE, S_SMDMA_WRITE, S_SMDMA_READ, S_FLASH_WRITE);
	signal sdram_present, sdram_next : t_state_sdram;

	signal sdram_addr		: std_logic_vector(22 downto 0);
	signal sdram_data_in	: std_logic_vector(7 downto 0);
	signal sdram_data_out	: std_logic_vector(7 downto 0);
	signal sdram_data_vld	: std_logic;
	signal sdram_busy		: std_logic;
	signal sdram_cmd		: sdram_func;
	signal sdram_cmd_we		: std_logic;
    
	-- -----------------------------------------------------------------------
    -- pomocne registry pro strankovani pameti
    -- -----------------------------------------------------------------------

    signal RAM_CNTRL_REG : std_logic_vector(7 downto 0); -- registr pro strankovani pameti 
    signal RAM_CNTRL_ADDR : std_logic_vector(18 downto 0); -- fyzicka adresa do RAM, ktera zohlednuje parametry strankovani
    signal RAM_CNTRL_TASK : std_logic;  -- adresa prepinani ulohy

	-- -----------------------------------------------------------------------
    -- Graficka jednotka
    -- -----------------------------------------------------------------------
	signal VGA_VSYNC	 : std_logic;
    signal VGA_VSYNC_old : std_logic;

    signal gpu_border_wr : std_logic;
	
	signal gpu_addr			: std_logic_vector (13 downto 0);
	signal gpu_read_en		: std_logic;

	signal gpu_data_in_vld	: std_logic;

    signal GPU_REFRESH		: std_logic;
    signal GPU_REFRESH_old		: std_logic;
    signal GPU_REFRESH_EN		: std_logic;
    signal GPU_REFRESH_RST		: std_logic;

    -- -----------------------------------------------------------------------
    -- Procesor T80
    -- -----------------------------------------------------------------------
    signal DCM_T80_CLK  : std_logic;

--	signal T80_RESET_n	: std_logic;
	signal T80_CLK_n	: std_logic;
--	signal T80_MREQ_n	: std_logic;

--	signal T80_IORQ_n	: std_logic;
	
	signal T80_WAIT_n      : std_logic;
--	signal SDRAM_WAIT_n	   : std_logic;
--	signal SDRAM_WAIT_n_rst	: std_logic;
    signal T80_PAUSE_n      : std_logic;

--	signal T80_RD_n		: std_logic;
--	signal T80_RD_n_reg		: std_logic;
--	signal T80_RD_event		: std_logic;
	
	signal T80_NMI_n		: std_logic;
--	signal T80_INT_n		: std_logic;
	
--	signal T80_read_en_reg	: std_logic;
--	signal T80_read_en_rst	: std_logic;
	signal T80_HALT_n		: std_logic;

--	signal T80_WR_n			: std_logic;
--	signal T80_WR_n_reg		: std_logic;
--	signal T80_WR_event		: std_logic;
	
--	signal T80_M1_n			: std_logic;
	
	signal T80_write_en_reg	: std_logic;
	signal T80_write_en_rst	: std_logic;
--	signal T80_ADDR		: std_logic_vector(15 downto 0);
	
--	signal T80_DATA_IN			: std_logic_vector(7 downto 0);
--	signal T80_DATA_IN_MREQ		: std_logic_vector(7 downto 0);
--	signal T80_DATA_IN_MREQ_vld	: std_logic;
--	signal T80_DATA_OUT	: std_logic_vector(7 downto 0);

    signal cpu_select_keyboard  : std_logic;
    signal cpu_select_mouse     : std_logic;
    signal cpu_select_sdcard    : std_logic;
    signal cpu_select_smdma       : std_logic;
    signal cpu_select_kempston_joystick : std_logic;
    signal cpu_select_speaker       : std_logic;
	
	signal clk_reg : std_logic_vector(15 downto 0);
	signal clk_reg_cpu : std_logic;



    signal cpu_addr             : std_logic_vector(15 downto 0);
    signal cpu_din              : std_logic_vector(7 downto 0);
    signal cpu_dout             : std_logic_vector(7 downto 0);
        
    signal cpu_mem_din_rd       : std_logic;
    signal cpu_mem_din_rd_sig   : std_logic;
    signal cpu_mem_din_vld      : std_logic;
    signal cpu_mem_dout_wr      : std_logic;
    signal cpu_mem_dout_wr_sig  : std_logic;
    signal cpu_mem_dout_vld     : std_logic;
    
    signal cpu_io_din_rd        : std_logic;
    signal cpu_io_din_rd_sig    : std_logic;
    signal cpu_io_din_vld       : std_logic;
    signal cpu_io_dout_wr       : std_logic;
    signal cpu_io_dout_wr_sig   : std_logic;
    signal cpu_io_dout_vld      : std_logic;
    
    signal cpu_int              : std_logic;


    -- -----------------------------------------------------------------------
    -- Kempston joystick
    -- -----------------------------------------------------------------------
    signal kempston_joystick_dout      : std_logic_vector(7 downto 0);

    -- -----------------------------------------------------------------------
    -- PS/2 Klavesnice
    -- -----------------------------------------------------------------------
	signal KB_DATA_OUT		: std_logic_vector(7 downto 0);

    -- -----------------------------------------------------------------------
    -- PS/2 Mys
    -- -----------------------------------------------------------------------
	signal MOUSE_DATA_OUT      : std_logic_vector(7 downto 0);
	
    -- -----------------------------------------------------------------------
    -- Externi Speaker
    -- -----------------------------------------------------------------------
    signal speaker_wr       : std_logic;

    -- -----------------------------------------------------------------------
    -- Radic SD/MMC karet
    -- -----------------------------------------------------------------------


    signal SDCARD_WAIT_n    : std_logic;
    signal SDCARD_ACK        : std_logic;
    signal sdcard_write_en   : std_logic;
    signal sdcard_read_en    : std_logic;
    signal sdcard_reset      : std_logic;
    signal sdcard_data_out   : std_logic_vector(7 downto 0);

    -- -----------------------------------------------------------------------
    -- SIMI DMA radic
    -- -----------------------------------------------------------------------
    signal SMDMA_ADDR         : std_logic_vector(22 downto 0);
    signal SMDMA_DATA_OUT     : std_logic_vector(7 downto 0);
    signal SMDMA_DATA_IN      : std_logic_vector(7 downto 0);

    signal SMDMA_WAIT_n       : std_logic;
    signal SMDMA_SELECT_SDCARD : std_logic;
    
    signal event_cpu_io_din_rd  : std_logic;
    signal event_cpu_io_dout_wr : std_logic;
    signal reg_cpu_io_din_rd    : std_logic;
    signal reg_cpu_io_dout_wr   : std_logic;

    signal smdma_iorq_din_rd     : std_logic;
    signal smdma_iorq_din_vld    : std_logic;
    signal smdma_iorq_dout_wr    : std_logic;
    signal smdma_iorq_dout_vld   : std_logic;
    
    signal smdma_mem_din_rd     : std_logic;
    signal smdma_mem_din_vld    : std_logic;
    signal smdma_mem_dout_wr    : std_logic;
    signal smdma_mem_dout_vld   : std_logic;
   
    -- -----------------------------------------------------------------------
    -- Obvod pro prepinani procesu
    -- -----------------------------------------------------------------------
    signal TASK_SELECT          : std_logic;

    signal TASK_ADDR            : std_logic_vector(15 downto 0);
    signal TASK_ADDR0_SET       : std_logic;
    signal TASK_ADDR1_SET       : std_logic;

    signal TASK_7FFD            : std_logic_vector(7 downto 0);
    signal TASK_7FFD_SET        : std_logic;
    
    signal TASK_CMD             : std_logic_vector(7 downto 0);
    signal TASK_CMD_SET         : std_logic;
    signal TASK_CMD_RST         : std_logic;
    
    signal TASK_SIGNAL_TASK_EVENT : std_logic;
--    signal TASK_T80_ADDR        : std_logic_vector(15 downto 0);
                                                        

    -- -----------------------------------------------------------------------
    -- Externi FLASH pamet
    -- -----------------------------------------------------------------------
    signal FLASH_DATA : std_logic_vector(7 downto 0);
    signal FLASH_ADDR : std_logic_vector(22 downto 0);
    signal FLASH_SDRAM_WR : std_logic;
    signal FLASH_SDRAM_ACK : std_logic;
    signal FLASH_WAIT_n    : std_logic;

begin


    -- -----------------------------------------------------------------------
    -- Externi FLASH pamet
    -- -----------------------------------------------------------------------
    flash_ext_inst : entity work.FLASH_EXT
    port map (
        CLK      => CLK,
        RESET    => RESET,
        WAIT_n   => FLASH_WAIT_n,
        -- externi FLASH
        MISO     => X(2),
        MOSI     => X(1),
        CSB      => X(3),
        SCLK     => X(4),
        -- rozhrani po komunikaci s pameti
        DATA_OUT => FLASH_DATA,
        ADDR     => FLASH_ADDR,
        WR       => FLASH_SDRAM_WR,
        ACK      => FLASH_SDRAM_ACK   
    );


    -- -----------------------------------------------------------------------
    -- SIMI DMA radic
    -- -----------------------------------------------------------------------
	smdma_inst : entity work.SMDMA
	port map (
		RESET		=> RESET,
		CLK   		=> CLK,

        CPU_WAIT_n      => SMDMA_WAIT_n,

		CPU_RD      => event_cpu_io_din_rd,
		CPU_WR		=> event_cpu_io_dout_wr,
		CPU_ADDR  	=> cpu_addr,

		ADDR    	=> SMDMA_ADDR,
        		
		CPU_DATA_IN	=> cpu_dout,
        
        DIN		    => SMDMA_DATA_IN,
		DOUT	    => SMDMA_DATA_OUT,
        
        MEM_DIN_RD      => smdma_mem_din_rd,
        MEM_DIN_VLD     => smdma_mem_din_vld,
        MEM_DOUT_WR     => smdma_mem_dout_wr,
        MEM_DOUT_VLD    => smdma_mem_dout_vld,
        
        IORQ_DIN_RD      => smdma_iorq_din_rd,
        IORQ_DIN_VLD     => smdma_iorq_din_vld,
        IORQ_DOUT_WR     => smdma_iorq_dout_wr,
        IORQ_DOUT_VLD    => smdma_iorq_dout_vld
	);

    event_cpu_io_din_rd <= cpu_io_din_rd and (not reg_cpu_io_din_rd);
    event_cpu_io_dout_wr <= cpu_io_dout_wr and (not reg_cpu_io_dout_wr);

    process(CLK)
    begin
        if CLK'event and CLK='1' then
            reg_cpu_io_din_rd <= cpu_io_din_rd;
            reg_cpu_io_dout_wr <= cpu_io_dout_wr;
        end if;
    end process;


    SMDMA_SELECT_SDCARD <= '1' when SMDMA_ADDR(7 downto 0)=X"F7" and (smdma_iorq_din_rd='1' or smdma_iorq_dout_wr='1') else '0';

    smdma_iorq_din_vld <= SDCARD_ACK and SMDMA_SELECT_SDCARD;
    smdma_iorq_dout_vld <= SMDMA_SELECT_SDCARD and smdma_iorq_dout_wr;

    -- pripojim na vstup spravnou sbernici
    SMDMA_DATA_IN <= SDRAM_DATA_OUT when smdma_mem_din_rd='1' else
                   SDCARD_DATA_OUT when SMDMA_SELECT_SDCARD='1' else
                   X"00";


    -- -----------------------------------------------------------------------
    -- Kempston joystick
    -- -----------------------------------------------------------------------
    kempston_joystic_inst : entity work.KEMPSTON_JOYSTICK
	port map (
		CLK			    => CLK,
		RESET			=> RESET,
		-- rozhrani pro komunikaci s procesorem
		ADDR			=> cpu_addr,
		DATA_OUT		=> kempston_joystick_dout,
		-- joystick pinout
		UP				=> X(18),
		DOWN			=> X(17),
		LEFT			=> X(16),
		RIGHT			=> X(15),
		BUTTON1	        => X(13),
		BUTTON2		    => '1',
		BUTTON3		    => '1'
	);


    -- -----------------------------------------------------------------------
    -- PS/2 Klavesnice
    -- -----------------------------------------------------------------------
	keyboard_inst : entity work.KEYBOARD
	port map (
		CLK				=> CLK,
		RESET			=> RESET,
		-- vstup z procesoru		
		ADDR			=> cpu_addr,
		DATA_OUT		=> KB_DATA_OUT,
		-- signaly pro komunikaci s PS2 vystupem z FPGA		
		K_CLK  			=> K_CLK,
		K_DATA 			=> K_DATA
	);
	
    -- -----------------------------------------------------------------------
    -- PS/2 Mys
    -- -----------------------------------------------------------------------
	mouse_inst : entity work.MOUSE
	port map (
		CLK				=> CLK,
		RESET			=> RESET,
		-- komunikace s procesorem		
		ADDR			=> cpu_addr,
		DATA_OUT		=> MOUSE_DATA_OUT,
		-- signaly pro komunikaci s PS2 vystupem z FPGA		
		M_CLK  			=> M_CLK,
		M_DATA 			=> M_DATA
	);	

    -- -----------------------------------------------------------------------
    -- Externi Speaker
    -- -----------------------------------------------------------------------
	speaker_isnt : entity work.SPEAKER
	port map (
		CLK				=> CLK,
		-- vstup z procesoru		
		ADDR			=> cpu_addr,
		DATA_IN			=> cpu_dout,
		WR			    => speaker_wr,
		-- vyspuni signal do reproduktoru		
		SPEAKER			=> SPEAK_OUT
	);
    
    speaker_wr <= cpu_select_speaker and cpu_io_dout_wr;


    -- -----------------------------------------------------------------------
    -- Procesor T80
    -- -----------------------------------------------------------------------
--	T80_RESET_n <= not RESET;

	-- signal predstavujici sestupnou hranu sigalu T80_RD_n
--	T80_RD_event <= (not T80_RD_n) and T80_RD_n_reg;
	
	-- signal predstavujici sestupnou hranu signalu T80_WR_n
--	T80_WR_event <= (not T80_WR_n) and T80_WR_n_reg;
	
	T80_WAIT_n <=  SMDMA_WAIT_n and SDCARD_WAIT_n; -- SDRAM_WAIT_n and
    
    T80_PAUSE_n <= FLASH_WAIT_n and SMDMA_WAIT_n and SDCARD_WAIT_n;
    
--	T80_NMI_n <= '1';

									 
	bufg_t80: BUFG
	port map (
		I => clk_reg_cpu,
		O => T80_CLK_n
	);


                         
--	T80s_inst : entity work.T80s
--	generic map(
--		Mode => 1,        -- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
--		T2Write => 1,     -- 0 => WR_n active in T3, /=0 => WR_n active in T2
--		IOWait => 0       -- 0 => Single cycle I/O, 1 => Std I/O cycle
--	)
--	port map (
--		RESET_n		=> T80_RESET_n,
--		CLK_n		=> T80_CLK_n,
--		WAIT_n		=> T80_WAIT_n,
--		INT_n		=> T80_INT_n,
--		NMI_n		=> T80_NMI_n,
--		BUSRQ_n		=> '1',
--		M1_n		=> T80_M1_n,
--		MREQ_n		=> T80_MREQ_n,
--		IORQ_n		=> T80_IORQ_n,
--		RD_n		=> T80_RD_n,
--		WR_n		=> T80_WR_n,
--		RFSH_n		=> open,
--		HALT_n		=> T80_HALT_n,
--		BUSAK_n		=> open,
--		A			=> T80_ADDR,
--		DI			=> T80_DATA_IN,
--		DO			=> T80_DATA_OUT
--	);


    cpu_wrapper_inst : entity work.cpu_wrapper_clk
    port map (
        RESET           => RESET,
        CLK             => CLK,
        CLK_CPU         => T80_CLK_n,

        ADDR            => cpu_addr,
        DIN             => cpu_din,
        DOUT            => cpu_dout,
        
        MEM_DIN_RD      => cpu_mem_din_rd,
        MEM_DIN_VLD     => cpu_mem_din_vld,
        MEM_DOUT_WR     => cpu_mem_dout_wr,
        MEM_DOUT_VLD    => cpu_mem_dout_vld,
    
        IO_DIN_RD       => cpu_io_din_rd,
        IO_DIN_VLD      => cpu_io_din_vld,
        IO_DOUT_WR      => cpu_io_dout_wr,
        IO_DOUT_VLD     => cpu_io_dout_vld,

        INT             => cpu_int
    );

    cpu_io_din_vld <= cpu_io_din_rd and T80_WAIT_n;
    cpu_io_dout_vld <= cpu_io_dout_wr and T80_WAIT_n;

    -- Zarizeni, ktere procesor adresuje
    cpu_select_keyboard             <= '1' when cpu_addr(0)='0' else '0';
    cpu_select_speaker              <= '1' when cpu_addr(0)='0' else '0';
    cpu_select_kempston_joystick    <= '1' when cpu_addr(5)='0' else '0';
    cpu_select_mouse                <= '1' when cpu_addr(7 downto 0)=X"DF" else '0';
    cpu_select_sdcard               <= '1' when cpu_addr(7 downto 0)=X"F7" else '0';
    cpu_select_smdma                <= '1' when cpu_addr(7 downto 0)=X"F3" else '0';  
    
    

    cpu_din <= sdram_data_out when cpu_mem_din_rd='1' else
               kb_data_out when cpu_select_keyboard='1' and cpu_io_din_rd='1' else
               sdcard_data_out when cpu_select_sdcard='1' and cpu_io_din_rd='1' else
               smdma_data_out when cpu_select_smdma='1' and cpu_io_din_rd='1' else
               MOUSE_DATA_OUT when cpu_select_mouse='1' and cpu_io_din_rd='1' else
               kempston_joystick_dout when cpu_select_kempston_joystick='1' and cpu_io_din_rd='1' else
               X"FF";

    clk_reg_cpu <= clk_reg(3);                   

	process (RESET,CLK)
	begin
		if RESET='1' then
			clk_reg <= (others=>'0');
		elsif CLK'event and CLK='1' then
			clk_reg <= clk_reg+1;
		end if;
	end process;

   	-- registr vstupnich dat do procesoru	
--	process(CLK, T80_MREQ_n, SDRAM_DATA_OUT, T80_DATA_IN_MREQ_vld)
--	begin
--		if T80_MREQ_n='1' then -- pokud procik nepracuje s pameti, vyresetuji tento vstupni registr
--			T80_DATA_IN_MREQ <= (others=>'0');
--		elsif CLK'event and CLK='1' then
--			if T80_DATA_IN_MREQ_vld='1' then
--				T80_DATA_IN_MREQ <= SDRAM_DATA_OUT;
--			end if;
--		end if;
--	end process;

  	
--  	process (CLK)
--	begin
--		if CLK'event and CLK='1' then
--			T80_RD_n_reg <= T80_RD_n;
--			T80_WR_n_reg <= T80_WR_n;
--		end if;
--	end process;
	
  	-- registr uchovavajici si zadost od procesoru o cteni z pameti
--   	T80_read_en_process : process(CLK, T80_read_en_rst)
--	begin
--		if T80_read_en_rst='1' then
--			T80_read_en_reg <= '0';
--		elsif CLK'event and CLK='1' then
--			if T80_RD_event='1' and T80_MREQ_n='0' then
--				T80_read_en_reg <= '1';
--			end if;
--		end if;
--	end process;

--  	-- registr uchovavajici si zadost o zapis z procesoru
--   	process(CLK, T80_write_en_rst)
--	begin
--		if T80_write_en_rst='1' then
--			T80_write_en_reg <= '0';
--		elsif CLK'event and CLK='1' then
--			if T80_WR_event='1' and T80_MREQ_n='0' then
--				T80_write_en_reg <= '1';
--			end if;
--		end if;
--	end process;

	-- rizeni signalu T80_WAIT
--   	process (CLK, RESET, SDRAM_WAIT_n_rst)
--	begin
--		if RESET='1' or SDRAM_WAIT_n_rst='1' then
--			SDRAM_WAIT_n <= '1';
--		elsif CLK'event and CLK='1' then
--			if (T80_RD_event='1' or T80_WR_event='1') and T80_MREQ_n='0' then -- pokud se objevil pozadavek o cteni nebo zapis, pozastavim cinnost procesoru
--				SDRAM_WAIT_n <= '0';
--			end if;
--		end if;
--	end process;
	

    --------------------------------------------------------------------------
    -- Generovani preruseni INT (maskovatelne preruseni)
    --------------------------------------------------------------------------

    --vzorkuji signal vertikalni synchronizace
    process(CLK)
    begin
        if CLK'event and CLK='1' then
            VGA_VSYNC_OLD <= VGA_VSYNC;
        end if;
    end process;

    
	-- po kazde vertikalni synchronizaci je provedeno preruseni INT, ktery trva presne 32 taktu procesoru
	cpu_int <= VGA_VSYNC and (not VGA_VSYNC_OLD);



	-- -----------------------------------------------------------------------
    -- Graficka jednotka
    -- -----------------------------------------------------------------------

    --signal zapisujici border do graficke karty
	gpu_border_wr <= '1' when cpu_addr(0)='0' and cpu_io_dout_wr='1' else '0';

	gpu_inst : entity work.GPU
	port map (
		CLK		    => CLK,
		RESET		=> RESET,
		
        --BORDER okraj
		BORDER_IN   => cpu_dout,		
        BORDER_WR   => gpu_border_wr,    

		-- signaly VGA radice
		VGA_VSYNC	=> VGA_VSYNC,
		VGA_HSYNC	=> HSYNC_V,
		VGA_RED		=> RED_V,
		VGA_GREEN	=> GREEN_V,
		VGA_BLUE	=> BLUE_V,

		-- signaly pro komunikaci s pameti		
        ADDR		=> gpu_addr,
        READ_EN	    => gpu_read_en,
        DATA_IN	    => sdram_data_out,
        DATA_IN_VLD => gpu_data_in_vld,
        REFRESH		=> GPU_REFRESH
	);

    VSYNC_V <= VGA_VSYNC;
    

    -- -----------------------------------------------------------------------
    -- Radic SD/MMC karet
    -- -----------------------------------------------------------------------

    sdcard_reset <= RESET;-- or X(10);

    sdcard_write_en <= cpu_select_sdcard and event_cpu_io_dout_wr;
    SDCARD_READ_EN <= (cpu_select_sdcard and event_cpu_io_din_rd) or (SMDMA_SELECT_SDCARD and smdma_iorq_din_rd);
    
    sdcard_inst : entity work.sdcard
    port map ( 
        -- Reset a synchronizace
        RESET   => sdcard_reset,
        CLK     => CLK,
     
        -- Datova a adresova sbernice
        DATA_IN  => cpu_dout,
        DATA_OUT => sdcard_data_out,
        ADDR     => cpu_addr(10 downto 8),
        WRITE_EN => sdcard_write_en,
        READ_EN  => SDCARD_READ_EN,
        WAIT_n   => SDCARD_WAIT_n,
        ACK      => SDCARD_ACK,
      
        -- Rozhrani SD karty. Pozor. DATA_IN a DATA_OUT jsou naopak
        SD_CLK        => SD_CLK,
        SD_CS         => SD_CS,
        SD_MOSI       => SD_MOSI,
        SD_MISO       => SD_MISO
    ); 
   

    -- -----------------------------------------------------------------------
    -- SDRAM pamet
    -- -----------------------------------------------------------------------

    RA <= sdram_ra(13 downto 12) & '0' & sdram_ra(11 downto 0);

    sdram_inst: entity work.sdram_raw_controller
	generic map (
         -- Generovani prikazu refresh radicem manu
         GEN_AUTO_REFRESH => false,
         OPTIMIZE_REFRESH => oAlone
      )
      port map (
         -- Adresa
         ADDR_ROW    => sdram_addr(20 downto 9),
         ADDR_COLUMN => sdram_addr(8 downto 0),
         BANK        => sdram_addr(22 downto 21),

         -- Pozadavek + jeho potvrzeni
         CMD      => sdram_cmd,
         CMD_WE   => sdram_cmd_we,
			
         -- Hodiny, reset, ...
         CLK      => CLK,
         RST      => RESET,
         ENABLE   => '1',
         BUSY     => sdram_busy,

         -- Data
         DATA_OUT    => sdram_data_out,
         DATA_VLD    => sdram_data_vld,
         DATA_IN     => sdram_data_in,

         -- SDRAM
         RAM_A       => sdram_ra,
         RAM_D       => RD,
         RAM_DQM     => RDQM,
         RAM_CS      => RCS,
         RAM_RAS     => RRAS,
         RAM_CAS     => RCAS,
         RAM_WE      => RWE,
         RAM_CLK     => RCLK,
         RAM_CKE     => RCKE
      );

	-- vystupni hodiny pro SDRAM posilam pres vystupni buffer
--	SDRAM_OBUF_CLK : OBUF
--	port map (
--		I => CLK,
--		O => RCLK
--    );

	-- prepnuti next_state do present_state
	sync_logic : process(RESET, CLK)
	begin
		if (RESET = '1') then
			sdram_present <= S_WAIT;
		elsif (CLK'event AND CLK = '1') then
			sdram_present <= sdram_next;
		end if;
	end process;




	-- pokud GPU kresli horizontalni okraj, ulozim si priznak, ze SDRAM muze provest refresh	
	process (CLK, GPU_REFRESH_RST)
	begin
		if GPU_REFRESH_RST='1' then
			GPU_REFRESH_EN <= '0';
		elsif CLK'event and CLK='1' then
			GPU_REFRESH_old <= GPU_REFRESH;
			if GPU_REFRESH_old='0' and GPU_REFRESH='1' then
				GPU_REFRESH_EN <= '1';
			end if;
		end if;
	end process;


    --TODO: tady se asi musi odstranit registr a nechat to jenom jako komparátor
--	process(CLK)
--	begin
--	   if CLK'event and CLK='1' then
--	       if cpu_mem_din_rd = '1' then
--	           TASK_T80_ADDR <= cpu_addr;
--	        end if;
--	   end if;
--	end process;

--    TASK_SIGNAL_TASK_EVENT <= '1' when TASK_CMD(0)='1' and TASK_T80_ADDR=TASK_ADDR(15 downto 0) and cpu_mem_din_rd='1' else '0';
    TASK_SIGNAL_TASK_EVENT <= '1' when TASK_CMD(0)='1' and cpu_addr=TASK_ADDR(15 downto 0) and cpu_mem_din_rd='1' else '0';

    process(RESET, CLK)
    begin
        if RESET='1' then
            RAM_CNTRL_TASK <= '0';
        elsif CLK'event and CLK='1' then
            if TASK_SIGNAL_TASK_EVENT='1' then
                RAM_CNTRL_TASK <= '1';
            end if;
        end if;
    end process;

    -- registr s adresou
    process(CLK)
    begin
        if CLK'event and CLK='1' then
            if TASK_ADDR0_SET='1' then
                TASK_ADDR(7 downto 0) <= cpu_dout;
            elsif TASK_ADDR1_SET='1' then
                TASK_ADDR(15 downto 8) <= cpu_dout;
            end if;
        end if;
    end process;

    
    -- command registr
    process(RESET, CLK, TASK_CMD_RST)
    begin
        if RESET='1' or TASK_CMD_RST='1' then
            TASK_CMD <= (others=>'0');
        elsif CLK'event and CLK='1' then
            if TASK_SIGNAL_TASK_EVENT='1' then
                TASK_CMD <= (others=>'0');
            elsif TASK_CMD_SET='1' then
                TASK_CMD <= cpu_dout;
            end if;
        end if; 
    end process;
    
    -- registr pro ulozeni hodnoty, ktera se pri spousteni aplikace ulozi do registru na adrese 7FFD
    process(RESET, CLK)
    begin
        if RESET='1' then
            TASK_7FFD <= (others=>'0');
        elsif CLK'event and CLK='1' then
            if TASK_7FFD_SET='1' then
                TASK_7FFD <= cpu_dout;
            end if;
        end if; 
    end process;
    
    -- TODO: posunout tento signál nahoru k procesoru
    -- Priznak, ze procesor prave adresuje tento obvod
    TASK_SELECT <= '1' when cpu_addr(7 downto 0)=X"1F" else '0';
    
    -- adresovy dekoder - zapis
    process(TASK_SELECT, cpu_addr, cpu_io_dout_wr)
    begin
        TASK_ADDR0_SET <= '0';        
        TASK_ADDR1_SET <= '0';
        TASK_7FFD_SET <= '0';
        TASK_CMD_SET <= '0';
        if TASK_SELECT='1' and cpu_io_dout_wr='1' then
            case cpu_addr(15 downto 8) is
                when X"00" =>
                    TASK_ADDR0_SET <= '1';        
                when X"01" =>
                    TASK_ADDR1_SET <= '1';
                when X"02" =>
                    TASK_7FFD_SET <= '1';
                when X"04" =>
                    TASK_CMD_SET <= '1';
                when others =>
            end case;
        end if;
    end process;
    
    -- TODO: vytvoøit zde select signal pro adresu procesoru
    process(RESET,CLK)
    begin
        if RESET='1' then
            RAM_CNTRL_REG(7 downto 0) <= (others=>'0');
        elsif CLK'event and CLK='1' then
			if cpu_addr(15)='0' and cpu_addr(1)='0' and cpu_io_dout_wr='1' and RAM_CNTRL_REG(5)='0' then
				RAM_CNTRL_REG(7 downto 0) <= cpu_dout(7 downto 0);
			elsif TASK_SIGNAL_TASK_EVENT='1' then
                RAM_CNTRL_REG(7 downto 0) <= TASK_7FFD(7 downto 0);
            end if;
		end if;
	end process;

    MX_RAM_CNTRL_ADDR : process(cpu_addr, RAM_CNTRL_REG,RAM_CNTRL_TASK)
    begin
        case cpu_addr(15 downto 14) is
            when "00" => -- 0x0000 adresace ROM 
                RAM_CNTRL_ADDR(18 downto 0) <= '0' & "100" & RAM_CNTRL_REG(4) & cpu_addr(13 downto 0);
            when "01" => -- 0x4000 video RAM
                RAM_CNTRL_ADDR(18 downto 0) <= RAM_CNTRL_TASK & "0101" & cpu_addr(13 downto 0);
            when "10" => -- 0x8000
                RAM_CNTRL_ADDR(18 downto 0) <= RAM_CNTRL_TASK & "0010" & cpu_addr(13 downto 0);
            when others => --adresa mapovatelne pametove oblasti
                RAM_CNTRL_ADDR(18 downto 0) <= RAM_CNTRL_TASK & '0' & RAM_CNTRL_REG(2 downto 0) & cpu_addr(13 downto 0);
        end case;
    end process;
    
    
	FSM_SDRAM : process(sdram_present, cpu_mem_din_rd, cpu_mem_dout_wr, cpu_dout, GPU_REFRESH_EN, gpu_read_en, sdram_data_vld, sdram_busy, gpu_addr, RAM_CNTRL_REG, TASK_ADDR, RAM_CNTRL_ADDR, RAM_CNTRL_TASK, SMDMA_ADDR, SMDMA_DATA_OUT, FLASH_SDRAM_WR, FLASH_ADDR, FLASH_DATA,T80_PAUSE_n)
	begin
		-- defaultni hodnoty, aby nevznikl latch - kombinacni logika		
		sdram_cmd <= fNop;
		sdram_cmd_we <= '0';

		gpu_data_in_vld <= '0';

		sdram_addr <= (others => '0');
		sdram_data_in <= (others => '0');

--		SDRAM_WAIT_n_rst <= '0';
--		T80_DATA_IN_MREQ_vld <= '0';

--		T80_read_en_rst <= '0';		
--		T80_write_en_rst <= '0';
		
		GPU_REFRESH_RST <= '0';
		
        TASK_CMD_RST <= '0';
        
  
        FLASH_SDRAM_ACK <= '0';
        
        cpu_mem_din_vld <= '0';
        cpu_mem_dout_vld <= '0';
        
        smdma_mem_din_vld <= '0';
        smdma_mem_dout_vld <= '0';
        
		case (sdram_present) is
			when S_WAIT =>
				sdram_next <= S_WAIT;
				if (sdram_busy = '1') then
				elsif (GPU_REFRESH_EN='1') then -- GPU signalizuje, je pamet muze provest refresh
    				sdram_cmd <= fRefresh;
    				sdram_cmd_we <= '1';
					sdram_next <= S_REFRESH;
				elsif (gpu_read_en='1') then -- grafika chce cist
    				sdram_cmd <= fRead;
    				sdram_cmd_we <= '1';
    				sdram_addr <= "0000" & RAM_CNTRL_TASK & "01" & RAM_CNTRL_REG(3) & '1' & gpu_addr(13 downto 0);
    				sdram_next <= S_GPU_READ;
    			elsif smdma_mem_dout_wr='1' then
    				sdram_cmd <= fWrite;
    				sdram_cmd_we <= '1';
    				sdram_addr <= SMDMA_ADDR;
                    sdram_data_in <= SMDMA_DATA_OUT;
					sdram_next <= S_SMDMA_WRITE;
				elsif smdma_mem_din_rd='1' then
    				sdram_cmd <= fRead;
    				sdram_cmd_we <= '1';
    				sdram_addr <= SMDMA_ADDR;
    				sdram_next <= S_SMDMA_READ;
    			elsif FLASH_SDRAM_WR='1' then
    				sdram_cmd <= fWrite;
    				sdram_cmd_we <= '1';
    				sdram_addr <= FLASH_ADDR;
    				sdram_data_in <= FLASH_DATA;
					sdram_next <= S_FLASH_WRITE;
				elsif cpu_mem_din_rd='1' and T80_PAUSE_n='1' then -- procesor chce cist -- 
    				sdram_cmd <= fRead;
    				sdram_cmd_we <= '1';
    				sdram_addr <= "0000" & RAM_CNTRL_ADDR;
    				sdram_next <= S_T80_READ;
				elsif cpu_mem_dout_wr='1' and T80_PAUSE_n='1' then -- procesor chce zapisovat 
                    if RAM_CNTRL_ADDR(17)='0' then   --povolim zapis do SDRAM pouze pokud procesor adresuje oblast RAM. Pokud adresuje ROM, nedovolim mu zapis
                        sdram_cmd <= fWrite;
                        sdram_cmd_we <= '1';
                        sdram_addr <= "0000" & RAM_CNTRL_ADDR;
                        sdram_data_in <= cpu_dout;
                    end if; 
					sdram_next <= S_T80_WRITE;
    			end if;
    			
			when S_REFRESH =>
                GPU_REFRESH_RST <= '1';
				sdram_next <= S_WAIT;
  			-- - - - - - - - - - - - - - - - - - - - - - -				
			when S_FLASH_WRITE =>
				FLASH_SDRAM_ACK <= '1'; 
				sdram_next <= S_WAIT;
  			-- - - - - - - - - - - - - - - - - - - - - - -				
			when S_SMDMA_WRITE =>
                smdma_mem_dout_vld <= '1';
				sdram_next <= S_WAIT;
			when S_SMDMA_READ =>
				sdram_next <= S_SMDMA_READ;
				if sdram_data_vld='1' then
				    smdma_mem_din_vld <= '1';
					sdram_next <= S_WAIT;
				end if;
    			
			-- - - - - - - - - - - - - - - - - - - - - - -
			when S_T80_READ =>
				sdram_next <= S_T80_READ;
				if sdram_data_vld='1' then
                    cpu_mem_din_vld <= '1';
					sdram_next <= S_WAIT;
				end if;
   			-- - - - - - - - - - - - - - - - - - - - - - -				
			when S_T80_WRITE =>
                cpu_mem_dout_vld <= '1';
				sdram_next <= S_WAIT;

			-- - - - - - - - - - - - - - - - - - - - - - -
			when S_GPU_READ =>
				sdram_next <= S_GPU_READ;
				if sdram_data_vld='1' then
				    gpu_data_in_vld <= '1';
					sdram_next <= S_WAIT;
				end if;

			when others =>
				sdram_next <= S_WAIT;
		end case;
	end process;



end architecture;
