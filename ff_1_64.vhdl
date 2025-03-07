library ieee;
use ieee.std_logic_1164.all;

entity ff_1_64 is 
		port(D1: in std_logic_vector(63 downto 0);En,clock,reset:in std_logic ; Q:out std_logic_vector(63 downto 0));
	end entity ff_1_64;

architecture behav of ff_1_64 is
	begin
	
	dff_reset_proc: process (clock,reset,En, D1)
		begin
		   for i in 0 to 63 loop
			if(En(i)='1') then
				if(reset(i)='1')then 
				Q(i) <= '0'; 
				elsif (clock(i)'event and (clock(i)='1')) then
				Q(i) <= D1(i); 
				end if ;
			end if;
		  end loop;
	end process;
end behav;
