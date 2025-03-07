library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;


entity res_station_store is
    generic(
        size : integer := 32
        -- this defines the size of the reservation station
        -- the double priority encoder also depends on this value
    );

    port(
        clk: in std_logic;
        reset: in std_logic;
        from_decoder1: in std_logic_vector(82 downto 0);
        from_decoder2: in std_logic_vector(82 downto 0);
        --inst_valid-pc1-inst-op1-valid1-op2-valid2-imm
        --(16+16+16+1+16+1+16) = 82 bits

        data_from_rrf: in std_logic_vector(1023 downto 0);
        signal_ROB:  in std_logic;
        -- if 1, means it is on top of ROB nd can be written in mem_data
       

        validbits_fromrrf: in std_logic_vector(63 downto 0);
        
        load_queue_address: in std_logic_vector(511 downto 0);
        load_queue_pc: in std_logic_vector(511 downto 0);
        load_queue_busy: in std_logic_vector(31 downto 0);
        load_queue_ep_out: in std_logic_vector(4 downto 0);
        
        store_choose : in std_logic;
        
        load_queue_throw: out std_logic_vector(31 downto 0);
       
        to_store_pipeline : out std_logic_vector(64 downto 0)
       	-- valid - inst - pc - dest - mem_address
        
        
        );
			
end res_station_store;

architecture rs_arch of res_station_store is 

function add(A: in std_logic_vector(4 downto 0);
        B: in std_logic_vector(4 downto 0))
        return std_logic_vector is
        variable sum : std_logic_vector(4 downto 0);
        variable carry : std_logic_vector(4 downto 0);
        begin
        L1 : for i in 0 to 4 loop
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

function add16(A: in std_logic_vector(15 downto 0);
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
        end add16;
        
    component ff_5 is 
		port(En,clock,reset:in std_logic; D1: in std_logic_vector(4 downto 0); Q:out std_logic_vector(4 downto 0));
    end component ff_5;

    -- defining datatypes for the columns
    -- each is a table of with number of rows equal to the size
    type datatype_5 is array(size-1 downto 0) of std_logic_vector(4 downto 0);
    type datatype_6 is array(size-1 downto 0) of std_logic_vector(5 downto 0);
    type datatype_8 is array(size-1 downto 0) of std_logic_vector(7 downto 0);
    type datatype_9 is array(size-1 downto 0) of std_logic_vector(8 downto 0);
    type datatype_16 is array(size-1 downto 0) of std_logic_vector(15 downto 0);


    -- we start defining the columns as signals
    -- busy bit signifies which rows of the rs have valid instructions in them.
    -- as soon as instruction is issued, busy bit goes to 0.
    signal busy_bit: std_logic_vector(size-1 downto 0):=(others=>'0');

    --consisting of the instructions
    signal inst: datatype_16:=(others=>(others=>'0'));

	 
	 
    --program counter,operands and valid bits of the operand for the instructions
    signal pc: datatype_16:=(others=>(others=>'0'));
    -- need to be 16 bits as data can be 2 bytes ? (regardless keeping life simple)
    signal regA: datatype_16:=(others=>(others=>'0'));
    signal regB: datatype_16:=(others=>(others=>'0'));
    signal address: datatype_16:=(others=>(others=>'0'));
    -- these are single bit wide columns of length size
    signal valid_A: std_logic_vector(size-1 downto 0):=(others=>'0');
    signal valid_B: std_logic_vector(size-1 downto 0):=(others=>'0');
    signal immediate: datatype_16:=(others=>(others=>'0'));

   
    signal ep_load_queue: datatype_5:=(others=>(others=>'0'));
   
       
    -- we need bit denoting whether the instruction is ready to be executed
    signal ready_bit: std_logic_vector(size-1 downto 0):=(others=>'0'); -- calculated using operand valid bits.
    -- prev_issues now redundant, putting busy bit instead #3
    -- signal prev_issued: std_logic_vector(size-1 downto 0):=(others=>'0');
    
    signal sp_inp, ep_inp: std_logic_vector(4 downto 0) := (others=>'0');
    signal sp_out, ep_out: std_logic_vector(4 downto 0) := (others=>'0');
    signal ep_next : std_logic_vector(4 downto 0);

    -------------------------------------------------------------------
    begin
    -- here we start writing processes for the actual fucntions performed by the rs
	 
---------------------------------------------------------------------------------------------------------------
--###########################  RS  INPUT  #####################################################################
    
    startpointerff : ff_5 port map (D1 => sp_inp, En=> '1' ,clock => clk, reset=> reset, Q=> sp_out);
  
    endpointerff   : ff_5 port map (D1 => ep_inp, En=> '1' ,clock => clk, reset=> reset, Q=> ep_out); 
  
    reset_process:process(reset)
    begin
        if(reset='1') then
            busy_bit <= (others=>'0');
        end if;
    end process;

    
    
    -- ENTRY
    rs_loader_datapath: process(clk,from_decoder1,from_decoder2, ep_out)
    --distribution of signal "from_decoder1"
    
    begin
        if (from_decoder1(82)= '1') then
            --if address one is valid
            --pc1-inst-op1-valid1-op2-valid2-imm
            --(16+16+16+1+16+1+16) = 82 bits
            busy_bit(to_integer(unsigned(ep_out)) ) <= '1'; 
            pc     (to_integer(unsigned(ep_out)) ) <= from_decoder1(81 downto 66);
            inst   (to_integer(unsigned(ep_out)) ) <= from_decoder1(65 downto 50);
            regA   (to_integer(unsigned(ep_out)) ) <= from_decoder1(49 downto 34);
            valid_A(to_integer(unsigned(ep_out)) ) <= from_decoder1(33);
            regB   (to_integer(unsigned(ep_out)) ) <= from_decoder1(32 downto 17);
            valid_B(to_integer(unsigned(ep_out)) ) <= from_decoder1(16);
            immediate(to_integer(unsigned(ep_out)) ) <= from_decoder1(15 downto 0);
            
            ep_load_queue(to_integer(unsigned(ep_out)) ) <= add (load_queue_ep_out, "00000"); 
            
            ep_next<= add (ep_out, "00001");
         
         else 
            ep_next<= ep_out;
         
         end if ;


        if (from_decoder2(82)= '1') then
            -- if address two is valid
            --pc1-inst-op1-valid1-op2-valid2-imm
            --(16+16+16+1+16+1+16) = 82 bits
            busy_bit(to_integer(unsigned(ep_next)) ) <= '1'; 
            pc      (to_integer(unsigned(ep_next)) ) <= from_decoder2(81 downto 66);
            inst    (to_integer(unsigned(ep_next)) ) <= from_decoder2(65 downto 50);
            regA    (to_integer(unsigned(ep_next)) ) <= from_decoder2(49 downto 34);
            valid_A (to_integer(unsigned(ep_next)) ) <= from_decoder2(33);
            regB    (to_integer(unsigned(ep_next)) ) <= from_decoder2(32 downto 17);
            valid_B (to_integer(unsigned(ep_next)) ) <= from_decoder2(16);
            immediate(to_integer(unsigned(ep_next)) ) <= from_decoder2(15 downto 0);
            
            ep_load_queue(to_integer(unsigned(ep_next)) ) <= add (load_queue_ep_out, "00000"); 
            
            ep_inp<= add (ep_next, "00001");
        else
            ep_inp<= ep_next;
        end if;
    
    end process;

------------------------------------------------------------------------------------------------------------------
--###########################  RS  INTERNAL PROCESSES  ###########################################################


    -- just calculating the ready bit for the instruction based on valid bits of operands.
    -- will be different conditions for different instructions
    ready_bit_calculator: process(clk)
    begin
        if (reset='1') then
            ready_bit<= (others => '0');
        else
            for i in 0 to size-1 loop
                    if(busy_bit(i) = '1') then               
							  ready_bit(i) <= valid_A(i) and valid_B(i); 
							  address (i) <= add16 (regB(i), immediate( i)); 
						  end if;
            end loop;
        end if;
    end process ready_bit_calculator;

-- endptr calculation remaining

    rs_data_update: process
    --it needs to check the rrf in each cycle
    --refreshing rs data entries each cycle
    -- we take a 1024 bits wide signal from the rrf which gives all the data in it.
    -- then each entry of the rs takes the required segment of it.
    begin
        for i in 0 to size-1 loop
            if (valid_A(i)='0' and busy_bit(i)='1' and validbits_fromrrf(to_integer(unsigned(regA(i)(5 downto 0))))='1') then
                regA(i) <= data_from_rrf(((to_integer(unsigned(regA(i)(5 downto 0)))+1)*16 -1) downto ((to_integer(unsigned(regA(i)(5 downto 0))))*16));
                valid_A(i)<='1';
            end if;

            if (valid_B(i)='0' and busy_bit(i)='1' and validbits_fromrrf(to_integer(unsigned(regB(i)(5 downto 0))))='1') then
                regB(i) <= data_from_rrf(((to_integer(unsigned(regB(i)(5 downto 0)))+1)*16 -1) downto ((to_integer(unsigned(regB(i)(5 downto 0))))*16));
                valid_B(i) <= '1';
            end if;
        end loop;
    end process;

------------------------------------------------------------------------------------------------------
    
    -- EXIT
    -- Need signal from ROB which tells that instruction could be released to pipeline after inst is ready...
    -- Check Load queue while exiting
    
    scheduling_datapath: process(clk, store_choose)
    
    	variable load_queue_throw1: std_logic_vector(31 downto 0):=(others => '0');
    	variable flag: std_logic:= '0';
        begin
    	
    	if((ready_bit(to_integer(unsigned(sp_out))) = '1') and (signal_ROB = '1') and (store_choose = '1')) then
            to_store_pipeline(15 downto 0) <=  address(to_integer(unsigned(sp_out)));  --mem_address (reg_B + immediate)
            to_store_pipeline(31 downto 16) <= regA(to_integer(unsigned(sp_out)));     --mem_data
            to_store_pipeline(47 downto 32) <= pc(to_integer(unsigned(sp_out)));  	   --pc
            to_store_pipeline(63 downto 48) <= inst(to_integer(unsigned(sp_out)));  	   --inst
            to_store_pipeline(64) <= '1';  			   --valid
		
            busy_bit(to_integer(unsigned(sp_out))) <= '0';
            sp_inp <= add(sp_out, "00001");
		
            for i in to_integer(unsigned(ep_load_queue(to_integer(unsigned(sp_out))))) to 31 loop
                if (load_queue_busy(i) = '1') then
                    if(load_queue_address((i+1)*16 downto 16*i) = address(to_integer(unsigned(sp_out))) and flag = '0') then
                        load_queue_throw1(i) := '1';
                        flag := '1';
                    end if;
                end if;
            end loop;
		    load_queue_throw <= load_queue_throw1;
			
	    else
            to_store_pipeline <= (others=>'0');
            sp_inp <= sp_out; 
            load_queue_throw <= (others=>'0');
	    end if;
    
    end process;

end rs_arch;
