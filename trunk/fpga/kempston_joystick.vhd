library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_ARITH.ALL;
use ieee.std_logic_UNSIGNED.ALL;


entity KEMPSTON_JOYSTICK is
	port (
		CLK			    : in  std_logic;
		RESET			: in  std_logic;
		-- rozhrani pro komunikaci s procesorem
		ADDR			: in  std_logic_vector(15 downto 0);
		DATA_OUT		: out std_logic_vector(7 downto 0);
		-- joystick pinout
		UP				: in  std_logic;
		DOWN			: in  std_logic;
		LEFT			: in  std_logic;
		RIGHT			: in  std_logic;
		BUTTON1	        : in  std_logic;
		BUTTON2		    : in  std_logic;
		BUTTON3		    : in  std_logic
	);
end entity;

architecture kempston_joystick_arch of kempston_joystick is

begin

    DATA_OUT(7 downto 0) <= (not BUTTON2) & '0' & (not BUTTON3) & (not BUTTON1) & (not UP) & (not DOWN) & (not LEFT) & (not RIGHT);

end architecture;

