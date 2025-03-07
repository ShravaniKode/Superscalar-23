library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity decode_stage is 

		port(clock,reset:in std_logic; pc_inp : in std_logic_vector(15 downto 0); 
		
		busybits_from_arf: in std_logic_vector(7 downto 0);
		busybit_from_zero : in std_logic;
		tags_from_arf: in std_logic_vector(47 downto 0);
		arf_values : in std_logic_vector(127 downto 0);
		
		busybit_from_carry: in std_logic;
		tag_from_carry: in std_logic_vector(5 downto 0);
		carry_value : in std_logic;
		
		rrf_carry_values : in std_logic_vector(63 downto 0);
		valid_from_rrf_carry : in std_logic_vector(63 downto 0);
		
		rrf_values : in std_logic_vector(1023 downto 0);
		valid_from_rrf: in std_logic_vector(63 downto 0);
		
		busybits_from_rrf: in std_logic_vector(63 downto 0);
		busybits_from_rrf_carry: in std_logic_vector(63 downto 0);
		busybits_from_rrf_zero : in std_logic_vector(63 downto 0);
		
		FLUSH: in std_logic_vector(16 downto 0);
		branch_flag: in std_logic;
		
		branch_result:  in std_logic_vector(1 downto 0);
		---------------------------------------------------------
		rrf_zero_values : in std_logic_vector (63 downto 0);
		
		valid_from_rrf_zero: in std_logic_vector(63 downto 0);
		zero_value : in std_logic;
		tag_from_zero : in std_logic_vector (5 downto 0);
		-------------------------------------------------------------
	
		
		busyout, write_out: out std_logic_vector(1 downto 0); 
		
		spec_out, tag_out: out std_logic_vector(1 downto 0); 
		branch_bit, valid_out: out std_logic_vector(1 downto 0); 
		taken_or_not : out std_logic_vector(1 downto 0);
		
		tags_to_arf : out std_logic_vector(11 downto 0);
		address_to_arf_tag : out std_logic_vector(5 downto 0);
		valid_to_arf_tag : out std_logic_vector(1 downto 0);
		
		tags_to_carry : out std_logic_vector(11 downto 0);
		valid_to_carry_tag : out std_logic_vector(1 downto 0);
		
		tags_to_zero : out std_logic_vector(11 downto 0);
		valid_to_zero_tag : out std_logic_vector(1 downto 0);
		
		carry_write : out std_logic_vector(1 downto 0);
		zero_write  : out std_logic_vector(1 downto 0);
		
		valid_opr1_inst1, valid_opr2_inst1 : out std_logic;

		valid_opr1_inst2, valid_opr2_inst2 : out std_logic;
		
		opr1_inst1, opr1_inst2, opr2_inst1, opr2_inst2 : out std_logic_vector(15 downto 0) ;--:= (others => '0');
		--opr1_inst1, opr1_inst1 :out std_logic_vector(15 downto 0)
		
	    	dest : out std_logic_vector(5 downto 0);

		valid_carry_inst1, valid_carry_inst2: out std_logic; carry_inst1, carry_inst2: out std_logic_vector (5 downto 0);
		valid_zero_inst1, valid_zero_inst2: out std_logic; zero_inst1, zero_inst2: out std_logic_vector (5 downto 0);

		

		
		busybits_to_rrf_update: out std_logic_vector(63 downto 0);
		busybits_to_rrf_carry_update: out std_logic_vector(63 downto 0);
		busybits_to_rrf_zero_update : out std_logic_vector(63 downto 0);
		
		PC_out: out std_logic_vector(31 downto 0);
		inst_out: out std_logic_vector(31 downto 0);
		
		rrf_1_assigned_out: out std_logic_vector(15 downto 0); rrf_2_assigned_out: out std_logic_vector(15 downto 0)
		
	        
	    );
	
	 
end entity decode_stage;


architecture behav of decode_stage is
function add(A: in std_logic_vector(15 downto 0);
        B: in std_logic_vector(15 downto 0))
        return std_logic_vector is
        variable sum : std_logic_vector(15 downto 0);
        variable carry : std_logic_vector(15 downto 0);
        begin
        L1 : for i in 0 to 15 loop
                    if i = 0 then 
                        sum(i) := ((A(i) xor B(i)) xor '0');
                            carry(i) := (A(i) and B(i));
                            
                    else 
                        sum(i) := A(i) xor B(i) xor carry(i-1);
                        carry(i) := (A(i) and B(i)) or  (carry(i-1) and ( A(i) or B(i) ));
                    end if;
                    end loop L1;
        return  sum;       
        end add;

function priority_encoder64(A: in std_logic_vector(63 downto 0))
        return std_logic_vector is
        	variable count: integer:= 0;

		variable flag: std_logic:= '0';
		
		variable opt1: std_logic_vector(5 downto 0) := (others => '0');
		
        begin
		
		count:= 0;

		flag:='0';
		L1: for i in 0 to 63 loop
				
				if(A(63-i)='0' and flag='0') then
					 count := 63-i;
					 flag := '1';
				end if;
				end loop L1;
		opt1 := std_logic_vector(to_unsigned(count, 6)) ; 
		return opt1;
end priority_encoder64;

component Memory_inst is
		port(clock, mem_rd: in std_logic; mem_add: in std_logic_vector(15 downto 0);  mem_out: out std_logic_vector(31 downto 0) );
end component Memory_inst;

component ff_16 is 
		port(En,clock,reset:in std_logic; D1: in std_logic_vector(15 downto 0); Q:out std_logic_vector(15 downto 0));
end component ff_16;

component  ff_1 is 
		port(D1, En,clock,reset:in std_logic; Q:out std_logic);
	end component  ff_1;

component SignE6 is 
	port(input1: in std_logic_vector(5 downto 0); se6: in std_logic; output: out std_logic_vector(15 downto 0));
end component SignE6;

component oneshift is
	port (inp :in std_logic_vector(15 downto 0); OneS: in std_logic; output: out std_logic_vector(15 downto 0));
end component oneshift;

component adder is
	port (A, B: in std_logic_vector(15 downto 0); carry_in: in std_logic; C: out std_logic_vector(15 downto 0));
end component adder;

--component priority_encoder64 is 
--	port(inst: in std_logic_vector(63 downto 0); output: out std_logic_vector(5 downto 0));
--end component priority_encoder64;

component branch_predictor is 
    port( clk:in std_logic; reset: in std_logic; result_in: in std_logic; valid_in: in std_logic;
        --whenever valid bit goes from low to high, we read the true result of the branch at top of rob
        prediction_out: out std_logic);
end component branch_predictor;

signal PC, PC1 : std_logic_vector(15 downto 0) := pc_inp;
--signal opr1_inst1, opr1_inst2, opr2_inst1, opr2_inst1 : std_logic_vector(15 downto 0) := (others => '0');
signal  PC_update_by : std_logic_vector(15 downto 0) := (others => '0');




signal inst: std_logic_vector(31 downto 0) := (others => '0');

signal predicted: std_logic := '0';

signal valid: std_logic_vector (1 downto 0) := "11";
signal if_branch: std_logic_vector (1 downto 0) := "11";

signal rrf_needed : std_logic_vector(1 downto 0) := "10";    --rrf_needed(1) if 1 tells inst 1 needs rrf, rrf_needed(0) if 1 tells inst 2 needs rrf
signal throw : std_logic_vector(1 downto 0) := "00";
signal rrf_c_needed : std_logic_vector(1 downto 0) := "10";  --rrf_c_needed(1) if 1 tells inst 1 needs rrf_c, rrf_c_needed(0) if 1 tells inst 2 needs rrf_c (modifies carry)
signal rrf_z_needed : std_logic_vector(1 downto 0) := "10";  --rrf_z_needed(1) if 1 tells inst 1 needs rrf_z, rrf_z_needed(0) if 1 tells inst 2 needs rrf_z (modifies zero)

signal next_valid, next_valid1: std_logic := '0';

signal prev_JLR, prev_JLR1: std_logic := '0';
signal prev_JRI, prev_JRI1: std_logic := '0';
--signal carry_inst1: std_logic := '0';

signal rrf_1_assigned, rrf_2_assigned: std_logic_vector(15 downto 0);
signal rrf_1c_assigned, rrf_2c_assigned: std_logic_vector(5 downto 0);
signal rrf_1z_assigned, rrf_2z_assigned: std_logic_vector(5 downto 0);

signal num_of_branch, num_of_branch1: std_logic := '0';

signal En : std_logic:= '1';
signal dest1: std_logic_vector(5 downto 0);

begin

      PC_ff: ff_16 port map(En => En,clock => clock,reset => reset, D1=> PC, Q=> PC1);
      
      mem_inst: Memory_inst port map(clock => clock, mem_rd => '1' , mem_add => PC1 ,  mem_out=> inst);
      
      next_valid_ff: ff_1 port map(En => En,clock => clock,reset => reset, D1=> next_valid , Q=> next_valid1 );
      
      prev_JLR_ff: ff_1 port map(En => En,clock => clock,reset => reset, D1=> prev_JLR , Q=> prev_JLR1 );
      
      prev_JRI_ff: ff_1 port map(En => En,clock => clock,reset => reset, D1=> prev_JRI , Q=> prev_JRI1 );
      
      bp: branch_predictor port map( clk => clock,  reset => reset , result_in=> branch_result(1), valid_in => branch_result(0), prediction_out => predicted);    --predicted is 0 means not taken else taken
      
      bno: ff_1 port map(En => En,clock => clock,reset => reset, D1=> num_of_branch , Q=> num_of_branch1 );
      
      taken_or_not <= predicted & predicted;
      
      PC <= PC_update_by;
      
      PC_out(31 downto 16) <= PC1;
      PC_out(15 downto 0) <= add(PC1, "0000000000000010");
      
      rrf_1_assigned_out <= rrf_1_assigned;
      rrf_2_assigned_out <= rrf_2_assigned;
      
      inst_out<= inst;
      flush_proc: process(flush)
      begin
      		if(flush(16) = '1') then 
      			PC_update_by <= flush(15 downto 0);
      			throw <= "11";
      		else
			PC_update_by <= PC1;
		end if;
      		
      end process flush_proc; 
      
      decode_proc: process( clock)
      variable rrf_to_check : integer := 0;
      variable r1: integer := 0;
      variable r2: integer := 0;
      variable r3: integer := 0;
      variable r4: integer := 0;
      variable busybits_to_rrf_update1: std_logic_vector(63 downto 0);
      variable busybits_to_rrf_carry_update1: std_logic_vector(63 downto 0);
      variable busybits_to_rrf_zero_update1: std_logic_vector(63 downto 0);
      
      variable write_bits: std_logic_vector(1 downto 0);
      variable flag_1: std_logic := '0';
      
      
      begin
      		--num_of_branch <= 
      		
      		valid <= "11";
      		if_branch <= "00";
      		next_valid <= '1';
      		prev_JLR <= '0';
      		prev_JRI <= '0';
      	
      		r1 := to_integer(unsigned(inst(24 downto 22)));
      		r2 := to_integer(unsigned(inst(27 downto 25)));
      		r3 := to_integer(unsigned(inst(8 downto 6)));
      		r4 := to_integer(unsigned(inst(11 downto 9)));
      		
      		rrf_needed <= "00";
      		rrf_c_needed <= "00";
      		rrf_z_needed <= "00";
      		
      		PC_update_by <= add (PC1,"0000000000000100") ;
      		
      		busybits_to_rrf_update <= busybits_from_rrf;
      		
      		valid_to_arf_tag <= "00";
      		write_bits := "00";
      		
      		dest1 <= "000000";
      		
      		
      		
      		if (branch_flag = '1') then
      			num_of_branch <= not(num_of_branch1);
      		else
      			num_of_branch <= num_of_branch1;
      		end if;
      		
      		if (prev_JLR1 = '1' and next_valid1= '0') then
      		
      			if (valid_from_rrf(rrf_to_check) = '1') then
      				PC_update_by <= rrf_values( (((rrf_to_check +1)*16)-1) downto (rrf_to_check*16) );
      				prev_JLR <= '0';
      			else 
      				PC_update_by <= PC1;
      				next_valid <= '0';   --make valid of next instructions 0
      				prev_JLR <= '1';
      				rrf_to_check := rrf_to_check;
      			end if;
     		
      			
      		elsif (prev_JRI1 = '1' and next_valid1= '0') then
      			if (valid_from_rrf(rrf_to_check) = '1') then
      				PC_update_by <= add( rrf_values( (((rrf_to_check +1)*16)-1) downto (rrf_to_check*16) ), std_logic_vector(to_unsigned(to_integer(unsigned(inst(24 downto 16)))*2, 16)));
      				prev_JRI <= '0';
      			else 
      				PC_update_by <= PC1;
      				next_valid <= '0';   --make valid of next instructions 0
      				prev_JRI <= '1';
      				rrf_to_check := rrf_to_check;
      			end if;
      			
      		elsif ((num_of_branch1 = '1' and branch_flag = '0') and (inst(31 downto 28) = "1000" or inst(31 downto 28) = "1001" or inst(31 downto 28) = "1010")) then --I1 is conditional branch (BEQ, BLT, BLE)
      			
      			valid <= "00";
      			PC_update_by <= PC1;
      			
      			
      		elsif (((num_of_branch1 = '1' and branch_flag = '1') or num_of_branch1 = '0') and (inst(31 downto 28) = "1000" or inst(31 downto 28) = "1001" or inst(31 downto 28) = "1010")) then --I1 is conditional branch (BEQ, BLT, BLE)
      		
      			if (busybits_from_arf(r2) = '0') then --most updated opr1
      				opr1_inst1 <= arf_values( (((r2+1)*16)-1) downto (r2*16) );
      				
      				valid_opr1_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3)))) = '1') then
      				
      				opr1_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))*16) );
      				valid_opr1_inst1 <= '1';
      			else 
      				opr1_inst1 <= "0000000000" & tags_from_arf(((r2+1)*3-1) downto r2*3);
      				valid_opr1_inst1 <= '0';
      			end if;
      			
      			if (busybits_from_arf(r1) = '0') then --most updated opr2
      				opr2_inst1 <= arf_values( (((r1+1)*16)-1) downto (r1*16) );
      				valid_opr2_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3)))) = '1') then
      				
      				opr2_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))*16) );
      				valid_opr2_inst1 <= '1';
      			else 
      				opr2_inst1 <= "0000000000" & tags_from_arf(((r1+1)*3-1) downto r1*3);
      				valid_opr2_inst1 <= '0';
      			end if;
      			
      			valid(0) <= '0';
      			if_branch(1) <= '1';
      			rrf_needed(1) <= '1';
      			rrf_needed(0) <= '0';
      			
      			if(predicted = '0') then
      				PC_update_by <= add(PC1, "0000000000000010");
      			else 
      				PC_update_by <= add (PC1 , std_logic_vector(to_unsigned(to_integer(unsigned(inst(21 downto 16)))*2, 16))) ;
      				 --std_logic_vector(to_unsigned(to_integer(unsigned(inst(21 downto 16)))*2, 16)) ;
      				--PC_update_by <= PC1 + "000000000" & inst(21 downto 16) & "0" ;
      			end if;
      			
      			num_of_branch <= '1';
      			spec_out <= "01";
      			tag_out  <= "01";
      			
      		
      		elsif (inst(31 downto 28) = "1100") then  --JAL
      		
      			rrf_needed(1) <= '1';
      			valid(0) <= '0';
      			rrf_needed(0) <= '0';
      			
      			PC_update_by <= add(PC1 , std_logic_vector(to_signed(to_integer(signed(inst(24 downto 16)))*2, 16)) );
      			write_bits(1) := '0';
      			dest1(5 downto 3) <= inst(27 downto 25);
      			
      		elsif (inst(31 downto 28) = "1101") then  --JLR
      		
      			if (busybits_from_arf(r1) = '0') then --most updated
      				PC_update_by <= arf_values( (((r1+1)*16)-1) downto (r1*16) );
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3)))) = '1') then
      			
      				PC_update_by <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))*16) );
      			else 
      				PC_update_by <= add(PC1 , "0000000000000000");
      				next_valid <= '0';   --make valid of next instructions 0
      				prev_JLR <= '1';
      				rrf_to_check := to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3)));
      			end if;
      			
      			rrf_needed(1) <= '1';
      			valid(0) <= '0';
      			rrf_needed(0) <= '0';
      			write_bits(1) := '1';
      			dest1(5 downto 3) <= inst(27 downto 25);
      			
      			
      		elsif (inst(31 downto 28) = "1111") then  --JRI
      		
      			if (busybits_from_arf(r2) = '0') then --most updated
      				PC_update_by <= add(arf_values ((((r2+1)*16)-1) downto (r2*16) ), std_logic_vector(to_unsigned(to_integer(unsigned(inst(24 downto 16)))*2, 16)));
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3)))) = '1') then
      			
      				PC_update_by <= add(rrf_values( ((((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))*16) ) , std_logic_vector(to_unsigned(to_integer(unsigned(inst(24 downto 16)))*2, 16)));
      				
      			else 
      				PC_update_by <= add(PC1 , "0000000000000000");
      				next_valid <= '0';   --make valid of next instructions 0
      				prev_JRI <= '1';
      				rrf_to_check := to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3)));
      			end if;
      			
      			rrf_needed(1) <= '0';
      			valid(0) <= '0';
      			rrf_needed(0) <= '0';
      					
      		elsif (inst(31 downto 28) = "0001" and( inst(18 downto 16) = "000" or inst(18 downto 16) = "100")) then --ADA, ACA
      		
      			if (busybits_from_arf(r2) = '0') then --most updated opr1
      				opr1_inst1 <= arf_values( (((r2+1)*16)-1) downto (r2*16) );
      				valid_opr1_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3)))) = '1') then
      				
      				opr1_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))*16) );
      				valid_opr1_inst1 <= '1';
      			else 
      				opr1_inst1 <= "0000000000" & tags_from_arf(((r2+1)*3-1) downto r2*3);
      				valid_opr1_inst1 <= '0';
      			end if;
      			
      			if (busybits_from_arf(r1) = '0') then --most updated opr2
      				opr2_inst1 <= arf_values( (((r1+1)*16)-1) downto (r1*16) );
      				valid_opr2_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3)))) = '1') then
      				
      				opr2_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))*16) );
      				valid_opr2_inst1 <= '1';
      			else 
      				opr2_inst1 <= "0000000000" & tags_from_arf(((r1+1)*3-1) downto r1*3);
      				valid_opr2_inst1 <= '0';
      			end if;
      			
      			rrf_needed(1) <= '1';
      			rrf_c_needed(1) <= '1';
      			rrf_z_needed(1) <= '1';
      			write_bits(1) := '1';
      			dest1(5 downto 3) <= inst(21 downto 19);
      			
      		elsif (inst(31 downto 28) = "0010" and( inst(18 downto 16) = "000" or inst(18 downto 16) = "100")) then --NDU, NCU
      		
      			if (busybits_from_arf(r2) = '0') then --most updated opr1
      				opr1_inst1 <= arf_values( (((r2+1)*16)-1) downto (r2*16) );
      				valid_opr1_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3)))) = '1') then
      				
      				opr1_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))*16) );
      				valid_opr1_inst1 <= '1';
      			else 
      				opr1_inst1 <= "0000000000" & tags_from_arf(((r2+1)*3-1) downto r2*3);
      				valid_opr1_inst1 <= '0';
      			end if;
      			
      			if (busybits_from_arf(r1) = '0') then --most updated opr2
      				opr2_inst1 <= arf_values( (((r1+1)*16)-1) downto (r1*16) );
      				valid_opr2_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3)))) = '1') then
      				
      				opr2_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))*16) );
      				valid_opr2_inst1 <= '1';
      			else 
      				opr2_inst1 <= "0000000000" & tags_from_arf(((r1+1)*3-1) downto r1*3);
      				valid_opr2_inst1 <= '0';
      			end if;
      			
      			rrf_needed(1) <= '1';
      			rrf_c_needed(1) <= '0';
      			rrf_z_needed(1) <= '1';
      			write_bits(1) := '1';
      			dest1(5 downto 3) <= inst(21 downto 19);
      		
      		elsif (inst(31 downto 28) = "0001" and (inst(17 downto 16) = "10" or inst(17 downto 16) = "11")) then --ADC, AWC, ACW, ACC
      		
      			if (busybits_from_arf(r2) = '0') then --most updated opr1
      				opr1_inst1 <= arf_values( (((r2+1)*16)-1) downto (r2*16) );
      				valid_opr1_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3)))) = '1') then
      				
      				opr1_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))*16) );
      				valid_opr1_inst1 <= '1';
      			else 
      				opr1_inst1 <= "0000000000" & tags_from_arf(((r2+1)*3-1) downto r2*3);
      				valid_opr1_inst1 <= '0';
      			end if;
      			
      			if (busybits_from_arf(r1) = '0') then --most updated opr2
      				opr2_inst1 <= arf_values( (((r1+1)*16)-1) downto (r1*16) );
      				valid_opr2_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3)))) = '1') then
      				
      				opr2_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))*16) );
      				valid_opr2_inst1 <= '1';
      			else 
      				opr2_inst1 <= "0000000000" & tags_from_arf(((r1+1)*3-1) downto r1*3);
      				valid_opr2_inst1 <= '0';
      			end if;
      			
      			if (busybit_from_carry = '0') then --most updated carry
      				carry_inst1 <= "00000" & carry_value;
      				valid_carry_inst1 <= '1';
      				
      			elsif (valid_from_rrf_carry(to_integer(unsigned(tag_from_carry))) = '1') then
      				
      				carry_inst1 <= "00000" & rrf_carry_values(to_integer(unsigned(tag_from_carry)));
      				valid_carry_inst1 <= '1';
      			else 
      				carry_inst1 <= tag_from_carry;
      				valid_carry_inst1 <= '0';
      			end if;
      			
      			rrf_needed(1) <= '1';
      			rrf_c_needed(1) <= '1';
      			rrf_z_needed(1) <= '1';
      			write_bits(1) := '1';
      			dest1(5 downto 3) <= inst(21 downto 19);
      			
      		elsif (inst(31 downto 28) = "0010" and inst(17 downto 16) = "10") then                                --NCC, NDC
      			
      			if (busybits_from_arf(r2) = '0') then --most updated opr1
      				opr1_inst1 <= arf_values( (((r2+1)*16)-1) downto (r2*16) );
      				valid_opr1_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3)))) = '1') then
      				
      				opr1_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))*16) );
      				valid_opr1_inst1 <= '1';
      			else 
      				opr1_inst1 <= "0000000000" & tags_from_arf(((r2+1)*3-1) downto r2*3);
      				valid_opr1_inst1 <= '0';
      			end if;
      			
      			if (busybits_from_arf(r1) = '0') then --most updated opr2
      				opr2_inst1 <= arf_values( (((r1+1)*16)-1) downto (r1*16) );
      				valid_opr2_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3)))) = '1') then
      				
      				opr2_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))*16) );
      				valid_opr2_inst1 <= '1';
      			else 
      				opr2_inst1 <= "0000000000" & tags_from_arf(((r1+1)*3-1) downto r1*3);
      				valid_opr2_inst1 <= '0';
      			end if;
      			
      			if (busybit_from_carry = '0') then --most updated carry
      				carry_inst1 <= "00000" & carry_value;
      				valid_carry_inst1 <= '1';
      				
      			elsif (valid_from_rrf_carry(to_integer(unsigned(tag_from_carry))) = '1') then
      				
      				carry_inst1 <= "00000" & rrf_carry_values(to_integer(unsigned(tag_from_carry)));
      				valid_carry_inst1 <= '1';
      			else 
      				carry_inst1 <= tag_from_carry;
      				valid_carry_inst1 <= '0';
      			end if;
      			
      			rrf_needed(1) <= '1';
      			rrf_c_needed(1) <= '0';
      			rrf_z_needed(1) <= '1';
      			write_bits(1) := '1';
      			dest1(5 downto 3) <= inst(21 downto 19);
      			
      		elsif (inst(31 downto 28) = "0001" and inst(17 downto 16) = "01") then                                --ADZ, ACZ
      		
      			if (busybits_from_arf(r2) = '0') then --most updated opr1
      				opr1_inst1 <= arf_values( (((r2+1)*16)-1) downto (r2*16) );
      				valid_opr1_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3)))) = '1') then
      				
      				opr1_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))*16) );
      				valid_opr1_inst1 <= '1';
      			else 
      				opr1_inst1 <= "0000000000" & tags_from_arf(((r2+1)*3-1) downto r2*3);
      				valid_opr1_inst1 <= '0';
      			end if;
      			
      			if (busybits_from_arf(r1) = '0') then --most updated opr2
      				opr2_inst1 <= arf_values( (((r1+1)*16)-1) downto (r1*16) );
      				valid_opr2_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3)))) = '1') then
      				
      				opr2_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))*16) );
      				valid_opr2_inst1 <= '1';
      			else 
      				opr2_inst1 <= "0000000000" & tags_from_arf(((r1+1)*3-1) downto r1*3);
      				valid_opr2_inst1 <= '0';
      			end if;
      			
      			if (busybit_from_zero =  '0') then --most updated zero
      				zero_inst1 <= "00000" & zero_value;
      				valid_zero_inst1 <= '1';
      				
      			elsif (valid_from_rrf_zero(to_integer(unsigned(tag_from_zero))) = '1') then
      				
      				zero_inst1 <= "00000" & rrf_zero_values(to_integer(unsigned(tag_from_zero)));
      				valid_zero_inst1 <= '1';
      			else 
      				zero_inst1 <= tag_from_zero;
      				valid_zero_inst1 <= '0';
      			end if;
      			
      			rrf_needed(1) <= '1';
      			rrf_c_needed(1) <= '1';
      			rrf_z_needed(1) <= '1';
      			write_bits(1) := '1';
      			dest1(5 downto 3) <= inst(21 downto 19);
      			
      		elsif (inst(31 downto 28) = "0010" and inst(17 downto 16) = "01") then                                --NDZ, NCZ
      			if (busybits_from_arf(r2) = '0') then --most updated opr1
      				opr1_inst1 <= arf_values( (((r2+1)*16)-1) downto (r2*16) );
      				valid_opr1_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3)))) = '1') then
      				
      				opr1_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))*16) );
      				valid_opr1_inst1 <= '1';
      			else 
      				opr1_inst1 <= "0000000000" & tags_from_arf(((r2+1)*3-1) downto r2*3);
      				valid_opr1_inst1 <= '0';
      			end if;
      			
      			if (busybits_from_arf(r1) = '0') then --most updated opr2
      				opr2_inst1 <= arf_values( (((r1+1)*16)-1) downto (r1*16) );
      				valid_opr2_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3)))) = '1') then
      				
      				opr2_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))*16) );
      				valid_opr2_inst1 <= '1';
      			else 
      				opr2_inst1 <= "0000000000" & tags_from_arf(((r1+1)*3-1) downto r1*3);
      				valid_opr2_inst1 <= '0';
      			end if;
      			
      			if (busybit_from_zero =  '0') then --most updated zero
      				zero_inst1 <= "00000" & zero_value;
      				valid_zero_inst1 <= '1';
      				
      			elsif (valid_from_rrf_zero(to_integer(unsigned(tag_from_zero))) = '1') then
      				
      				zero_inst1 <= "00000" & rrf_zero_values(to_integer(unsigned(tag_from_zero)));
      				valid_zero_inst1 <= '1';
      			else 
      				zero_inst1 <= tag_from_zero;
      				valid_zero_inst1 <= '0';
      			end if;
      			
      			rrf_needed(1) <= '1';
      			rrf_c_needed(1) <= '0';
      			rrf_z_needed(1) <= '1';
      			write_bits(1) := '1';
      			dest1(5 downto 3) <= inst(21 downto 19);
      		
      			
      		elsif (inst(31 downto 28) = "0000") then                                                              --ADI
      			if (busybits_from_arf(r2) = '0') then --most updated opr1
      				opr1_inst1 <= arf_values( (((r2+1)*16)-1) downto (r2*16) );
      				valid_opr1_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3)))) = '1') then
      				
      				opr1_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))*16) );
      				valid_opr1_inst1 <= '1';
      			else 
      				opr1_inst1 <= "0000000000" & tags_from_arf(((r2+1)*3-1) downto r2*3);
      				valid_opr1_inst1 <= '0';
      			end if;
      			
      			opr2_inst1 <=  "0000000000" & inst(5 downto 0);
	      		valid_opr2_inst1 <= '1';
      			
      			rrf_needed(1) <= '1';
      			rrf_c_needed(1) <= '1';
      			rrf_z_needed(1) <= '1';
      			write_bits(1) := '1';
      			dest1(5 downto 3) <= inst(24 downto 22);
      			
      		elsif (inst(31 downto 28) = "0011") then  				                              --LLI
      		
      			opr1_inst1 <=  "0000000" & inst(24 downto 16);
      			valid_opr1_inst1 <= '1';
      			
      			rrf_needed(1) <= '1';
      			rrf_c_needed(1) <= '0';
      			rrf_z_needed(1) <= '0';
      			write_bits(1) := '1';
      			dest1(5 downto 3) <= inst(27 downto 25);
      			
      		elsif (inst(31 downto 28) = "0100") then  				                              --LW
      		
      			if (busybits_from_arf(r1) = '0') then --most updated opr2
      				opr2_inst1 <= arf_values( (((r1+1)*16)-1) downto (r1*16) );
      				valid_opr2_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3)))) = '1') then
      				
      				opr2_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))*16) );
      				valid_opr2_inst1 <= '1';
      			else 
      				opr2_inst1 <= "0000000000" & tags_from_arf(((r1+1)*3-1) downto r1*3);
      				valid_opr2_inst1 <= '0';
      			end if;
      			
			opr2_inst1 <= std_logic_vector(to_signed(to_integer(signed(inst(21 downto 16))), 16));
			valid_opr2_inst1 <= '1';
      				
      		
      			rrf_needed(1)   <= '1';
      			rrf_c_needed(1) <= '0';
      			rrf_z_needed(1) <= '1';
      			write_bits(1) := '1';
      			dest1(5 downto 3) <= inst(27 downto 25);
      			
      		elsif (inst(31 downto 28) = "0101") then  				                              --SW
      			
      			if (busybits_from_arf(r2) = '0') then --most updated opr1
      				opr1_inst1 <= arf_values( (((r2+1)*16)-1) downto (r2*16) );
      				valid_opr1_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3)))) = '1') then
      				
      				opr1_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r2+1)*3-1) downto r2*3))))*16) );
      				valid_opr1_inst1 <= '1';
      			else 
      				opr1_inst1 <= "0000000000" & tags_from_arf(((r2+1)*3-1) downto r2*3);
      				valid_opr1_inst1 <= '0';
      			end if;
      			
      			if (busybits_from_arf(r1) = '0') then --most updated opr2
      				opr2_inst1 <= arf_values( (((r1+1)*16)-1) downto (r1*16) );
      				valid_opr2_inst1 <= '1';
      				
      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3)))) = '1') then
      				
      				opr2_inst1 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r1+1)*3-1) downto r1*3))))*16) );
      				valid_opr2_inst1 <= '1';
      			else 
      				opr2_inst1 <= "0000000000" & tags_from_arf(((r1+1)*3-1) downto r1*3);
      				valid_opr2_inst1 <= '0';
      			end if;
      			
      		
      			rrf_1_assigned <= std_logic_vector(to_signed(to_integer(signed(inst(21 downto 16))), 16));
      			
      			rrf_needed(1)  <= '0';
      			rrf_c_needed(1) <= '0';
      			rrf_z_needed(1) <= '0';
      				
      		end if;
      		
      		
      		
      		if (inst(31 downto 28) /= "1000" or inst(31 downto 28) /= "1001" or inst(31 downto 28) /= "1010" or inst(31 downto 28) /= "1100" or inst(31 downto 28) /= "1101" or inst(31 downto 28) /= "1111" or prev_JLR1 /= '1' or prev_JRI1 /= '1') then
      		
      			if ((num_of_branch1 = '1' and branch_flag = '0') and (inst(31 downto 28) = "1000" or inst(31 downto 28) = "1001" or inst(31 downto 28) = "1010")) then --I1 is conditional branch (BEQ, BLT, BLE)
      			
      				valid(0) <= '0';
      				PC_update_by <= add(PC1 , "0000000000000010");
      				if_branch(0) <= '0';
	      			rrf_needed(0) <= '0';
      				
	      		elsif (((num_of_branch1 = '1' and branch_flag = '1') or num_of_branch1 = '0') and (inst(31 downto 28) = "1000" or inst(31 downto 28) = "1001" or inst(31 downto 28) = "1010")) then --I2 is conditional branch (BEQ, BLT, BLE)
	      		
	      			if_branch(0) <= '1';
	      			rrf_needed(0) <= '1';
	      			
	      			if(predicted = '0') then
	      				PC_update_by <= add(PC1 ,"0000000000000100");
	      			else 
	      				PC_update_by <= add(PC1 , std_logic_vector(to_unsigned((to_integer(unsigned(inst(5 downto 0)))*2) + 2, 16))) ;
	      			end if;
	      			
	      		elsif (inst(15 downto 12) = "1100") then  --JAL
      		
	      			rrf_needed(0) <= '1';
	      			--valid(0) <= '1';
	      			
	      			PC_update_by <= add(PC1 , std_logic_vector(to_unsigned(to_integer(unsigned(inst(8 downto 0)))*2 + 2, 16))) ;
	      			
	      			dest1(2 downto 0) <= inst(11 downto 9);
	      			
	      			write_bits(0) := '1';
	      			
	      			
      			elsif (inst(15 downto 12) = "1101") then  --JLR
      		
	      			if (busybits_from_arf(r3) = '0') then --most updated
	      				PC_update_by <= arf_values( (((r3+1)*16)-1) downto (r3*16) );
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3)))) = '1') then
	      			
	      				PC_update_by <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))*16) );
	      			else 
	      				PC_update_by <= add(PC1 ,"0000000000000010");
	      				next_valid <= '0';   --make valid of next instructions 0
	      				prev_JLR <= '1';
	      				rrf_to_check := to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3)));
	      			end if;
	      			
	      			rrf_needed(0) <= '1';
	      			--valid(0) <= '1';
	      			
	      			write_bits(0) := '1';
	      			dest1(2 downto 0) <= inst(11 downto 9);
	      			
      			elsif (inst(15 downto 12) = "1111") then  --JRI
      		
	      			if (busybits_from_arf(r4) = '0') then --most updated
	      				PC_update_by <= add(arf_values ((((r4+1)*16)-1) downto (r4*16) ), std_logic_vector(to_unsigned(to_integer(unsigned(inst(8 downto 0)))*2, 16)));
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3)))) = '1') then
	      			
	      				PC_update_by <= add(rrf_values( ((((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))*16) ) , std_logic_vector(to_unsigned(to_integer(unsigned(inst(8 downto 0)))*2, 16)));
	      				
	      			else 
	      				PC_update_by <= add(PC1, "0000000000000010");
	      				next_valid <= '0';   --make valid of next instructions 0
	      				prev_JRI <= '1';
	      				rrf_to_check := to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3)));
	      			end if;
	      			
	      			rrf_needed(0) <= '0';
	 			--valid(0) <= '1';
	      			
	      			
      			elsif (inst(15 downto 12) = "0001" and( inst(15 downto 12) = "000" or inst(15 downto 12) = "100")) then --ADA, ACA
      		
	      			if (busybits_from_arf(r4) = '0') then --most updated opr1
	      				opr1_inst2 <= arf_values( (((r4+1)*16)-1) downto (r4*16) );
	      				valid_opr1_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3)))) = '1') then
	      				
	      				opr1_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))*16) );
	      				valid_opr1_inst2 <= '1';
	      			else 
	      				opr1_inst2 <= "0000000000" & tags_from_arf(((r4+1)*3-1) downto r4*3);
	      				valid_opr1_inst2 <= '0';
	      			end if;
	      			
	      			if (busybits_from_arf(r3) = '0') then --most updated opr2
	      				opr2_inst2 <= arf_values( (((r3+1)*16)-1) downto (r3*16) );
	      				valid_opr2_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3)))) = '1') then
	      				
	      				opr2_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))*16) );
	      				valid_opr2_inst2 <= '1';
	      			else 
	      				opr2_inst2 <= "0000000000" & tags_from_arf(((r3+1)*3-1) downto r3*3);
	      				valid_opr2_inst2 <= '0';
	      			end if;
	      			
	      			rrf_needed(0) <= '1';
	      			rrf_c_needed(0) <= '1';
	      			rrf_z_needed(0) <= '1';
	      			write_bits(0) := '1';
	      			dest1(2 downto 0) <= inst(5 downto 3);
	      			
	      		elsif (inst(15 downto 12) = "0010" and( inst(2 downto 0) = "000" or inst(2 downto 0) = "100")) then --NDU, NCU
      		
	      			if (busybits_from_arf(r4) = '0') then --most updated opr1
	      				opr1_inst2 <= arf_values( (((r4+1)*16)-1) downto (r4*16) );
	      				valid_opr1_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3)))) = '1') then
	      				
	      				opr1_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))*16) );
	      				valid_opr1_inst2 <= '1';
	      			else 
	      				opr1_inst2 <= "0000000000" & tags_from_arf(((r4+1)*3-1) downto r4*3);
	      				valid_opr1_inst2 <= '0';
	      			end if;
	      			
	      			if (busybits_from_arf(r3) = '0') then --most updated opr2
	      				opr2_inst2 <= arf_values( (((r3+1)*16)-1) downto (r3*16) );
	      				valid_opr2_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3)))) = '1') then
	      				
	      				opr2_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))*16) );
	      				valid_opr2_inst2 <= '1';
	      			else 
	      				opr2_inst2 <= "0000000000" & tags_from_arf(((r3+1)*3-1) downto r3*3);
	      				valid_opr2_inst2 <= '0';
	      			end if;
	      			
	      			rrf_needed(0) <= '1';
	      			rrf_c_needed(0) <= '0';
	      			rrf_z_needed(0) <= '1';
	      			write_bits(0) :=  '1';
	      			dest1(2 downto 0) <= inst(5 downto 3);
	      			
	      			
      			elsif (inst(15 downto 12) = "0001" and (inst(1 downto 0) = "10" or inst(1 downto 0) = "11")) then --ADC, AWC, ACW, ACC
      		
	      			if (busybits_from_arf(r4) = '0') then --most updated opr1
	      				opr1_inst2 <= arf_values( (((r4+1)*16)-1) downto (r4*16) );
	      				valid_opr1_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3)))) = '1') then
	      				
	      				opr1_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))*16) );
	      				valid_opr1_inst2 <= '1';
	      			else 
	      				opr1_inst2 <= "0000000000" & tags_from_arf(((r4+1)*3-1) downto r4*3);
	      				valid_opr1_inst2 <= '0';
	      			end if;
	      			
	      			if (busybits_from_arf(r3) = '0') then --most updated opr2
	      				opr2_inst2 <= arf_values( (((r3+1)*16)-1) downto (r3*16) );
	      				valid_opr2_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3)))) = '1') then
	      				
	      				opr2_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))*16) );
	      				valid_opr2_inst2 <= '1';
	      			else 
	      				opr2_inst2 <= "0000000000" & tags_from_arf(((r3+1)*3-1) downto r3*3);
	      				valid_opr2_inst2 <= '0';
	      			end if;
      			
	      			if (busybit_from_carry = '0') then --most updated carry
	      				carry_inst2 <= "00000" & carry_value;
	      				valid_carry_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf_carry(to_integer(unsigned(tag_from_carry))) = '1') then
	      				
	      				carry_inst2 <= "00000" & rrf_carry_values(to_integer(unsigned(tag_from_carry)));
	      				valid_carry_inst2 <= '1';
	      			else 
	      				carry_inst2 <= tag_from_carry;
	      				valid_carry_inst2 <= '0';
	      			end if;
	      			
	      			rrf_needed(0) <= '1';
	      			rrf_c_needed(0) <= '1';
	      			rrf_z_needed(0) <= '1';
	      			write_bits(0):=  '1';
	      			dest1(2 downto 0) <= inst(5 downto 3);
	      			
	      		elsif (inst(15 downto 12) = "0010" and inst(1 downto 0) = "10") then                                --NCC, NDC
	      		
      				if (busybits_from_arf(r4) = '0') then --most updated opr1
	      				opr1_inst2 <= arf_values( (((r4+1)*16)-1) downto (r4*16) );
	      				valid_opr1_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3)))) = '1') then
	      				
	      				opr1_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))*16) );
	      				valid_opr1_inst2 <= '1';
	      			else 
	      				opr1_inst2 <= "0000000000" & tags_from_arf(((r4+1)*3-1) downto r4*3);
	      				valid_opr1_inst2 <= '0';
	      			end if;
	      			
	      			if (busybits_from_arf(r3) = '0') then --most updated opr2
	      				opr2_inst2 <= arf_values( (((r3+1)*16)-1) downto (r3*16) );
	      				valid_opr2_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3)))) = '1') then
	      				
	      				opr2_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))*16) );
	      				valid_opr2_inst2 <= '1';
	      			else 
	      				opr2_inst2 <= "0000000000" & tags_from_arf(((r3+1)*3-1) downto r3*3);
	      				valid_opr2_inst2 <= '0';
	      			end if;
      			
	      			if (busybit_from_carry = '0') then --most updated carry
	      				carry_inst2 <= "00000" & carry_value;
	      				valid_carry_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf_carry(to_integer(unsigned(tag_from_carry))) = '1') then
	      				
	      				carry_inst2 <= "00000" & rrf_carry_values(to_integer(unsigned(tag_from_carry)));
	      				valid_carry_inst2 <= '1';
	      			else 
	      				carry_inst2 <= tag_from_carry;
	      				valid_carry_inst2 <= '0';
	      			end if;
	      			
	      			rrf_needed(0) <= '1';
	      			rrf_c_needed(0) <= '0';
	      			rrf_z_needed(0) <= '1';
	      			write_bits(0) :=  '1';
	      			dest1(2 downto 0) <= inst(5 downto 3);
	      			
	      		elsif (inst(31 downto 28) = "0001" and inst(17 downto 16) = "01") then                                --ADZ, ACZ
      		
	      			if (busybits_from_arf(r4) = '0') then --most updated opr1
	      				opr1_inst2 <= arf_values( (((r4+1)*16)-1) downto (r4*16) );
	      				valid_opr1_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3)))) = '1') then
	      				
	      				opr1_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))*16) );
	      				valid_opr1_inst2 <= '1';
	      			else 
	      				opr1_inst2 <= "0000000000" & tags_from_arf(((r4+1)*3-1) downto r4*3);
	      				valid_opr1_inst2 <= '0';
	      			end if;
	      			
	      			if (busybits_from_arf(r3) = '0') then --most updated opr2
	      				opr2_inst2 <= arf_values( (((r3+1)*16)-1) downto (r3*16) );
	      				valid_opr2_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3)))) = '1') then
	      				
	      				opr2_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))*16) );
	      				valid_opr2_inst2 <= '1';
	      			else 
	      				opr2_inst2 <= "0000000000" & tags_from_arf(((r3+1)*3-1) downto r3*3);
	      				valid_opr2_inst2 <= '0';
	      			end if;
	      			
	      			if (busybit_from_zero =  '0') then --most updated zero
	      				zero_inst2 <= "00000" & zero_value;
	      				valid_zero_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf_zero(to_integer(unsigned(tag_from_zero))) = '1') then
	      				
	      				zero_inst2 <= "00000" & rrf_zero_values(to_integer(unsigned(tag_from_zero)));
	      				valid_zero_inst2 <= '1';
	      			else 
	      				zero_inst2 <= tag_from_zero;
	      				valid_zero_inst2 <= '0';
	      			end if;
	      			
	      			rrf_needed(0) <= '1';
	      			rrf_c_needed(0) <= '1';
	      			rrf_z_needed(0) <= '1';
	      			write_bits(0) :=  '1';
	      			
	      			dest1(2 downto 0) <= inst(5 downto 3);
	      			
      			elsif (inst(15 downto 12) = "0010" and inst(1 downto 0) = "01") then                                --NDZ, NCZ
      			
	      			if (busybits_from_arf(r4) = '0') then --most updated opr1
	      				opr1_inst2 <= arf_values( (((r4+1)*16)-1) downto (r4*16) );
	      				valid_opr1_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3)))) = '1') then
	      				
	      				opr1_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))*16) );
	      				valid_opr1_inst2 <= '1';
	      			else 
	      				opr1_inst2 <= "0000000000" & tags_from_arf(((r4+1)*3-1) downto r4*3);
	      				valid_opr1_inst2 <= '0';
	      			end if;
	      			
	      			if (busybits_from_arf(r3) = '0') then --most updated opr2
	      				opr2_inst2 <= arf_values( (((r3+1)*16)-1) downto (r3*16) );
	      				valid_opr2_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3)))) = '1') then
	      				
	      				opr2_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))*16) );
	      				valid_opr2_inst2 <= '1';
	      			else 
	      				opr2_inst2 <= "0000000000" & tags_from_arf(((r3+1)*3-1) downto r3*3);
	      				valid_opr2_inst2 <= '0';
	      			end if;
	      			
	      			if (busybit_from_zero =  '0') then --most updated zero
	      				zero_inst2 <= "00000" & zero_value;
	      				valid_zero_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf_zero(to_integer(unsigned(tag_from_zero))) = '1') then
	      				
	      				zero_inst2 <= "00000" & rrf_zero_values(to_integer(unsigned(tag_from_zero)));
	      				valid_zero_inst2 <= '1';
	      			else 
	      				zero_inst2 <= tag_from_zero;
	      				valid_zero_inst2 <= '0';
	      			end if;
	      			
      			
	      			rrf_needed(0) <= '1';
	      			rrf_c_needed(0) <= '0';
	      			rrf_z_needed(0) <= '1';
	      			write_bits(0) := '1';
	      			
	      			dest1(2 downto 0) <= inst(5 downto 3);
      			
      			elsif (inst(15 downto 12) = "0000") then                                                              --ADI
      			
	      			if (busybits_from_arf(r4) = '0') then --most updated opr1
	      				opr1_inst2 <= arf_values( (((r4+1)*16)-1) downto (r4*16) );
	      				valid_opr1_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3)))) = '1') then
	      				
	      				opr1_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))*16) );
	      				valid_opr1_inst2 <= '1';
	      			else 
	      				opr1_inst2 <= "0000000000" & tags_from_arf(((r4+1)*3-1) downto r4*3);
	      				valid_opr1_inst2 <= '0';
	      			end if;
	      		
	      			
	      			opr2_inst2 <=  "0000000000" & inst(5 downto 0);
	      			valid_opr2_inst2 <= '1';
	      			
	      			rrf_needed(0) <= '1';
	      			rrf_c_needed(0) <= '1';
	      			rrf_z_needed(0) <= '1';
	      			write_bits(0) := '1';
	      			
	      			dest1(2 downto 0) <= inst(8 downto 6);
	      			
	      		elsif (inst(15 downto 12) = "0011") then  				                              --LLI
      		
	      			opr1_inst2 <=  "0000000" & inst(8 downto 0);
	      			valid_opr1_inst2 <= '1';
	      			
	      			rrf_needed(0) <= '1';
	      			rrf_c_needed(0) <= '0';
	      			rrf_z_needed(0) <= '0';
	      			write_bits(0) :=  '1';
	      			
	      			dest1(2 downto 0) <= inst(11 downto 9);
      			
      			elsif (inst(15 downto 12) = "0100") then  				                              --LW
	      			
	      			
	      			if (busybits_from_arf(r3) = '0') then --most updated opr2
	      				opr2_inst2 <= arf_values( (((r3+1)*16)-1) downto (r3*16) );
	      				valid_opr2_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3)))) = '1') then
	      				
	      				opr2_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))*16) );
	      				valid_opr2_inst2 <= '1';
	      			else 
	      				opr2_inst2 <= "0000000000" & tags_from_arf(((r3+1)*3-1) downto r3*3);
	      				valid_opr2_inst2 <= '0';
	      			end if;
	      			
      			
				opr2_inst2 <= std_logic_vector(to_signed(to_integer(signed(inst(5 downto 0))), 16));
				valid_opr2_inst2 <= '1';
	      				
	      		
	      			
	      			rrf_needed(0)   <= '1';
	      			rrf_c_needed(0) <= '0';
	      			rrf_z_needed(0) <= '1';
	      			write_bits(0) := '1';
	      			dest1(2 downto 0) <= inst(11 downto 9);
      			
      			elsif (inst(31 downto 28) = "0101") then  				                              --SW
      			
	      			if (busybits_from_arf(r4) = '0') then --most updated opr1
	      				opr1_inst2 <= arf_values( (((r4+1)*16)-1) downto (r4*16) );
	      				valid_opr1_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3)))) = '1') then
	      				
	      				opr1_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r4+1)*3-1) downto r4*3))))*16) );
	      				valid_opr1_inst2 <= '1';
	      			else 
	      				opr1_inst2 <= "0000000000" & tags_from_arf(((r4+1)*3-1) downto r4*3);
	      				valid_opr1_inst2 <= '0';
	      			end if;
	      			
	      			if (busybits_from_arf(r3) = '0') then --most updated opr2
	      				opr2_inst2 <= arf_values( (((r3+1)*16)-1) downto (r3*16) );
	      				valid_opr2_inst2 <= '1';
	      				
	      			elsif (valid_from_rrf(to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3)))) = '1') then
	      				
	      				opr2_inst2 <= rrf_values( ((((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))+1)*16)-1) downto ((to_integer(unsigned(tags_from_arf(((r3+1)*3-1) downto r3*3))))*16) );
	      				valid_opr2_inst2 <= '1';
	      			else 
	      				opr2_inst2 <= "0000000000" & tags_from_arf(((r3+1)*3-1) downto r3*3);
	      				valid_opr2_inst2 <= '0';
	      			end if;
	      			
      				rrf_2_assigned<= std_logic_vector(to_signed(to_integer(signed(inst(5 downto 0))), 16));
      				
	      			rrf_needed(0)  <= '0';
	      			rrf_c_needed(0) <= '0';
	      			rrf_z_needed(0) <= '0';
      			end if;
      	end if;
	busybits_to_rrf_update1       := busybits_from_rrf;
	busybits_to_rrf_carry_update1 := busybits_from_rrf_carry;
	busybits_to_rrf_zero_update1  := busybits_from_rrf_zero;
	flag_1 := '0';
	
	if (rrf_needed(0) = '1') then
		
		rrf_2_assigned <= std_logic_vector(to_unsigned(to_integer(unsigned(priority_encoder64(busybits_to_rrf_update1))), 16));
		busybits_to_rrf_update1(to_integer(unsigned(rrf_2_assigned))) := '1';
		if ( write_bits(0) = '1') then
      			valid_to_arf_tag(0) <= '1';
      			tags_to_arf(5 downto 0) <= rrf_2_assigned(5 downto 0);
      			address_to_arf_tag(2 downto 0) <= dest1(2 downto 0);
      			flag_1 := '1';
      		else
	
			valid_to_arf_tag(0) <= '0';
      			tags_to_arf(5 downto 0) <= rrf_2_assigned(5 downto 0);
      			address_to_arf_tag(2 downto 0) <= dest1(2 downto 0);
      		end if;
      	else
		valid_to_arf_tag(0) <= '0';
		tags_to_arf(5 downto 0) <= "000000";
		address_to_arf_tag(2 downto 0) <= dest1(2 downto 0);
      	end if;
      		
	if (rrf_needed(1) = '1') then
		
		rrf_1_assigned <= std_logic_vector(to_unsigned(to_integer(unsigned(priority_encoder64(busybits_to_rrf_update1))), 16));
		busybits_to_rrf_update1(to_integer(unsigned(rrf_1_assigned))) := '1';
		if ( write_bits(1) = '1' and (dest1(5 downto 3) /= dest1(2 downto 0) or flag_1 = '0')) then
      			valid_to_arf_tag(1) <= '1';
      			tags_to_arf(11 downto 6) <= rrf_1_assigned(5 downto 0);
      			address_to_arf_tag(5 downto 3) <= dest1(5 downto 3);
		else
			valid_to_arf_tag(1) <= '0';
      			tags_to_arf(11 downto 6) <= rrf_1_assigned(5 downto 0);
      			address_to_arf_tag(5 downto 3) <= dest1(5 downto 3);
      		end if;
      	else
		valid_to_arf_tag(1) <= '0';
		tags_to_arf(11 downto 6) <= "000000";
		address_to_arf_tag(5 downto 3) <= dest1(5 downto 3);
	end if;
	
	
	if (rrf_c_needed(0) = '1') then
		
		rrf_2c_assigned <= priority_encoder64(busybits_to_rrf_carry_update1) ;
		busybits_to_rrf_carry_update1(to_integer(unsigned(rrf_2c_assigned))) := '1';
		
		valid_to_carry_tag(0) <= '1';
		tags_to_carry(5 downto 0) <= rrf_2c_assigned;
	else
		valid_to_carry_tag(0) <= '0';
		tags_to_carry(5 downto 0) <= "000000";
	end if;
      	
      		
	if (rrf_c_needed(1) = '1') then
		
		rrf_1c_assigned <= priority_encoder64(busybits_to_rrf_carry_update1);
		busybits_to_rrf_carry_update1(to_integer(unsigned(rrf_1c_assigned))) := '1';
		if (rrf_c_needed(0) /= '1') then
      			valid_to_carry_tag(1) <= '1';
			tags_to_carry(11 downto 6) <= rrf_1c_assigned;
		else
			valid_to_carry_tag(1) <= '0';
			tags_to_carry(11 downto 6) <= "000000";
      		end if;
      	else
		valid_to_carry_tag(1) <= '0';
		tags_to_carry(11 downto 6) <= "000000";
	end if;
	
	if (rrf_z_needed(0) = '1') then
		
		rrf_2z_assigned <= priority_encoder64(busybits_to_rrf_zero_update1);
		busybits_to_rrf_zero_update1(to_integer(unsigned(rrf_2z_assigned))) := '1';
		
		valid_to_zero_tag(0) <= '1';
		tags_to_zero(5 downto 0) <= rrf_2z_assigned;
	else
		valid_to_zero_tag(0) <= '0';
		tags_to_zero(5 downto 0) <= "000000";
	end if;
      		
	if (rrf_z_needed(1) = '1') then
		
		rrf_1z_assigned <= priority_encoder64(busybits_to_rrf_zero_update1);
		busybits_to_rrf_zero_update1(to_integer(unsigned(rrf_1z_assigned))) := '1';
		if (rrf_z_needed(1) /= '1') then
      			valid_to_zero_tag(1) <= '1';
			tags_to_zero(11 downto 6) <= rrf_1z_assigned;
		else
			valid_to_zero_tag(1) <= '0';
			tags_to_zero(11 downto 6) <= "000000";
      		end if;
      	else
		valid_to_zero_tag(1) <= '0';
		tags_to_zero(11 downto 6) <= "000000";
	end if;
      		
	if (num_of_branch1 = '1' and branch_flag = '1') then
		tag_out <= "00";
		spec_out <= "00";
	elsif (num_of_branch1 = '1' and branch_flag = '0') then
		tag_out <= "11";
		spec_out <= "11";
	elsif (num_of_branch1 = '0' and branch_flag = '0' and (if_branch(1) = '0' and if_branch(0) = '0')) then
		tag_out <= "00";
		spec_out <= "00";
	elsif (num_of_branch1 = '0' and branch_flag = '0' and (if_branch(1) = '1' and if_branch(0) = '0')) then
		tag_out <= "01";
		spec_out <= "01";
	elsif (num_of_branch1 = '0' and branch_flag = '0' and (if_branch(1) = '0' and if_branch(0) = '1')) then
		tag_out <= "00";
		spec_out <= "00";
	else
		tag_out <= "00";
		spec_out <= "00";
	end if;
      		
      		
      --end process decode_proc;
      write_out <= write_bits;
      busybits_to_rrf_update <= busybits_to_rrf_update1;
      busybits_to_rrf_carry_update <= busybits_to_rrf_carry_update1;
      busybits_to_rrf_zero_update <= busybits_to_rrf_zero_update1;
      
      dest <= dest1;
      end process;
 --end if;     

	  branch_bit <= if_branch;
	  valid_out <= "00" when (throw = "11") else valid;
	  busyout <= "00" when (throw = "11") else valid;
	  
      carry_write <= rrf_c_needed;
      zero_write <= rrf_z_needed;
end behav;
