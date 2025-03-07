library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

entity RRF is 
    generic(
        len: integer:=64;
        breadth: integer:=16
    );
    port (
        clk: in std_logic;
        reset: in std_logic;

        from_int1_pipe: in std_logic_vector((6+breadth-1) downto 0);
        -- as the pipe will always have a 6 bit address but might have 16 bit data or 1 bit data.
        valid_int1_pipe: in std_logic;

        from_int2_pipe: in std_logic_vector((6+breadth-1) downto 0);
        valid_int2_pipe: in std_logic;
        
        from_ls_pipe: in std_logic_vector((6+breadth-1) downto 0);
        valid_ls_pipe: in std_logic;

        from_decoder: in std_logic_vector(20 downto 0);
        -- 3 six bit rrf addresses -- 3 single bit corresponding valid bit

        data_output: out std_logic_vector(len*breadth-1 downto 0); -- spitting the entire rrf content to the outside world
        valid_out: out std_logic_vector(len-1 downto 0);
        busy_bit_out: out std_logic_vector(len-1 downto 0)
    );
end entity;

architecture rrf_arch of RRF is
    type datatype_breadth is array(len-1 downto 0) of std_logic_vector(breadth downto 0);
    signal busy_bit: std_logic_vector(len-1 downto 0):=(others=>'0');
    signal valid_bit: std_logic_vector(len-1 downto 0):=(others=>'0');
    signal data: datatype_breadth:=(others=>(others=>'0'));
    
begin

    input_process: process(from_decoder)
    begin
        if(from_decoder(2)='1') then
            valid_bit(to_integer(unsigned(from_decoder(20 downto 15)))) <= '0';
            busy_bit(to_integer(unsigned(from_decoder(20 downto 15)))) <= '1';
        end if;

        if(from_decoder(1)='1') then
            valid_bit(to_integer(unsigned(from_decoder(14 downto 9)))) <= '0';
            busy_bit(to_integer(unsigned(from_decoder(14 downto 9)))) <= '1';
        end if;

        if(from_decoder(0)='1') then
            valid_bit(to_integer(unsigned(from_decoder(8 downto 3)))) <= '0';
            busy_bit(to_integer(unsigned(from_decoder(8 downto 3)))) <= '1';
        end if;
    end process;

    broadcast_process: process(data,reset)
    begin
    if(reset='1') then
        data_output <= (others=>'0');
        data <=  (others=>'0');
        valid_bit <= (others=>'0');
        busy_bit <= (others=>'0');
    else
        for i in 0 to len-1 loop
        	data_output((i+1)*breadth-1 downto breadth*i) <= data(i);
        end loop;
        valid_out <= valid_bit;
        busy_bit_out <= busy_bit;
    end if;
    end process;

    update_process: process
    begin
        if (valid_int1_pipe='1' and busy_bit(to_integer(unsigned(from_int1_pipe((6+breadth-1) downto breadth))))='1') then
        data(to_integer(unsigned(from_int1_pipe((6+breadth-1) downto breadth)))) <= from_int1_pipe(breadth-1 downto 0);
        valid_bit(to_integer(unsigned(from_int1_pipe((6+breadth-1) downto breadth)))) <= '1';
        end if;

        if (valid_int2_pipe='1' and busy_bit(to_integer(unsigned(from_int2_pipe((6+breadth-1) downto breadth))))='1') then
        data(to_integer(unsigned(from_int2_pipe((6+breadth-1) downto breadth)))) <= from_int2_pipe(breadth-1 downto 0);
        valid_bit(to_integer(unsigned(from_int2_pipe((6+breadth-1) downto breadth)))) <= '1';
        end if;
        
        if (valid_ls_pipe='1' and busy_bit(to_integer(unsigned(from_ls_pipe((6+breadth-1) downto breadth))))='1') then
        data(to_integer(unsigned(from_ls_pipe((6+breadth-1) downto breadth)))) <= from_ls_pipe(breadth-1 downto 0);
        valid_bit(to_integer(unsigned(from_ls_pipe((6+breadth-1) downto breadth)))) <= '1';
        end if;
    end process;
    

end architecture;
