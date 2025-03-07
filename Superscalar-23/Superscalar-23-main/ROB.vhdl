library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ROB is
	generic(
        	size : integer := 64
    	);
    	
	port( 
		clock, reset:in std_logic;
		busyinp, write_inp,spec_inp, tag_inp,branch_bit, valid_inp,taken_or_not_inp : in std_logic_vector(1 downto 0); 
		
		exe_PC_valid : in std_logic_vector(2 downto 0); 
		exe_PC_inp: std_logic_vector(47 downto 0); 
		inst_inp, PCinp: in std_logic_vector(31 downto 0); 
		dest_inp: in std_logic_vector(5 downto 0); 
		rrf_inp : in std_logic_vector(11 downto 0); 
		rrf_values: in std_logic_vector(1023 downto 0); 
		
		arf_tag: in std_logic_vector(47 downto 0); 
		write_c : in std_logic_vector(1 downto 0); 
		
		rrf_carry_inp : in std_logic_vector(11 downto 0); 
		rrf_carry_values: in std_logic_vector(63 downto 0); 
		write_z : in std_logic_vector(1 downto 0); 
		
		rrf_zero_inp : in std_logic_vector(11 downto 0); 
		
		rrf_zero_values: in std_logic_vector(63 downto 0); 
		
		------------------------------------------------------------------------------------
		arfz_tag: in std_logic_vector(5 downto 0);
		arfc_tag: in std_logic_vector(5 downto 0);
		--------------------------------------------------------------------------------------
		
		flush_from_load_queue : in std_logic_vector(16 downto 0);
		--sp_opt, ep_opt: out std_logic_vector(5 downto 0);  
		branch_flag1: out std_logic;  
		flush_PC: out std_logic_vector(16 downto 0); 
		flush_rs: out std_logic; 
		value_arf: out std_logic_vector(31 downto 0); 
		address_arf: out std_logic_vector(5 downto 0); 
		arf_busy, valid_arf : out std_logic_vector(1 downto 0);

		c_out, c_valid, z_out, z_valid, store_signal: out std_logic;
		
		--------------------------------------------------------------------------------------
		c_busy, z_busy: out std_logic;
		------------------------------------------------------------------------------------
		branch_result: out std_logic_vector(1 downto 0));
	
end ROB;

architecture bhv of ROB is

type rob_type1 is array(size-1 downto 0) of std_logic;
type rob_type2 is array(size-1 downto 0) of std_logic_vector(15 downto 0);
type rob_type3 is array(size-1 downto 0) of std_logic_vector(2 downto 0);
type rob_type4 is array(size-1 downto 0) of std_logic_vector(5 downto 0);
type rob_type5 is array(size-1 downto 0) of std_logic_vector(1 downto 0);

component ff_6 is 
		port(En,clock,reset:in std_logic; D1: in std_logic_vector(5 downto 0); Q:out std_logic_vector(5 downto 0));
end component ff_6;

component mux2_1 is
		port(A,B : in std_logic_vector (15 downto 0); S: in std_Logic; Z: out std_logic_vector (15 downto 0));
end component mux2_1;

component alu3_6 is
		port (ALU3_A, ALU3_B: in std_logic_vector(5 downto 0); ALU3_C: out std_logic_vector(5 downto 0));
end component alu3_6;

component alu3 is
		port (ALU3_A, ALU3_B: in std_logic_vector(15 downto 0); ALU3_C: out std_logic_vector(15 downto 0));
end component alu3;

component oneshift is
		port (inp :in std_logic_vector(15 downto 0); OneS: in std_logic; output: out std_logic_vector(15 downto 0));
end component oneshift;

component SignE6 is 
		port(input1: in std_logic_vector(5 downto 0); se6: in std_logic; output: out std_logic_vector(15 downto 0));
end component SignE6;

component mux3_1_6 is 
		port(A, B, C: in std_logic_vector(5 downto 0); S:in std_logic_vector(1 downto 0) ; Z: out std_logic_vector(5 downto 0));
end component mux3_1_6;

component mux3_1_16 is 
		port(A, B, C: in std_logic_vector(15 downto 0); S:in std_logic_vector(1 downto 0) ; Z: out std_logic_vector(15 downto 0));
end component mux3_1_16;

component mux3_1 is 
		port(A, B, C: in std_logic; S:in std_logic_vector(1 downto 0) ; Z: out std_logic);
end component mux3_1;

component mux4_1 is 
		port(A, B, C, D: in std_logic; S:in std_logic_vector(1 downto 0) ; Z: out std_logic);
end component mux4_1;

component mux4_1_6 is 
		port(A, B, C, D: in std_logic_vector(5 downto 0); S:in std_logic_vector(1 downto 0) ; Z: out std_logic_vector(5 downto 0));
end component mux4_1_6;

component mux3_1_3 is 
		port(A, B, C: in std_logic_vector(2 downto 0); S:in std_logic_vector(1 downto 0) ; Z: out std_logic_vector(2 downto 0));
end component mux3_1_3;

signal valid_from_decode: std_logic:= '0';
signal branch_result1: std_logic_vector(1 downto 0):= "00"; 

signal busy, busy1: 	rob_type1:= (others=>'0');
signal flush_inst: 	rob_type1:= (others=>'0');
signal PC, PC1: 	rob_type2:= (others=>(others=>'0'));
signal inst, inst1: 	rob_type2:= (others=>(others=>'0'));

signal branch_flag: std_logic:= '0';
signal dest, dest1:     rob_type3:= (others=>(others=>'0'));

signal rrf, rrf1, rrf_carry, rrf_zero, rrf_carry1, rrf_zero1: 	rob_type4:= (others=>(others=>'0'));
signal exe, exe1: 	rob_type1:= (others=>'0');
--signal iss, iss1: 	rob_type1:= (others=>'0');
signal spec, spec1: 	rob_type1:= (others=>'0');
signal valid, valid1: 	rob_type1:= (others=>'0');

signal branch, branch1: 	rob_type1:= (others=>'0');  -- tells if branch or not

signal write, write1: 	rob_type1:= (others=>'0');          -- if inst writes in arf or not
signal write_carry, write_carry1: 	rob_type1:= (others=>'0');        
signal write_zero , write_zero1  : 	rob_type1:= (others=>'0');      


signal se6_opt, imm_pc, next_pc, alu_b: std_logic_vector(15 downto 0) := (others=>'0');

signal taken_or_not, taken_or_not1: 	rob_type1:= (others=>'0');

signal tag, tag1: 	rob_type1:= (others=>'0');


signal sp_inp, ep_inp: std_logic_vector(5 downto 0) := (others=>'0');
signal sp_opt, ep_opt: std_logic_vector(5 downto 0) := (others=>'0');

signal sp_next, sp_next2: std_logic_vector(5 downto 0) := (others=>'0');
signal ep_next, ep_next2: std_logic_vector(5 downto 0) := (others=>'0');

signal sp_select: std_logic_vector(1 downto 0) := "00";
signal bb: std_logic := '0';

signal write_from_decode, write_from_decode_c, write_from_decode_z: std_logic := '0';
signal tag_from_decoder: std_logic := '0';
signal spec_from_decoder: std_logic := '0';

signal busy_select: 	rob_type5:= (others=>"10");
signal write_select, write_c_select, write_z_select: 	rob_type5:= (others=>"10");
signal taken_or_not_select: 	rob_type5:= (others=>"10");
signal spec_select: 	rob_type5:= (others=>"10");
signal tag_select: 	rob_type5:= (others=>"10");

signal pp: std_logic_vector(15 downto 0) := (others=>'0');
signal PCselect: 	rob_type5:= (others=>"10");

signal ii: std_logic_vector(15 downto 0) := (others=>'0');
signal inst_select: 	rob_type5:= (others=>"10");

signal dd: std_logic_vector(2 downto 0) := (others=>'0');
signal dest_select: 	rob_type5:= (others=>"10");

signal rrfchoose, rrf_c_choose, rrf_z_choose: std_logic_vector(5 downto 0) := (others=>'0');
signal rrf_select, rrf_c_select, rrf_z_select: 	rob_type5:= (others=>"10");

signal valid_select: 	rob_type5:= (others=>"10");

signal branchselect: 	rob_type5:= (others=>"10");
signal brbr, npnp: std_logic := '0';

signal branch_no: integer := 0;

signal count: integer := 0;
signal FLUSH: std_logic := '0';

signal En: std_logic:= '1';

begin


  startpointerff : ff_6 port map (D1 => sp_inp, En=> En,clock => clock, reset=> reset, Q=> sp_opt);
  
  endpointerff   : ff_6 port map (D1 => ep_inp, En=> En,clock => clock, reset=> reset, Q=> ep_opt); 
   
--Busy, PC

  ff_proc: process (clock,reset,En)
		begin
			if(En='1') then
				if(reset='1')then 
					busy1 <=  (others=>'0');
				elsif (clock'event and (clock='1')) then
					busy1 <= busy;
					PC1 <= PC;
					inst1 <= inst;
					dest1 <= dest;
					rrf1 <= rrf;
					rrf_carry1 <= rrf_carry;
					rrf_zero1 <= rrf_zero;
					exe1 <= exe;
					--iss1 <= iss;
					spec1 <= spec;
					tag1 <= tag;
					valid1 <= valid;
					write1 <= write;
					write_carry1 <= write_carry;
					write_zero1 <= write_zero;
					taken_or_not1 <= taken_or_not;
					branch1 <= branch;
					branch_flag1 <= branch_flag;

				end if ;
			end if;
	
	end process ff_proc;
  
  
  L1: for i in 0 to 63 generate
  	busy_select(i) <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and ( to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                          "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2)) else 
                          "01" ;
  	--if busy1(i)=='1' busy(i)<='1' 
  	bb <= busyinp(0) when i = to_integer(unsigned(ep_next)) else busyinp(1) when i = to_integer(unsigned(ep_next2)) else '0';
  	mux1: mux3_1 port map (A => bb , B => busy1(i), C => '0', S=> busy_select(i), Z=> busy(i));
  	end generate L1;
  	
  L2: for i in 0 to 63 generate
  	PCselect(i)   <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and ( to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                         "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2))  else 
                         "01" ;
  	
  	pp <= PCinp(15 downto 0) when i = to_integer(unsigned(ep_next)) else PCinp(31 downto 16) when i = to_integer(unsigned(ep_next2)) else "0000000000000000";
  	mux2: mux3_1_16 port map (A => pp , B => PC1(i), C => "0000000000000000", S=> PCselect(i), Z=> PC(i));
  	end generate L2;
	
  L3: for i in 0 to 63 generate
  	write_select(i) <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and ( to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                           "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2)) else 
                           "01" ;
  	
  	write_from_decode <= write_inp(0) when i = to_integer(unsigned(ep_next)) else write_inp(1) when i = to_integer(unsigned(ep_next2)) else '0';
  	mux7: mux3_1 port map (A => write_from_decode , B => write1(i), C => '0', S=> write_select(i), Z=> write(i));
  	end generate L3;

	L30: for i in 0 to 63 generate
  	write_c_select(i) <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and ( to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                           "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2)) else 
                           "01" ;
  	
  	write_from_decode_c <= write_c(0) when i = to_integer(unsigned(ep_next)) else write_c(1) when i = to_integer(unsigned(ep_next2)) else '0';
  	mux7: mux3_1 port map (A => write_from_decode_c , B => write_carry1(i), C => '0', S=> write_c_select(i), Z=> write_carry(i));
  	end generate L30;

	L31: for i in 0 to 63 generate
  	write_z_select(i) <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and ( to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                           "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2)) else 
                           "01" ;
  	
  	write_from_decode_z <= write_z(0) when i = to_integer(unsigned(ep_next)) else write_z(1) when i = to_integer(unsigned(ep_next2)) else '0';
  	mux7: mux3_1 port map (A => write_from_decode_z , B => write_zero1(i), C => '0', S=> write_z_select(i), Z=> write_zero(i));
  	end generate L31;
  
  L4: for i in 0 to 63 generate
  	inst_select(i)   <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and ( to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                            "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2))  else 
                            "01" ;
  	
  	ii <= inst_inp(15 downto 0) when i = to_integer(unsigned(ep_next)) else inst_inp(31 downto 16) when i = to_integer(unsigned(ep_next2)) else "0000000000000000";
  	mux3: mux3_1_16 port map (A => ii , B => inst1(i), C => "0000000000000000", S=> inst_select(i), Z=> inst(i));
  	end generate L4;
	
  L5: for i in 0 to 63 generate
  	dest_select(i) <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and ( to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                          "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2))  else 
                          "01" ;
  	--if busy1(i)=='1' busy(i)<='1' 
  	dd <= dest_inp(2 downto 0) when i = to_integer(unsigned(ep_next)) else dest_inp(5 downto 3) when i = to_integer(unsigned(ep_next2)) else "000";
  	mux4: mux3_1_3 port map (A => dd , B => dest1(i), C => "000" , S=> dest_select(i), Z=> dest(i));
  	end generate L5;
	
  L6: for i in 0 to 63 generate
  	rrf_select(i) <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and ( to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                         "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2)) else 
                         "01" ;
  	--if busy1(i)=='1' busy(i)<='1' 
  	rrfchoose <= rrf_inp(5 downto 0) when i = to_integer(unsigned(ep_next)) else rrf_inp(11 downto 6) when i = to_integer(unsigned(ep_next2)) else "000000";
  	mux5: mux3_1_6 port map (A => rrfchoose , B => rrf1(i), C => "000000" , S=> rrf_select(i), Z=> rrf(i));
  	end generate L6;
  	
  	
  L19: for i in 0 to 63 generate
  	rrf_c_select(i) <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and ( to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                         "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2)) else 
                         "01" ;
  	
  	rrf_c_choose <= rrf_carry_inp(5 downto 0) when i = to_integer(unsigned(ep_next)) else rrf_carry_inp(11 downto 6) when i = to_integer(unsigned(ep_next2)) else "000000";
  	mux5: mux3_1_6 port map (A => rrf_c_choose , B => rrf_carry1(i), C => "000000" , S=> rrf_c_select(i), Z=> rrf_carry(i));
  	end generate L19;
  	
  L20: for i in 0 to 63 generate
  	rrf_z_select(i) <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and ( to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                         "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2)) else 
                         "01" ;
  	
  	rrf_z_choose <= rrf_zero_inp(5 downto 0) when i = to_integer(unsigned(ep_next)) else rrf_zero_inp(11 downto 6) when i = to_integer(unsigned(ep_next2)) else "000000";
  	mux5: mux3_1_6 port map (A => rrf_z_choose , B => rrf_zero1(i), C => "000000" , S=> rrf_z_select(i), Z=> rrf_zero(i));
  	end generate L20;
--  for i in 0 to 2 loop
--  	when iss_PC_inp(16.(i+1)-1 downto 16.i) /= "1111111111111111"
  	
  	
  	--if busy1(i)=='1' busy(i)<='1' 
--  	rrfchoose <= rrf_inp(4 downto 0) when i == ep_opt+1 else rrf_inp(9 downto 5) when i == ep_opt+2 else '0';
--  	mux5: mux3_1 port map (A => rrfchoose , B => rrf1(i), C => "000000" , S=> rrf_select(i), Z=> rrf(i));
  
  
   L7: for i in 0 to 63 generate
  	taken_or_not_select(i) <="10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and (to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                               "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2)) else 
                               "01" ;
  	
  	npnp <= taken_or_not_inp(1) when i = to_integer(unsigned(ep_next)) else taken_or_not_inp(0) when i = to_integer(unsigned(ep_next2)) else '0';
  	mux6: mux3_1 port map (A => npnp , B => taken_or_not1(i), C => '0', S=> taken_or_not_select(i), Z=> taken_or_not(i));
  	end generate L7;
  	
  	
  --L8: for i in 0 to 63 generate 
  
    --    iss(i) <= '1' when (((PC1(i) = iss_PC_inp(15 downto 0) and iss_PC_valid(0) = '1') or (PC1(i) = iss_PC_inp(31 downto 16) and iss_PC_valid(1) = '1') or (PC1(i) = iss_PC_inp(47 downto 32) and iss_PC_valid(2) = '1')) and ((i > to_integer(unsigned(sp_opt)) and i < to_integer(unsigned(ep_opt))) or (( i >= to_integer(unsigned(sp_opt)) or i < to_integer(unsigned(ep_opt))) and (to_integer(unsigned(ep_opt)) <= to_integer(unsigned(sp_opt))))))
      --  else '0' ;
  --end generate L8;
  
  L9: for i in 0 to 63 generate 
        exe(i) <= '1' when ((PC1(i) = exe_PC_inp(15 downto 0) and exe_PC_valid(0) = '1') or (PC1(i) = exe_PC_inp(31 downto 16) and exe_PC_valid(1) = '1') or (PC1(i) = exe_PC_inp(47 downto 32) and exe_PC_valid(2) = '1')) and ((i > to_integer(unsigned(sp_opt)) and i < to_integer(unsigned(ep_opt))) or (( i >= to_integer(unsigned(sp_opt)) or i < to_integer(unsigned(ep_opt))) and (to_integer(unsigned(ep_opt)) <= to_integer(unsigned(sp_opt)))))
        else '0' ;
  end generate L9;
  
  
  L10: for i in 0 to 63 generate
  	branchselect(i) <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and (to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) else 
                           "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2))  else 
                           "01" ;
  	
  	brbr <= branch_bit(0) when i = to_integer(unsigned(ep_next)) else busyinp(1) when i = to_integer(unsigned(ep_next2)) else '0';
  	mux1: mux3_1 port map (A => brbr , B => branch1(i), C => '0', S=> branchselect(i), Z=> branch(i));
   end generate L10;
 -------------------------------------- Start Pointer Update ---------------------------------------
  sp_next_update: alu3_6 port map (ALU3_A => sp_opt, ALU3_B => "000001", ALU3_C=>  sp_next);
  
  sp_next2_update : alu3_6 port map (ALU3_A => sp_opt, ALU3_B => "000010", ALU3_C=>  sp_next2);
  
  
  sp_select <= "11" when (count = 0) else 
  	       	   "01" when  (valid1(to_integer(unsigned(sp_opt))) = '1' and exe1(to_integer(unsigned(sp_opt))) = '1' and valid1(to_integer(unsigned(sp_next))) = '1' and exe1(to_integer(unsigned(sp_next))) = '1' and (inst1(to_integer(unsigned(sp_opt)))(15 downto 12) = "0101" and inst1(to_integer(unsigned(sp_next)))(15 downto 12) = "0101")) else
               "00" when (exe1(to_integer(unsigned(sp_opt)))='1' and exe1(to_integer(unsigned(sp_next))) ='1' and spec1(to_integer(unsigned(sp_next))) = '0' and branch1(to_integer(unsigned(sp_next))) = '0') else   --valid1(sp_opt) == '1' and
               "01" when exe1(to_integer(unsigned(sp_opt)))='1' else 
               "10"; 
               
  sp_mux: mux4_1_6 port map ( A => sp_next2, B => sp_next , C => sp_inp , D=> "000000", S => sp_select, Z=>sp_inp);
  

---------------------------------------- Completion stage ------------------------------------------   (Will check and give out only 2 at maximum)
  
  
  se6: SignE6 port map (input1 => inst1(to_integer(unsigned(sp_opt)))(5 downto 0), se6 => '1' , output => se6_opt);
  
  os: oneshift port map (inp => se6_opt, OneS=> '1' , output=> imm_pc);

  alu_b <= "0000000000000010" when taken_or_not1(to_integer(unsigned(sp_opt))) = '1' else imm_pc;
  
  pc_adding: alu3 port map (ALU3_A => PC1(to_integer(unsigned(sp_opt))), ALU3_B => alu_b, ALU3_C=>  next_pc);
  
--condition1 <='1' when (valid1(sp_opt) = '1' and exe1(sp_opt) = '1' ) and (branch1(sp_out) = '1');
--condition2 <= 

		
  
  
  L11: for i in 0 to 63 generate
	valid_select(i) <= "11" when (count = 0) else
			   "10" when ((i < to_integer(unsigned(sp_opt)) and (to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) or (FLUSH = '1' and i /= to_integer(unsigned(sp_opt)))) else 
			   "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2))  else 
			   "01" ;

	valid_from_decode <= valid_inp(0) when i = to_integer(unsigned(ep_next)) else valid_inp(1) when i = to_integer(unsigned(ep_next2)) else '0';
	mux1: mux4_1 port map (A => valid_from_decode , B => valid1(i), C => '0', D => '1' , S=> valid_select(i), Z=> valid(i));
	end generate L11;
  
	
  L12: for i in 0 to 63 generate
	spec_select(i) <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and (to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) ) or (branch_no = 0) else 
			  "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2))  else 
			  "01" ;

	spec_from_decoder <= spec_inp(0) when i = to_integer(unsigned(ep_next)) else spec_inp(1) when i = to_integer(unsigned(ep_next2)) else '0';
	mux1: mux3_1 port map (A => spec_from_decoder , B => spec1(i), C => '0', S=> spec_select(i), Z=> spec(i));
 end generate L12;
 
 
  L13: for i in 0 to 63 generate
	tag_select(i) <= "10" when (count = 0) or (i < to_integer(unsigned(sp_opt)) and (to_integer(unsigned(ep_opt)) >= to_integer(unsigned(sp_opt)) or i > to_integer(unsigned(ep_opt))) )  or (branch_no = 0) else 
			  "00" when i = to_integer(unsigned(ep_next)) or i = to_integer(unsigned(ep_next2)) else 
			  "01" ;

	tag_from_decoder <= tag_inp(0) when i = to_integer(unsigned(ep_next)) else tag_inp(1) when i = to_integer(unsigned(ep_next2)) else '0';
	mux1: mux3_1 port map (A => tag_from_decoder , B => tag1(i), C => '0', S=> tag_select(i), Z=> tag(i));
	end generate L13;							  
 
  ------------------- NB NB ----------------
  
   value_arf(15 downto 0) <= rrf_values(((to_integer(unsigned(rrf1(to_integer(unsigned(sp_opt)))))+1) *16 -1) downto (to_integer(unsigned(rrf1(to_integer(unsigned(sp_opt))))) * 16)) ; --value in rrf 
 
   															      --tags in arf															
   arf_busy(0) <= '0' when (rrf1(to_integer(unsigned(sp_opt))) = arf_tag(((to_integer(unsigned(dest1(to_integer(unsigned(sp_opt)))))+1)* 6 -1) downto (to_integer(unsigned(dest1(to_integer(unsigned(sp_opt))))* 6)) ) ) else '1'; --address of rrf should match tag of arf
   
   address_arf(2 downto 0) <= dest1((to_integer(unsigned(sp_opt))));
   
   valid_arf(0) <= '1' when (valid1((to_integer(unsigned(sp_opt)))) = '1' and write1((to_integer(unsigned(sp_opt)))) = '1') else '0';
   
   
   -- ARF_BUSY AS 0 MEANS MOST UPDATED AND 1 MEANS NOT YET UPDATED
  
   value_arf(31 downto 16) <= rrf_values((((to_integer(unsigned(rrf1(to_integer(unsigned(sp_next))))))+1) * 16 -1) downto (to_integer(unsigned(rrf1(to_integer(unsigned(sp_next))))) * 16)) ; --value in rrf 
 
   arf_busy(1) <= '0' when (rrf1(to_integer(unsigned(sp_opt))) = arf_tag(((to_integer(unsigned(dest1(to_integer(unsigned(sp_opt)))))+1)* 6 -1) downto ((to_integer(unsigned(dest1(to_integer(unsigned(sp_opt))))))* 6)) ) else '1'; --address of rrf should match tag of arf
  
   address_arf(5 downto 3) <= dest1((to_integer(unsigned(sp_next))));
   
   valid_arf(1) <= '1' when (valid1((to_integer(unsigned(sp_next)))) = '1' and write1((to_integer(unsigned(sp_next)))) = '1') else '0';
  
  -- NEED A WRITE BIT -- URGENT!!!!!!
 ----------------------------------------------------------------------------------- 
  
  c_valid <= write_carry1(to_integer(unsigned(sp_opt))) or write_carry1(to_integer(unsigned(sp_next))) ;
   
   arfc_busy <= '0' when (rrf_carry1(to_integer(unsigned(sp_next))) = arfc_tag and write_carry1(to_integer(unsigned(sp_next)))) 
   		else '0' when (rrf_carry1(to_integer(unsigned(sp_out))) = arfc_tag and write_carry1(to_integer(unsigned(sp_opt)))) 
   		else '1'; --address of rrf should match tag of arf
   
   arfz_busy <= '0' when (rrf_zero1(to_integer(unsigned(sp_next))) = arfz_tag and write_zero1(to_integer(unsigned(sp_next)))) 
   		else '0' when (rrf_zero1(to_integer(unsigned(sp_out))) = arfc_tag and write_zero1(to_integer(unsigned(sp_opt)))) 
   		else '1'; --address of rrf should match tag of arf
   
   z_valid <= write_zero1(to_integer(unsigned(sp_opt))) or write_zero1(to_integer(unsigned(sp_next))) ;
  
  ------------------------ END POINTER --------------------------------------------
  
  ep_next_update: alu3_6 port map (ALU3_A => ep_opt, ALU3_B => "000001", ALU3_C=>  ep_next);
  
  ep_next2_update : alu3_6 port map (ALU3_A => ep_opt, ALU3_B => "000010", ALU3_C=>  ep_next2);
  end_ptr_update: alu3_6 port map (ALU3_A => ep_opt, ALU3_B => "000010" , ALU3_C=> ep_inp);

  
  branch_handling_and_flush: process(valid1,sp_opt,exe1,branch1,rrf_values,rrf1,taken_or_not1)
    
	 begin
	 	
	    branch_result1 <= "00";
	    if ((valid1(to_integer(unsigned(sp_opt))) = '1' and exe1(to_integer(unsigned(sp_opt))) = '1' ) and flush_inst(to_integer(unsigned(sp_opt))) = '1') then 
	    		FLUSH <= '1';      
		        
			flush_PC <= '1' &  pc1(to_integer(unsigned(sp_opt)));
			flush_rs <= '1'; 
	    		
	    elsif (valid1(to_integer(unsigned(sp_opt))) = '1' and exe1(to_integer(unsigned(sp_opt))) = '1' ) then
         		if (branch1(to_integer(unsigned(sp_opt))) = '1') then 
			--and branch1(sp_out + 1) = '0' then
	        	-- to_integer(unsigned(rrf_values(((to_integer(unsigned(rrf1(sp_out)))+1) * 16 -1) downto ((to_integer(unsigned(rrf1(sp_out)))+1) * 16))) == 0,  z = Imm*2
                	-- to_integer(unsigned(rrf_values(((to_integer(unsigned(rrf1(sp_out)))+1) * 16 -1) downto ((to_integer(unsigned(rrf1(sp_out)))+1) * 16))) /= 0,  z = 2
                
      				if (rrf_values((((to_integer(unsigned(rrf1(to_integer(unsigned(sp_opt))))))+1) * 16 -1) downto (to_integer(unsigned(rrf1(to_integer(unsigned(sp_opt))))) * 16))(0) = taken_or_not1(to_integer(unsigned(sp_opt)))) then
						branch_no <= 0;
						branch_flag <= '1';   --tell decoder to make tag and speculation 0 
						FLUSH <= '0';
						flush_PC <= "00000000000000000";
						flush_rs <= '0';
						branch_result1 <= taken_or_not1(to_integer(unsigned(sp_opt))) & '1';
				else
						branch_no <= 0;
			
						branch_flag <= '1';
						FLUSH <= '1';      --make valid 0, rs ko batana hai flush ke baare me, aur decoder ko bhi batana about flush and PC to fetch from 
		        
						flush_PC <= '1' &  next_pc;
						flush_rs <= '1'; 
						branch_result1 <= not(taken_or_not1(to_integer(unsigned(sp_opt)))) & '1';
		        
	        		end if;
			elsif (branch1(to_integer(unsigned(sp_opt))) = '0' and branch1(to_integer(unsigned(sp_next))) = '1') then
					FLUSH <= '0';
					branch_flag <= '0';
		
					flush_PC <= "00000000000000000";
					flush_rs <= '0'; 
	      		else 	
					FLUSH <= '0';
					branch_flag <= '0';
		
					flush_PC <= "00000000000000000";
	        			flush_rs <= '0'; 
			end if;
  	else
		FLUSH <= '0';
		branch_flag <= '0';
	
        	flush_PC <= "00000000000000000";
        	flush_rs <= '0'; 
  	end if;
	 
end process branch_handling_and_flush ;	 


store_handling: process(valid1,sp_opt,exe1,branch1,rrf_values,rrf1,taken_or_not1)
    variable flag: std_logic:='0';
	 begin
	    if (valid1(to_integer(unsigned(sp_opt))) = '1' and exe1(to_integer(unsigned(sp_opt))) = '1') then
	    
         		if (inst1(to_integer(unsigned(sp_opt)))(15 downto 12) = "0101") then 
			           
			           store_signal <= '1';
			           flag:= '1';
			end if;		
		
  	    
  	    end if;
  	    if (valid1(to_integer(unsigned(sp_next))) = '1' and exe1(to_integer(unsigned(sp_next))) = '1' ) then
	    
         		if (inst1(to_integer(unsigned(sp_next)))(15 downto 12) = "0101") then 
			           
			           store_signal <= '1';
			           flag:= '1';
			end if;			
		
  	   
  	    end if;
  	    
  	     if(flag = '0') then
			store_signal <= '0';
	     end if;
	 
end process store_handling ;	 

carry_zero_handling: process
    
	 begin
	    if (valid1(to_integer(unsigned(sp_next))) = '1' and exe1(to_integer(unsigned(sp_next))) = '1' ) then
	    
         		if (write_carry1(to_integer(unsigned(sp_next))) = '1') then 
			           
			           c_out <= rrf_carry_values(((to_integer(unsigned(rrf_carry1(to_integer(unsigned(sp_next)))))))) ; --value in rrf ;
			end if;		
		
  	    elsif (valid1(to_integer(unsigned(sp_next))) = '1' and exe1(to_integer(unsigned(sp_next))) = '1' ) then
	    
         		if (write_carry1(to_integer(unsigned(sp_opt))) = '1') then 
			           
			           c_out <= rrf_carry_values(((to_integer(unsigned(rrf_carry1(to_integer(unsigned(sp_next)))))))) ; --value in rrf ;
			end if;		
					
		
  	    else
			c_out <= '0' ; 
		
  	    end if;
	 
	 if (valid1(to_integer(unsigned(sp_next))) = '1' and exe1(to_integer(unsigned(sp_next))) = '1' ) then
	    
         		if (write_zero(to_integer(unsigned(sp_next))) = '1') then 
			           
			           z_out <= rrf_zero_values(((to_integer(unsigned(rrf_zero1(to_integer(unsigned(sp_next)))))))) ;  --value in rrf ;
			end if;		
		
  	    elsif (valid1(to_integer(unsigned(sp_next))) = '1' and exe1(to_integer(unsigned(sp_next))) = '1' ) then
	    
         		if (write_zero(to_integer(unsigned(sp_opt))) = '1') then 
			           
			           z_out <= rrf_zero_values(((to_integer(unsigned(rrf_zero1(to_integer(unsigned(sp_opt)))))))) ; --value in rrf ;
			end if;		
					
		
  	    else
			z_out <= '0' ; 
		
  	    end if;
end process carry_zero_handling ;

flush_due_to_load_queue: process
    
	 begin
	    if (flush_from_load_queue(16) = '1') then
	    
         		for i in 0 to 64 loop
         			if (busy1(i) = '1' and pc1(i) = flush_from_load_queue(15 downto 0)) then 
         				flush_inst(i)<= '1';
         			else
         				flush_inst(i)<= flush_inst(i);
					end if;
				end loop;
	    else
			for i in 0 to 64 loop
	    		flush_inst(i)<= flush_inst(i);
			end loop;
  	    end if;
	 
	
end process flush_due_to_load_queue ;	 	

branch_result <= branch_result1;
  
end bhv;
