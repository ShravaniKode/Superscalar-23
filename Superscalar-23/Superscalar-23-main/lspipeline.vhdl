library ieee;
use ieee.std_logic_1164.all;

entity lspipeline is 
		port(
		clock,reset:in std_logic; 
		
		valid_load, valid_store: in std_logic;
		destZ : in std_logic_vector (5 downto 0);
		
		address, mem_data : in std_logic_vector (15 downto 0);
		pc_load, pc_store : in std_logic_vector (15 downto 0);
		
		address, dest     : in std_logic_vector (15 downto 0); 
		
		address_to_rrfZ : out std_logic_vector (5 downto 0);
		data_to_rrfZ : out std_logic;
		valid_to_rrfZ : out std_logic;
		
		address_to_rrf : out std_logic_vector (5 downto 0);
		data_to_rrf : out std_logic_vector (15 downto 0); 
		valid_to_rrf : out std_logic;
		
		exebit : out std_logic;
		exePC: out std_logic_vector (15 downto 0)
	); 
end entity lspipeline;

architecture behav of lspipeline is

component alu3 is
		port (ALU3_A, ALU3_B: in std_logic_vector(15 downto 0); ALU3_C: out std_logic_vector(15 downto 0));
end component alu3;

component Memory_data is
    port(clock, mem_rd, mem_wr: in std_logic; mem_add,mem_data: in std_logic_vector(15 downto 0);  mem_out: out std_logic_vector(15 downto 0) );
end component Memory_data ;


signal address : std_logic_vector(15 downto 0) := (others=>(others=>'0'));
signal mem_read : std_logic := '0';
signal rrf_read : std_logic := '0';
signal read_from_mem : std_logic_vector(15 downto 0) := (others=>(others=>'0'));
signal write_in_mem : std_logic_vector(15 downto 0) := (others=>(others=>'0'));


begin
    
    
    mem_read<= '1' when valid_load = '1' else '0'; --LW
    mem_wrte<= '1' when valid_store = '1' else '0'; --SW
    
    write_in_mem <= mem_data  ;  -- given by store
    
    mem_data : Memory_data port map (clock=> clock, mem_rd=> mem_read, mem_wr=> mem_wrte , mem_add=> address ,mem_data=> write_in_mem,  mem_out=> read_from_mem );
    
    valid_to_rrf<= '1' when valid_load = '1' else '0'; --LW
   
    address_to_rrf <=  dest_rrf (5 downto 0);
    
    data_to_rrf <= read_from_mem;
    
    address_to_rrfZ <=  destZ;
    
    data_to_rrfZ <= '1' when (to_integer(read_from_mem) = 0) else '0' ;
    
    valid_to_rrfZ <= '1' when valid_load = '1' else '0'; --LW
    
    exebit <= '1' when (valid_load = '1' or valid_store = '1' ) else '0';
    
    exePC <= pc_load when valid_load = '1' else pc_store ;
	
end behav;
