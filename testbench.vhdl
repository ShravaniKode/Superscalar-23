library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity testbench_tb is 
end entity testbench_tb;

architecture test_arch of testbench_tb is
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal fd1 : std_logic_vector(98 downto 0) := (others=>'0');
    signal fd2 : std_logic_vector(98 downto 0) := (others=>'0');
    signal dfrrf : std_logic_vector(1023 downto 0) := (others=>'0');
    signal vfrrf : std_logic_vector(63 downto 0) := (others=>'0');
    signal dfcrrf : std_logic_vector(63 downto 0) := (others=>'0');
    signal vfcrrf : std_logic_vector(63 downto 0) := (others=>'0');
    signal dfzrrf : std_logic_vector(63 downto 0) := (others=>'0');
    signal vfzrrf : std_logic_vector(63 downto 0) := (others=>'0');
    signal ti1p : std_logic_vector(95 downto 0) := (others=>'0');
    signal ti2p : std_logic_vector(95 downto 0) := (others=>'0');
    signal tsp : std_logic_vector(55 downto 0) := (others=>'0');

    --signal we : std_logic := '0';

component res_station is
    generic(
        size : integer := 32
        -- this defines the size of the reservation station
        -- the double priority encoder also depends on this value
    );
port(
        clk: in std_logic;
        reset: in std_logic;
        from_decoder1: in std_logic_vector(98 downto 0);
        from_decoder2: in std_logic_vector(98 downto 0);
        --destC[6]-destZ[6]-pc1-control[7]-op1-valid1-op2-valid2-imm-c-validc-z-validz
        --(6+6+16+7+16+1+16+1+16+6+1+6+1) = 99 bits
        --#6 Major mess fixed

        data_from_rrf: in std_logic_vector(1023 downto 0);-- rrf has 64 entries of length 16 bits.
        validbits_fromrrf: in std_logic_vector(63 downto 0);-- valid bits for each of the 64 entries

        data_from_Crrf: in std_logic_vector(63 downto 0);
        validbits_fromCrrf: in std_logic_vector(63 downto 0);

        data_from_Zrrf: in std_logic_vector(63 downto 0);
        validbits_fromZrrf: in std_logic_vector(63 downto 0);

        to_store_pipeline: out std_logic_vector(55 downto 0);
        --control[7]-valid-op1-op2-imm
        to_int1_pipeline: out std_logic_vector(95 downto 0);
        --destC-destZ-pc-control-z-c-valid-op1-op2-imm
        to_int2_pipeline: out std_logic_vector(95 downto 0)
        --destC[6]-destZ[6]-pc[16]-control[7]-z[6]-c[6]-valid[1]-op1[16]-op2[16]-imm[16]

    );
end component;

begin
    instance: res_station 
    generic map(size=>32)
    port map(clk,reset,fd1,fd2,dfrrf,vfrrf,dfcrrf,vfcrrf,dfzrrf,vfzrrf,tsp,ti1p,ti2p);

    clk <= not clk after 1 ns;
    reset <= '1','0' after 2 ns;
    
    stimulus : process 
    begin
        
		wait;
    end process stimulus;

                

end architecture;