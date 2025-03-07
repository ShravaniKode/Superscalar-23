library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

entity datapath is
port(
    clk: in std_logic;
	 reset: in std_logic
);
end datapath;

architecture bhv of datapath is

------defining the components-------------

component decode_stage is 

		port(En,clock,reset:in std_logic; pc_inp : in std_logic_vector(15 downto 0); 
		
		busybits_from_arf: in std_logic_vector(7 downto 0);
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
		busybits_from_rrfcarry: in std_logic_vector(63 downto 0);
		busybits_from_rrfzero : in std_logic_vector(63 downto 0);
		
		busybits_to_rrf: out std_logic_vector(63 downto 0);
		
		FLUSH: in std_logic;
		branch_flag: in std_logic:
		
		busyout, write_out: out std_logic_vector(1 downto 0); 
		
		spec_out, tag_out: out std_logic_vector(1 downto 0); 
		branch_bit, valid_out: out std_logic_vector(1 downto 0); 
		taken_or_not : out std_logic_vector(1 downto 0);

		tags_to_arf : out std_logic_vector(11 downto 0);
		address_to_arf_tag : out std_logic_vector(5 downto 0);
		valid_to_arf_tag : out std_logic_vector(1 downto 0)
		);

 
end component decode_stage;


component ROB is
	generic(
        	size : integer := 64
    	);
    	
	port( En, clock, reset:in std_logic_vector(63 downto 0); busyinp, write_inp: in std_logic_vector(1 downto 0); 
	
	spec_inp, tag_inp: in std_logic_vector(1 downto 0); branch_bit, valid_inp: in std_logic_vector(1 downto 0); 
	
	taken_or_not : in std_logic_vector(1 downto 0); exe_PC_valid, iss_PC_valid : in std_logic_vector(2 downto 0); 
	
	exe_PC_inp, iss_PC_inp: std_logic_vector(47 downto 0); inst_inp, PCinp: in std_logic_vector(31 downto 0); 
	
	dest_inp: in std_logic_vector(2 downto 0); rrf_inp : in std_logic_vector(11 downto 0); rrf_values: in std_logic_vector(1023 downto 0); 
	
	arf_tag: in std_logic_vector(47 downto 0); sp_opt, ep_opt: out std_logic_vector(5 downto 0);  
	
	branch_flag1: out std_logic;  flush_PC: out std_logic_vector(16 downto 0); flush_rs: out std_logic; 
	
	value_arf: out std_logic_vector(31 downto 0); address_arf: out std_logic_vector(5 downto 0); 
	
	arf_busy: out std_logic_vector(1 downto 0); valid_arf : out std_logic_vector(1 downto 0));
	
end component ROB;


component res_station is
    generic(
        size : integer := 32
        -- this defines the size of the reservation station
        -- the double priority encoder also depends on this value
    );

    port(
        clk: in std_logic;
        reset: in std_logic;
        from_decoder1: in std_logic_vector(86 downto 0);
        from_decoder2: in std_logic_vector(86 downto 0);
        --pc1-control[7]-op1-valid1-op2-valid2-imm-c-validc-z-validz
        --(16+7+16+1+16+1+16+6+1+6+1) = 87 bits

        data_from_rrf: in std_logic_vector(1023 downto 0);-- rrf has 64 entries of length 16 bits.
        validbits_fromrrf: in std_logic_vector(63 downto 0);-- valid bits for each of the 64 entries

        data_from_Crrf: in std_logic_vector(63 downto 0);
        validbits_fromCrrf: in std_logic_vector(63 downto 0);

        data_from_Zrrf: in std_logic_vector(63 downto 0);
        validbits_fromZrrf: in std_logic_vector(63 downto 0);

        to_store_pipeline: out std_logic_vector(55 downto 0);
        --control[7]-valid-op1-op2-imm
        to_int1_pipeline: out std_logic_vector(83 downto 0);
        --pc-control-z-c-valid-op1-op2-imm
        to_int2_pipeline: out std_logic_vector(83 downto 0)
        --pc-control-z-c-valid-op1-op2-imm

    );
end res_station;

component RRF is 
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

        from_decoder: in std_logic_vector(20 downto 0);
        -- 3 six bit rrf addresses -- 3 single bit corresponding valid bit

        data_output: out std_logic_vector(len*breadth-1 downto 0); -- spitting the entire rrf content to the outside world
        valid_out: out std_logic_vector(len-1 downto 0)
    );
end component;

component PriorityEncoderActiveHigh is
    generic (
        input_width : integer := 2 ** 8;
        output_width : integer := 8 
    );
    port (
        a: in std_logic_vector(input_width - 1 downto 0);
        y: out std_logic_vector(output_width - 1 downto 0);
        all_zeros: out std_logic
    );
end component;

component oneshift is

port (inp :in std_logic_vector(15 downto 0); OneS: in std_logic;
output: out std_logic_vector(15 downto 0));

end component;

component DoubleEncoder is
    generic (
        number_of_inputs : integer := 2 ** 8;
        number_of_outputs : integer := 8
    );
    port (
        a: in std_logic_vector(number_of_inputs - 1 downto 0);
        y_first: out std_logic_vector(number_of_outputs - 1 downto 0);
        valid_first: out std_logic;
        y_second: out std_logic_vector(number_of_outputs - 1 downto 0);
        valid_second: out std_logic
    );
end component DoubleEncoder;

component lspipeline is 
		port(En,clock,reset:in std_logic; opr1,opr2, PC_inp : in std_logic_vector (15 downto 0); dest_rrf :in std_logic_vector (15 downto 0); control : in std_logic_vector (5 downto 0); rrf_values: in std_logic_vector (1023 downto 0); exebit, rrf_valid : out std_logic ; exePC , rrf_data : out std_logic_vector (15 downto 0); rrf_add : out std_logic_vector (5 downto 0)); 
end component lspipeline;

component Memory_data is
    port(clock, mem_rd, mem_wr: in std_logic; mem_add,mem_data: in std_logic_vector(15 downto 0);  mem_out: out std_logic_vector(15 downto 0) );
end component;


component Memory_inst is
    port(clock, mem_rd, mem_wr: in std_logic; mem_add,mem_data: in std_logic_vector(15 downto 0);  mem_out: out std_logic_vector(15 downto 0) );
end component;


component integer_pipeline is 
    port(
    clk: in std_logic;
    from_rs: in std_logic_vector(95 downto 0);
    --destC[6]-destZ[6]-pc[16]-control[7]-z[6]-c[6]-valid[1]-op1[16]-op2[16]-imm[16]

    to_rrf: out std_logic_vector(21 downto 0);
    -- address in rrf[6] --data[16]
    valid_to_rrf: out std_logic;

    to_Crrf: out std_logic_vector(6 downto 0);
    -- address in Crrf[6] -- data[1]
    valid_to_Crrf: out std_logic;

    to_Zrrf: out std_logic_vector(6 downto 0);
    valid_to_Zrrf: out std_logic
    );

end component integer_pipeline;

component ARF is 
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

    );
end component;


----defining the signals-------------------------------------------------------------------------------------------------------------------------
signal flush_rs_sig: std_logic;     ----output of the ROB
signal rrf_rs_data: std_logic_vector(1023 downto 0);
signal rrf_rs_valid : std_logic_vector(63 downto 0);
signal rrfc_rs_data: std_logic_vector(63 downto 0);
signal rrfc_rs_valid : std_logic_vector(0 downto 0);
signal rrfz_rs_data: std_logic_vector(63 downto 0);
signal rrfz_rs_valid : std_logic_vector(0 downto 0);
signal rs_to_intpipe1: std_logic_vector(83 downto 0);
signal rs_to_intpipe2: std_logic_vector(83 downto 0);
signal intpipe1_to_rrf_data: std_logic_vector(21 downto 0);
signal intpipe1_rrf_valid: std_logic;
signal intpipe2_to_rrf_data: std_logic_vector(21 downto 0);
signal intpipe2_rrf_valid: std_logic;

--------------datapath-------------------------------------------------------------------------------------------------------
	rrf: RRF  generic map( len: integer:=64; breadth: integer:=16) port map(
	     clk => clk,
        reset => reset,

        from_int1_pipe => intpipe1_to_rrf_data,
        -- as the pipe will always have a 6 bit address but might have 16 bit data or 1 bit data.
        valid_int1_pipe => intpipe1_to_rrf_valid,

        from_int2_pipe => intpipe2_to_rrf_data,
        valid_int2_pipe => intpipe2_to_rrf_valid,

        from_decoder: in std_logic_vector(20 downto 0);
        -- 3 six bit rrf addresses -- 3 single bit corresponding valid bit

        data_output => rrf_rs_data, -- spitting the entire rrf content to the outside world
        valid_out: rrf_rs_valid);
-------------------------------------------------------------RRFC--------------------------------------		  
	rrfc: RRF  generic map( len: integer:=64; breadth: integer:=1) port map(
	     clk => clk,
        reset => reset,

        from_int1_pipe => intpipe1_to_rrfc_data,
        -- as the pipe will always have a 6 bit address but might have 16 bit data or 1 bit data.
        valid_int1_pipe => intpipe1_to_rrfc_valid,

        from_int2_pipe => intpipe2_to_rrfc_data,
        valid_int2_pipe => intpipe2_to_rrfc_valid,

        from_decoder: in std_logic_vector(20 downto 0);
        -- 3 six bit rrf addresses -- 3 single bit corresponding valid bit

        data_output => rrfc_rs_data-- spitting the entire rrf content to the outside world
        valid_out => rrfc_rs_valid);
---------------------------------------------------RRFZ----------------------------------
	rrfz: RRF  generic map( len: integer:=64; breadth: integer:=1) port map(
	     clk => clk,
        reset => reset,

        from_int1_pipe => intpipe1_to_rrfz_data,
        -- as the pipe will always have a 6 bit address but might have 16 bit data or 1 bit data.
        valid_int1_pipe => intpipe1_to_rrfz_valid,

        from_int2_pipe => intpipe2_to_rrfz_data,
        valid_int2_pipe => intpipe2_to_rrfz_valid,

        from_decoder: in std_logic_vector(20 downto 0);
        -- 3 six bit rrf addresses -- 3 single bit corresponding valid bit

        data_output => rrfz_rs_data, -- spitting the entire rrf content to the outside world
        valid_out: rrfz_rs_valid);
		  
		  
   intpipe1: integer_pipeline
				 port map(
				 clk => clk,
				 from_rs => rs_to_intpipe1,
				 --pc[16]-control[7]-z[6]-c[6]-valid[1]-op1[16]-op2[16]-imm[16]

				 to_rrf => intpipe1_to_rrf_data,
				 -- address in rrf[6] --data[16]
				 valid_to_rrf => intpipe1_to_rrf_valid,
                                 to_Crrf => intpipe1_to_rrfc_data,
                                 valid_to_Crrf => intpipe1_to_rrfc_valid,
                                 to_Zrrf => intpipe1_to_rrfz_data,
                                 valid_to_Zrrf => intpipe1_to_rrfz_valid

 
                                  
				 );
				 
	intpipe2: integer_pipeline
				 port map(
				 clk => clk,
				 from_rs => rs_to_intpipe2,
				 --pc[16]-control[7]-z[6]-c[6]-valid[1]-op1[16]-op2[16]-imm[16]

				 to_rrf: intpipe2_to_rrf_data,
				 -- address in rrf[6] --data[16]
				 valid_to_rrf: intpipe2_to_rrf_valid,
                                 to_Crrf => intpipe2_to_rrfc_data,
                                 valid_to_Crrf => intpipe2_to_rrfc_valid,
                                 to_Zrrf => intpipe2_to_rrfz_data,
                                 valid_to_Zrrf => intpipe2_to_rrfz_valid
				 );

      
     arf: ARF  port map(
        clk => clk,
        reset => reset,

        from_rob_data => in std_logic_vector(31 downto 0);
        from_rob_valid: in std_logic_vector(1 downto 0);
        from_rob_busy: in std_logic_vector(1 downto 0);
        from_rob_add: in std_logic_vector(5 downto 0);




        --Value[16] + busy[1] + address[3]

        from_decoder_add: in std_logic_vector(5 downto 0);
        from_decoder_valid: in std_logic_vector(1 downto 0);
        from_decoder_tag: in std_logic_vector(11 downto 0);

        --Tag[6] + busy[1]

    );
						  
   
		  
	
	
	rs: res_station port map(clk => clk,
		                 reset => reset or flush_rs_sig,
                                 from_decoder1: in std_logic_vector(86 downto 0),
			         from_decoder2: in std_logic_vector(86 downto 0),
				  --pc1-control[7]-op1-valid1-op2-valid2-imm-c-validc-z-validz
				  --(16+7+16+1+16+1+16+6+1+6+1) = 87 bits

				data_from_rrf => rrf_rs_data, -- rrf has 64 entries of length 16 bits.
			        validbits_fromrrf => rrf_rs_valid,-- valid bits for each of the 64 entries

				 data_from_Crrf => rrfc_rs_data,
				 validbits_fromCrrf => rrfc_rs_valid,

				 data_from_Zrrf => rrfz_rs_data,
				 validbits_fromZrrf => rrfz_rs_valid,

				 to_store_pipeline => out std_logic_vector(55 downto 0),
			         --control[7]-valid-op1-op2-imm
			         to_int1_pipeline => rs_to_intpipe1,
			         --pc-control-z-c-valid-op1-op2-imm
		                 to_int2_pipeline => rs_to_intpipe2,
			         --pc-control-z-c-valid-op1-op2-imm))
								  								  
								  
	decoder: decode_stage port map (clock => clk,
	   reset => reset, 
		
		busybits_from_arf: in std_logic_vector(7 downto 0);
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
		busybits_from_rrfcarry: in std_logic_vector(63 downto 0);
		busybits_from_rrfzero : in std_logic_vector(63 downto 0);
		
		busybits_to_rrf: out std_logic_vector(63 downto 0);
		
		FLUSH: in std_logic;
		branch_flag: in std_logic:
		
		busyout, write_out: out std_logic_vector(1 downto 0); 
		
		spec_out, tag_out: out std_logic_vector(1 downto 0); 
		branch_bit, valid_out: out std_logic_vector(1 downto 0); 
		taken_or_not : out std_logic_vector(1 downto 0);

		tags_to_arf : out std_logic_vector(11 downto 0);
		address_to_arf_tag : out std_logic_vector(5 downto 0);
		valid_to_arf_tag : out std_logic_vector(1 downto 0)
		);

 rob: ROB 
	generic map(
        	size : integer := 64
    	);
    	
	port map( En, 
                  clock => clk,
                  reset => reset, 
                  busyinp, write_inp: in std_logic_vector(1 downto 0); 
	
	spec_inp, tag_inp: in std_logic_vector(1 downto 0); branch_bit, valid_inp: in std_logic_vector(1 downto 0); 
	
	taken_or_not : in std_logic_vector(1 downto 0); exe_PC_valid, iss_PC_valid : in std_logic_vector(2 downto 0); 
	
	exe_PC_inp, iss_PC_inp: std_logic_vector(47 downto 0); inst_inp, PCinp: in std_logic_vector(31 downto 0); 
	
	dest_inp: in std_logic_vector(2 downto 0); rrf_inp : in std_logic_vector(11 downto 0); rrf_values: in std_logic_vector(1023 downto 0); 
	
	arf_tag: in std_logic_vector(47 downto 0); sp_opt, ep_opt: out std_logic_vector(5 downto 0);  
	
	branch_flag1: out std_logic;  flush_PC: out std_logic_vector(16 downto 0); flush_rs: out std_logic; 
	
	value_arf: out std_logic_vector(31 downto 0); address_arf: out std_logic_vector(5 downto 0); 
	
	arf_busy: out std_logic_vector(1 downto 0); valid_arf : out std_logic_vector(1 downto 0));






