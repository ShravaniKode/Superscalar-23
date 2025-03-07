library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

entity ARF is 
    port (
        clk: in std_logic;
        reset: in std_logic;

        from_rob_data: in std_logic_vector(31 downto 0);
        from_rob_valid: in std_logic_vector(1 downto 0);
        from_rob_busy: in std_logic_vector(1 downto 0);
        from_rob_add: in std_logic_vector(5 downto 0);
        



        --Value[16] + busy[1] + address[3]

        from_decoder_add: in std_logic_vector(5 downto 0);
        from_decoder_valid: in std_logic_vector(1 downto 0);
        from_decoder_tag: in std_logic_vector(11 downto 0);

        --Tag[6] + busy[1]
        arf_value: out std_logic_vector(127 downto 0);
        arf_tag: out std_logic_vector(47 downto 0);
        arf_busy: out std_logic_vector(7 downto 0)

    );
end entity;

architecture arch of ARF is

    type datatype_8 is array(7 downto 0) of std_logic_vector(7 downto 0);
    type datatype_6 is array(7 downto 0) of std_logic_vector(5 downto 0);
    type datatype_1 is array (7 downto 0) of std_logic;
    signal busy: datatype_1:=(others=>'0');
    signal tag: datatype_6:=(others=>(others=>'0'));
    signal data: datatype_8:=(others=>(others=>'0'));

begin

    busy_process: process(from_rob_busy, from_decoder_valid, from_decoder_add, from_rob_add)
    begin
     if(clk'event and clk = '1') then
      if(from_decoder_valid(1 downto 1) = "1") then
        busy(to_integer(unsigned(from_decoder_add(5 downto 3)))) <= '1';

      elsif(from_rob_busy(1 downto 1) = "0") then
        busy(to_integer(unsigned (from_rob_add(5 downto 3)))) <= '0';

      end if;

      if(from_decoder_valid(0 downto 0) = "1") then
        busy(to_integer(unsigned(from_decoder_add(2 downto 0)))) <= '1';

      elsif(from_rob_busy(0 downto 0) = "0") then
        busy(to_integer(unsigned (from_rob_add(2 downto 0)))) <= '0';

      end if;
     end if;
    end process;

 data_process: process(from_rob_busy, from_rob_valid, from_rob_add, from_rob_data)
    begin
      if(clk'event and clk = '1') then
        if(from_rob_valid(1 downto 1) = "1") then
           data(to_integer(unsigned (from_rob_add(5 downto 3)))) <= from_rob_data(31 downto 16);
        end if;

        if(from_rob_valid(0 downto 0) = "1") then
           data(to_integer(unsigned (from_rob_add(2 downto 0)))) <= from_rob_data(15 downto 0);
        end if;

      end if;
    end process;


 tag_process: process(from_decoder_tag)
 begin
    if(clk'event and clk = '1') then
       if(from_decoder_valid(1 downto 1) = "1") then
          tag(to_integer(unsigned (from_decoder_add(5 downto 3)))) <= from_decoder_tag(11 downto 6);
       end if;

       if(from_decoder_valid(0 downto 0) = "1") then
          tag(to_integer(unsigned (from_decoder_add(2 downto 0)))) <= from_decoder_tag(5 downto 0);
       end if;
  
    end if;  
end process;

broadcast_process: process (data,tag,busy)
    begin
        for i in 0 to 7 loop
            arf_value((i+1)*16-1 downto 16*i) <= data(i);
            arf_tag((i+1)*6-1 downto 6*i) <= tag(i);
            arf_busy(i)<= busy(i);
          --  load_queue_ep_out <= ep_out;
        end loop;
    end process;




end arch;
