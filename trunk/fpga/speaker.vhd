library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_ARITH.ALL;
use ieee.std_logic_UNSIGNED.ALL;


entity SPEAKER is
	port (
		CLK				: in  std_logic;
		-- vstup z procesoru		
		ADDR			: in  std_logic_vector(15 downto 0);
		DATA_IN			: in  std_logic_vector(7 downto 0);
		WR			    : in  std_logic;
		-- vyspuni signal do reproduktoru		
		SPEAKER			: out std_logic
	);
end entity;


architecture behav of SPEAKER is
   
begin
    
	process(CLK)
	begin
		if CLK'event and CLK='1' then
			if WR='1' then
				SPEAKER <= DATA_IN(4);
			end if;
		end if;
	end process;


end architecture behav; 