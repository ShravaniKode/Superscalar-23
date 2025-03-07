library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

entity ldsd_queue_decider is 
    port(
        inpA: in std_logic;
        inpB: in std_logic;

        outA: out std_logic;
        outB: out std_logic
    );
end entity;

architecture arch of ldsd_queue_decider is 
begin
    process
    begin
    if (inpA='1') then
        outA<= '1';
        outB<= '0';
    else
        outB<='1';
        outA<='0';
    end if;
    end process;
end architecture;