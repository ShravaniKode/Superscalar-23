library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LoadQueue is
	
	port(
	    clk: in std_logic;
        reset: in std_logic;
        from_decoder1: in std_logic_vector(88 downto 0);
        from_decoder2: in std_logic_vector(88 downto 0);
        --inst_valid-destZ[6]-pc1-inst-op1-valid1-op2-valid2-dest
        --(1+6+16+16+16+1+16+1+16) = 89 bits

        data_from_rrf: in std_logic_vector(1023 downto 0);
        validbits_fromrrf: in std_logic_vector(63 downto 0);
        
        
        load_queue_throw: in std_logic_vector(31 downto 0);
        --from_lspipeline : in std_logic_vector(32 downto 0);
        --valid - pc - address
        
        from_rob_exit_pc : in std_logic_vector(33 downto 0);
        --valid1(if_load)-pc1--valid2-pc2
        
        load_choose : in std_logic;
        
        load_queue_address: out std_logic_vector(511 downto 0);
        load_queue_pc: 	    out std_logic_vector(511 downto 0);
        load_queue_busy:    out std_logic_vector(31 downto 0);
        load_queue_ep_out:  out std_logic_vector(4 downto 0);
       
       	to_store_pipeline: out std_logic_vector(69 downto 0);
       	-- valid - destZ- inst - pc - dest - mem_address
       
       	to_flush_to_rob : out std_logic_vector(16 downto 0)
       	-- to_flush_valid - flush_PC 
       	
        );
	
end LoadQueue;

architecture bhv of LoadQueue is

    type datatype_4 is array(31 downto 0) of std_logic_vector(3 downto 0);
    type datatype_6 is array(31 downto 0) of std_logic_vector(5 downto 0);
    type datatype_8 is array(31 downto 0) of std_logic_vector(7 downto 0);
    type datatype_9 is array(31 downto 0) of std_logic_vector(8 downto 0);
    type datatype_16 is array(31 downto 0) of std_logic_vector(15 downto 0);



    component ff_5 is 
        port(D1: in std_logic_vector(4 downto 0);En,clock,reset:in std_logic ; Q:out std_logic_vector(4 downto 0));
    end component ff_5;

    function add(A: in std_logic_vector(4 downto 0);
        B: in std_logic_vector(4 downto 0);
        c: in std_logic)
        return std_logic_vector is
        variable sum : std_logic_vector(4 downto 0);
        variable carry : std_logic_vector(4 downto 0);
        begin
        L1 : for i in 0 to 4 loop
                    if i = 0 then 
                        sum(i) := ((A(i) xor B(i)) xor c);
                            carry(i) := (A(i) and B(i));
                            
                    else 
                        sum(i) := A(i) xor B(i) xor carry(i-1);
                        carry(i) := (A(i) and B(i)) or  (carry(i-1) and ( A(i) or B(i) ));
                    end if;
                    end loop L1;
        return carry(4) & sum;       
        end add;
    
    function add16(A: in std_logic_vector(15 downto 0);
        B: in std_logic_vector(15 downto 0);
        c: in std_logic)
        return std_logic_vector is
        variable sum : std_logic_vector(15 downto 0);
        variable carry : std_logic_vector(15 downto 0);
        begin
        L1 : for i in 0 to 15 loop
                    if i = 0 then 
                        sum(i) := ((A(i) xor B(i)) xor c);
                            carry(i) := (A(i) and B(i));
                            
                    else 
                        sum(i) := A(i) xor B(i) xor carry(i-1);
                        carry(i) := (A(i) and B(i)) or  (carry(i-1) and ( A(i) or B(i) ));
                    end if;
                    end loop L1;
        return carry(15) & sum;       
        end add16;


    -- we start defining the columns as signals
    signal busy_bit: std_logic_vector(31 downto 0):=(others=>'0');
    signal ready_bit: std_logic_vector(31 downto 0):=(others=>'0');
    signal throw: std_logic_vector(31 downto 0):=(others=>'0');
    signal execute: std_logic_vector(31 downto 0):=(others=>'0');
    
    signal address: datatype_16:=(others=>(others=>'0'));
  
    signal pc: datatype_16:=(others=>(others=>'0'));
    
    signal sp_out, ep_out: std_logic_vector(4 downto 0):=(others=>'0');
    signal sp_inp, ep_inp: std_logic_vector(4 downto 0):=(others=>'0');

    signal En: std_logic_vector(63 downto 0);
    signal destZ:  datatype_6:=(others=>(others=>'0'));
    signal inst: datatype_16:=(others=>(others=>'0'));
    signal regA: datatype_16:=(others=>(others=>'0'));
    signal valid_A: std_logic_vector(31 downto 0);
    signal regB: datatype_16:=(others=>(others=>'0'));
    signal valid_B: std_logic_vector(31 downto 0);
    signal immediate: datatype_16:=(others=>(others=>'0'));
    signal ep_next: std_logic_vector(4 downto 0):=(others=>'0');
    signal sp_next: std_logic_vector(4 downto 0);
begin
  
  --Make 32 entry long LoadQueue
	
    startpointerff : ff_5 port map (D1 => sp_inp, En=> '1',clock => clk, reset=> reset, Q=> sp_out);
  
    endpointerff   : ff_5 port map (D1 => ep_inp, En=> '1',clock => clk, reset=> reset, Q=> ep_out); 
  
    reset_process:process(reset)
    begin
        if(reset='1') then
            busy_bit <= (others=>'0');
        end if;
    end process;


    LQ_loader_datapath: process(clk)
    
    begin
        if (from_decoder1(88) = '1' and from_decoder1(65 downto 62) = "0100") then
            
            --inst_valid-destC[6]-pc1-inst-op1-valid1-op2-valid2-dest
            --(1+6+16+16+16+1+16+1+16) = 89 bits
            
            busy_bit(to_integer(unsigned(ep_out)) ) <= '1'; 
            destZ (to_integer(unsigned(ep_out)) ) <= from_decoder1(87 downto 82);
            pc     (to_integer(unsigned(ep_out)) ) <= from_decoder1(81 downto 66);
            inst   (to_integer(unsigned(ep_out)) ) <= from_decoder1(65 downto 50);
            regA   (to_integer(unsigned(ep_out)) ) <= from_decoder1(49 downto 34);
            valid_A(to_integer(unsigned(ep_out)) ) <= from_decoder1(33);
            regB   (to_integer(unsigned(ep_out)) ) <= from_decoder1(32 downto 17);
            valid_B(to_integer(unsigned(ep_out)) ) <= from_decoder1(16);
            immediate(to_integer(unsigned(ep_out)) ) <= from_decoder1(15 downto 0);
            
            --ep_load_queue(to_integer(unsigned(ep_out)) ) <= add (load_queue_ep_out, "00000"); 
            
            ep_next<= add(ep_out, "00001",'0');
            
         
         else 
            ep_next<= ep_out;
         
         end if ;
	
	 if (from_decoder2(88) = '1' and from_decoder2(65 downto 62) = "0100") then
            
            --inst_valid-destC[6]-pc1-inst-op1-valid1-op2-valid2-dest
            --(1+6+16+16+16+1+16+1+16) = 89 bits
            
            busy_bit(to_integer(unsigned(ep_next)) ) <= '1'; 
            destZ (to_integer(unsigned(ep_next)) ) <= from_decoder2(87 downto 82);
            pc      (to_integer(unsigned(ep_next)) ) <= from_decoder2(81 downto 66);
            inst    (to_integer(unsigned(ep_next)) ) <= from_decoder2(65 downto 50);
            regA    (to_integer(unsigned(ep_next)) ) <= from_decoder2(49 downto 34);
            valid_A (to_integer(unsigned(ep_next)) ) <= from_decoder2(33);
            regB    (to_integer(unsigned(ep_next)) ) <= from_decoder2(32 downto 17);
            valid_B (to_integer(unsigned(ep_next)) ) <= from_decoder2(16);
            immediate(to_integer(unsigned(ep_next)) ) <= from_decoder2(15 downto 0);
            
            --ep_load_queue(to_integer(unsigned(ep_out)) ) <= add (load_queue_ep_out, "00000"); 
            
            ep_inp<= add (ep_next, "00001",'0');
            
         
         else 
            ep_inp <= ep_next;
         
         end if ;
         
         
	 
    end process;

    -- just calculating the ready bit for the instruction based on valid bits of operands.
    
    ready_bit_calculator: process(clk)
    begin
        if (reset='1') then
            ready_bit<= (others => '0');
        else
            for i in 0 to 31 loop
                    if (busy_bit(i) = '1') then               
		            ready_bit(i) <= valid_A(i); 
		            address (i) <= add16 (regA(i), regB(i), '0');  
		    end if;           
            end loop;
        end if;
    end process ready_bit_calculator;


    rs_data_update: process (clk)
    --it needs to check the rrf in each cycle
    --refreshing rs data entries each cycle
    -- we take a 1024 bits wide signal from the rrf which gives all the data in it.
    -- then each entry of the rs takes the required segment of it.
    begin
        for i in 0 to 31 loop
        
            if (valid_A(i)='0' and busy_bit(i)='1' and validbits_fromrrf(to_integer(unsigned(regA(i)(5 downto 0))))='1') then
                	
                	regA(i) <= data_from_rrf(((to_integer(unsigned(regA(i)(5 downto 0)))+1)*16 -1) downto ((to_integer(unsigned(regA(i)(5 downto 0))))*16));
                	valid_A(i) <= '1';
            end if;
            
        end loop;
    end process;


    exit_process: process(clk)
    begin
    if(from_rob_exit_pc(33) ='1') then
         if (from_rob_exit_pc(32 downto 17) = pc(to_integer(unsigned(sp_out))) and execute(to_integer(unsigned(sp_out))) = '1') then 
        		busy_bit(to_integer(unsigned(sp_out))) <= '0';
        		sp_next <= add( sp_out, "00001",'0');
         else
         		sp_next <= sp_out;
         end if;
    else
         sp_next <= sp_out;
    end if;
        
    if(from_rob_exit_pc(16) ='1') then
         if (from_rob_exit_pc(15 downto 0) = pc(to_integer(unsigned(sp_next))) and execute(to_integer(unsigned(sp_next))) = '1') then 
        		busy_bit(to_integer(unsigned(sp_next))) <= '0';
        		sp_inp <= add( sp_next, "00001",'0');
         else
         		sp_inp <= sp_next;
         end if;
    else
         sp_inp <= sp_next;
    end if;
        
    end process;
    

    flush_process: process(clk, throw)
    	variable flush: std_logic_vector(16 downto 0);
    	variable flag: std_logic:='0';
        begin
        	flag :='0';
    		flush := (others=>'0');
    		for i in 0 to 31 loop
    			if(throw(i) = '1' and flag = '0') then
    				flush := "1" & pc(i);
    				flag = '1';
    			end if;
    		end loop;
        to_flush_to_rob<=flush;
    end process;
    
    scheduling_datapath: process(clk, load_choose)
    
    	--variable load_queue_throw1: std_logic_vector(31 downto 0);
        begin
    	
    	for i in 0 to 31 loop
	    	if(ready_bit(i) = '1' and busy_bit(i) = '1' and execute(i) = '0' and load_choose = '1') then
                to_store_pipeline(15 downto 0) <= address(i);      --mem_address (regA + regB)
                to_store_pipeline(31 downto 16) <= immediate(i);   --dest
                to_store_pipeline(47 downto 32) <= pc(i);  	   --pc
                to_store_pipeline(63 downto 48) <= inst(i);        --inst
                to_store_pipeline(68 downto 63) <= destZ(i);  	   --destZ
                to_store_pipeline(69) <= '1';  			   --valid
                execute(i) <= '1';
            else
                to_store_pipeline <= (others=>'0');
		    end if;
		end loop;
   end process;
   
    broadcast_process: process(address,pc,busy_bit,ep_out)
    begin
        for i in 0 to 31 loop
            load_queue_address((i+1)*16-1 downto 16*i) <= address(i);
            load_queue_pc((i+1)*16-1 downto 16*i) <= pc(i);
            load_queue_busy <= busy_bit;
            load_queue_ep_out <= ep_out;
        end loop;
    end process;
   
end bhv;
