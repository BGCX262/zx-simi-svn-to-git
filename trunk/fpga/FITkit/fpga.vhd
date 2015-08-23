-- arch_pc_ifc: PC interface architecture
-- Copyright (C) 2006 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Zdenek Vasicek <vasicek AT fit.vutbr.cz>
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
use IEEE.std_logic_1164.all;

use work.clkgen_cfg.all;
use work.fpga_cfg.all;

entity fpga is
    port (

        -- hodiny
        SMCLK   : in std_logic;
        -- SDRAM
        RA      : out std_logic_vector(14 downto 0);
        RD      : inout std_logic_vector(7 downto 0) := (others => 'Z');
        RDQM    : out std_logic;
        RCS     : out std_logic;
        RRAS    : out std_logic;
        RCAS    : out std_logic;
        RWE     : out std_logic;
        RCLK    : out std_logic;
        RCKE    : out std_logic;
        -- SD Card
        SD_CLK  : out std_logic;
        SD_CS   : out std_logic;
        SD_MOSI : out std_logic;
        SD_MISO : in std_logic;          
        -- VGA
        BLUE_V  : out std_logic_vector(2 downto 0);
        GREEN_V : out std_logic_vector(2 downto 0);
        RED_V   : out std_logic_vector(2 downto 0);
        VSYNC_V : out std_logic;
        HSYNC_V : out std_logic;
        -- PS/2 mouse
        M_DATA    : inout std_logic := 'Z';
        M_CLK     : inout std_logic := 'Z';
        -- PS/2 keyboard
        K_DATA    : inout std_logic := 'Z';
        K_CLK     : inout std_logic := 'Z';
        -- SPEAKER
        SPEAK_OUT : out std_logic;
        -- PC interface
        X       : inout std_logic_vector(40 downto 1) := (others => 'Z')
    );
end fpga;


architecture arch of fpga is

   signal clk          : std_logic;
   signal clk_locked   : std_logic;
   signal clkdv        : std_logic;
   signal reset        : std_logic;
   signal smclk_x1     : std_logic;

   component clkgen is
      generic (
         FREQ    : dcm_freq := DCM_FREQUENCY
      );
      port (
         CLK        : in    std_logic;
         RST        : in    std_logic;
         CLK1X_OUT  : out   std_logic;
         CLKFX_OUT  : out   std_logic;
         LOCKED_OUT : out   std_logic
      );
   end component; 

begin

   -- DCM - clock generator (default 25MHz)
   DCMclkgen: entity work.clkgen
      generic map (
         FREQ        => DCM_FREQUENCY
      )
      port map (
         CLK         => SMCLK,
         RST         => '0',
         CLK1X_OUT   => smclk_x1,
         CLKFX_OUT   => clk,
         LOCKED_OUT  => clk_locked
      ); 

   -- FPGA design
   fpga_inst: entity work.top_level
      port map (
         SMCLK => smclk_x1,
         CLK   => clk,
         RESET => reset,

         RA    => RA,
         RD    => RD,
         RDQM  => RDQM,
         RCS   => RCS,
         RRAS  => RRAS,
         RCAS  => RCAS,
         RWE   => RWE,
         RCKE  => RCKE,
         RCLK  => RCLK,



         X     => X(40 downto 1),

         BLUE_V(2) => BLUE_V(2),
         BLUE_V(1)  => BLUE_V(1),
         BLUE_V(0)  => BLUE_V(0),

         GREEN_V(2) => GREEN_V(2),
         GREEN_V(1) => GREEN_V(1),
         GREEN_V(0) => GREEN_V(0),

         RED_V(2) => RED_V(2),
         RED_V(1) => RED_V(1),
         RED_V(0) => RED_V(0),

         VSYNC_V => VSYNC_V,
         HSYNC_V => HSYNC_V,

         K_DATA => K_DATA,
         K_CLK  => K_CLK,

         M_DATA => M_DATA,
         M_CLK  => M_CLK,
         
         -- SD Card
         SD_CLK   => SD_CLK,
         SD_CS    => SD_CS,
         SD_MOSI  => SD_MOSI,
         SD_MISO  => SD_MISO,
         
         -- Speaker
         SPEAK_OUT => SPEAK_OUT
         
      );

end architecture;
