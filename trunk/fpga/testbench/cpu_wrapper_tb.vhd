--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   20:31:46 11/29/2013
-- Design Name:   
-- Module Name:   D:/fuck/fpga/cpu_wrapper_tb.vhd
-- Project Name:  Xilinx
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: cpu_wrapper
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
Library UNISIM;
use UNISIM.vcomponents.all; 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY cpu_wrapper_tb IS
END cpu_wrapper_tb;
 
ARCHITECTURE behavior OF cpu_wrapper_tb IS 
    

   --Inputs
   signal RESET : std_logic := '0';
   signal CLK : std_logic := '0';
   signal CLK_CPU : std_logic := '0';
   signal DIN : std_logic_vector(7 downto 0) := (others => '0');
   signal MEM_DIN_VLD : std_logic := '0';
   signal MEM_DOUT_VLD : std_logic := '0';
   signal IO_DIN_VLD : std_logic := '0';
   signal IO_DOUT_VLD : std_logic := '0';
   signal INT : std_logic := '0';

 	--Outputs
   signal ADDR : std_logic_vector(15 downto 0);
   signal MEM_DIN_RD : std_logic;
   signal DOUT : std_logic_vector(7 downto 0);
   signal MEM_DOUT_WR : std_logic;
   signal IO_DIN_RD : std_logic;
   signal IO_DOUT_WR : std_logic;

   -- Clock period definitions
   constant CLK_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: entity work.cpu_wrapper_clk PORT MAP (
          RESET => RESET,
          CLK => CLK,
          CLK_CPU => CLK_CPU,
          ADDR => ADDR,
          DIN => DIN,
          DOUT => DOUT,
          MEM_DIN_RD => MEM_DIN_RD,
          MEM_DIN_VLD => MEM_DIN_VLD,
          MEM_DOUT_WR => MEM_DOUT_WR,
          MEM_DOUT_VLD => MEM_DOUT_VLD,
          IO_DIN_RD => IO_DIN_RD,
          IO_DIN_VLD => IO_DIN_VLD,
          IO_DOUT_WR => IO_DOUT_WR,
          IO_DOUT_VLD => IO_DOUT_VLD,
          INT => INT
        );

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '0';
		wait for CLK_period/2;
		CLK <= '1';
		wait for CLK_period/2;
   end process;
 


   -- Clock process definitions
   CLK_CPU_process :process
   begin
		CLK_CPU <= '0';
		wait for CLK_period*3;
		CLK_CPU <= '1';
		wait for CLK_period*3;
   end process;
 
 
   process(ADDR, MEM_DIN_VLD, IO_DIN_VLD)
   begin
     DIN <= (others=>'0');
     if MEM_DIN_VLD='1' then
         case ADDR is
           when X"0001" => DIN <= X"C3";
           -- JP 0x0025
           when X"0002" => DIN <= X"25";
           when X"0003" => DIN <= X"00";
           -- LD A,0xA5
           when X"0025" => DIN <= X"3E";
           when X"0026" => DIN <= X"A5";
           -- LD B, 0x45
           when X"0027" => DIN <= X"06";
           when X"0028" => DIN <= X"46";
           -- LD C, 0x46
           when X"0029" => DIN <= X"0E";
           when X"002A" => DIN <= X"45";
           -- LD (BC), A
           when X"002B" => DIN <= X"02";
           -- IN A,
           when X"002C" => DIN <= X"DB";
           when X"002D" => DIN <= X"1F";
           -- OUT (C),B
           when X"002E" => DIN <= X"ED";
           when X"002F" => DIN <= X"41";
           when others  => null;
         end case;
       elsif IO_DIN_VLD='1' then
         case ADDR is
           when X"A51F" => DIN <= X"88";
           when others  => null;
         end case;
     end if;
   end process;
 
 
   process
   begin
      wait until MEM_DIN_RD='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      MEM_DIN_VLD <= '1';
      wait until CLK'event and CLK='1';
      MEM_DIN_VLD <= '0';
   end process;
 
 
 
 
   process
   begin
      wait until IO_DIN_RD='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      IO_DIN_VLD <= '1';
      wait until CLK'event and CLK='1';
      IO_DIN_VLD <= '0';
   end process;
 
 
 
   process
   begin
      wait until MEM_DOUT_WR='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      MEM_DOUT_VLD <= '1';
      wait until CLK'event and CLK='1';
      MEM_DOUT_VLD <= '0';
   end process; 


   process
   begin
      wait until IO_DOUT_WR='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      wait until CLK'event and CLK='1';
      IO_DOUT_VLD <= '1';
      wait until CLK'event and CLK='1';
      IO_DOUT_VLD <= '0';
   end process;  

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      reset <= '1';
      wait for 100 ns;	
      reset <= '0';

      -- insert stimulus here 

      wait;
   end process;

END;
