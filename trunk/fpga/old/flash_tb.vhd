--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   12:56:40 02/19/2012
-- Design Name:   
-- Module Name:   D:/ZX Simi/fpga/flash_tb.vhd
-- Project Name:  Xilinx
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: FLASH
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY flash_tb IS
END flash_tb;
 
ARCHITECTURE behavior OF flash_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT FLASH
    PORT(
         CLK : IN  std_logic;
         RESET : IN  std_logic;
         DATA_OUT : OUT  std_logic_vector(7 downto 0);
         ADDR : OUT  std_logic_vector(22 downto 0);
         WR : OUT  std_logic;
         ACK : IN  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal CLK : std_logic := '0';
   signal RESET : std_logic := '0';
   signal ACK : std_logic := '0';

 	--Outputs
   signal DATA_OUT : std_logic_vector(7 downto 0);
   signal ADDR : std_logic_vector(22 downto 0);
   signal WR : std_logic;

   -- Clock period definitions
   constant CLK_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: FLASH PORT MAP (
          CLK => CLK,
          RESET => RESET,
          DATA_OUT => DATA_OUT,
          ADDR => ADDR,
          WR => WR,
          ACK => ACK
        );

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '0';
		wait for CLK_period/2;
		CLK <= '1';
		wait for CLK_period/2;
   end process;

 
process(CLK)
begin
    if CLK'event and CLK='1' then
        ACK <= WR;
    end if;
end process;

   -- Stimulus process
   stim_proc: process
   begin		

      RESET <= '1';
      -- hold reset state for 100 ns.
      wait for 100 ns;	
      RESET <= '0';

      
      wait for CLK_period*100;

      -- insert stimulus here 

      wait;
   end process;

END;
