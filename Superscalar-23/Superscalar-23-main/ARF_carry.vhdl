library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

entity ARF_carry is 
    port (
        clk: in std_logic;
        reset: in std_logic;

        from_rob_data: in std_logic;
        from_rob_valid: in std_logic;
        from_rob_busy: in std_logic ;
       -- from_rob_busy: in std_logic_vector(1 downto 0);
       -- from_rob_add: in std_logic_vector(0 downto 0);




        --Value[16] + busy[1] + address[3]

       -- from_decoder_add: in std_logic_vector(0 downto 0);
        from_decoder_valid: in std_logic_vector(1 downto 0);
        from_decoder_tag: in std_logic_vector(11 downto 0);

        --Tag[6] + busy[1]
	
        arf_value : out std_logic;
        arf_tag : out std_logic_vector(5 downto 0);
        arf_busy: out std_logic

    );
end entity;

architecture arch of ARF_carry is

    --type datatype_8 is array(7 downto 0) of std_logic_vector(7 downto 0);
   -- type datatype_6 is array(7 downto 0) of std_logic_vector(5 downto 0);
    signal busy: std_logic := '0';
    signal tag: std_logic_vector(5 downto 0) := (others => '0');
    signal data: std_logic := '0';

begin

    busy_process: process(from_rob_busy, from_decoder_valid)
    begin
     if(clk'event and clk = '1') then
      if((from_decoder_valid(1 downto 1) = "1") or (from_decoder_valid(0 downto 0) = "1")) then
        busy <= '1';
        

      elsif(from_rob_busy = '0') then
        busy <= '0';

      end if;

      --if(from_decoder_valid(0 downto 0) = "1") then
       -- busy <= '1';

      
      end if;
    end process;

 data_process: process(from_rob_busy, from_rob_valid, from_rob_data)
    begin
      if(clk'event and clk = '1') then
        if(from_rob_valid = '1') then
           data <= from_rob_data ;
        end if;

      end if;
    end process;


 tag_process: process(from_decoder_tag)
 begin 
    if(clk'event and clk = '1') then
       if(from_decoder_valid(0 downto 0) = "1") then
          tag <= from_decoder_tag(11 downto 6);
       

       elsif(from_decoder_valid(1 downto 1) = "1") then
          tag <= from_decoder_tag(5 downto 0);
       end if;
  
    end if;
end process;

broadcast_process: process(data,tag,busy)
    begin
            arf_value <= data;
            arf_tag((1)*6-1 downto 0) <= tag;
            arf_busy<= busy;
          --  load_queue_ep_out <= ep_out;
        
    end process;  

end arch;
