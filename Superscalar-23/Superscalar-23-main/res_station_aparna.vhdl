library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

entity res_station is
    generic(
        size : integer := 32
        -- this defines the size of the reservation station
        -- the double priority encoder also depends on this value
    );

    port(
        clk: in std_logic;
        reset: in std_logic;
        from_decoder1: in std_logic_vector(99 downto 0);
        from_decoder2: in std_logic_vector(99 downto 0);
        --valid-destC[6]-destZ[6]-pc1-control[7]-op1-valid1-op2-valid2-imm-c-validc-z-validz
        --(1+6+6+16+7+16+1+16+1+16+6+1+6+1) = 100 bits
        --#6 Major mess fixed

        data_from_rrf: in std_logic_vector(1023 downto 0);-- rrf has 64 entries of length 16 bits.
        validbits_fromrrf: in std_logic_vector(63 downto 0);-- valid bits for each of the 64 entries

        data_from_Crrf: in std_logic_vector(63 downto 0);
        validbits_fromCrrf: in std_logic_vector(63 downto 0);

        data_from_Zrrf: in std_logic_vector(63 downto 0);
        validbits_fromZrrf: in std_logic_vector(63 downto 0);

        --to_store_pipeline: out std_logic_vector(55 downto 0);
        --control[7]-valid-op1-op2-imm
        to_int1_pipeline: out std_logic_vector(95 downto 0);
        --destC-destZ-pc-control-z-c-valid-op1-op2-imm
        to_int2_pipeline: out std_logic_vector(95 downto 0)
        --destC[6]-destZ[6]-pc[16]-control[7]-z[6]-c[6]-valid[1]-op1[16]-op2[16]-imm[16]

    );
end res_station;

architecture rs_arch of res_station is 
    -- defining datatypes for the columns
    -- each is a table of with number of rows equal to the size
    type datatype_4 is array(size-1 downto 0) of std_logic_vector(3 downto 0);
    type datatype_6 is array(size-1 downto 0) of std_logic_vector(5 downto 0);
    type datatype_7 is array(size-1 downto 0) of std_logic_vector(6 downto 0);
    type datatype_8 is array(size-1 downto 0) of std_logic_vector(7 downto 0);
    type datatype_9 is array(size-1 downto 0) of std_logic_vector(8 downto 0);
    type datatype_16 is array(size-1 downto 0) of std_logic_vector(15 downto 0);


    -- we start defining the columns as signals
    -- busy bit signifies which rows of the rs have valid instructions in them.
    -- as soon as instruction is issued, busy bit goes to 0.
    signal busy_bit: std_logic_vector(size-1 downto 0):=(others=>'0');

    --consisting of the opcode and complement,c,z conditions
    signal control: datatype_7:=(others=>(others=>'0'));

    signal destC:datatype_6:=(others=>(others=>'0'));
    signal destZ:datatype_6:=(others=>(others=>'0'));
    
    --program counter,operands and valid bits of the operand for the instructions
    signal pc: datatype_16:=(others=>(others=>'0'));
    -- need to be 16 bits as data can be 2 bytes ? (regardless keeping life simple)
    signal operand_1: datatype_16:=(others=>(others=>'0'));
    signal operand_2: datatype_16:=(others=>(others=>'0'));
    -- these are single bit wide columns of length size
    signal valid_1: std_logic_vector(size-1 downto 0):=(others=>'0');
    signal valid_2: std_logic_vector(size-1 downto 0):=(others=>'0');
    signal immediate: datatype_16:=(others=>(others=>'0'));

    -- the following will be the counterparts of rrf for storing c and z values. USED AS OPERANDS   
    signal c: datatype_6:=(others=>(others=>'0'));
    signal z: datatype_6:=(others=>(others=>'0'));
    --The have been made of 6 bit as they can contain either the c,z value or the rrf address.

    -- they'll need valid bits as we are using RRFs for these too
    signal valid_c: std_logic_vector(size-1 downto 0):=(others=>'0');
    signal valid_z: std_logic_vector(size-1 downto 0):=(others=>'0');

    
    -- we need bit denoting whether the instruction is ready to be executed
    signal ready_bit: std_logic_vector(size-1 downto 0):=(others=>'0'); -- calculated using operand valid bits.
    -- prev_issues now redundant, putting busy bit instead #3
    -- signal prev_issued: std_logic_vector(size-1 downto 0):=(others=>'0');
    signal ldsd_mask: std_logic_vector(size-1 downto 0):=(others=>'0');
    
    signal and1, and2: std_logic_vector(size-1 downto 0):=(others=>'0');
    
    --------------------------------------------------------------------------------
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
    end component;
    
    -------------------------------------------------------------------
    --listing all internal communication signals below
    signal encoder1_out: std_logic_vector(11 downto 0);-- carries addresses for empty rs rows.
    --address1--valid1--address2--valid2
    signal encoder2_out: std_logic_vector(11 downto 0);
    --address1--valid1--address2--valid2
    signal encoder3_out: std_logic_vector(5 downto 0);-- carries address info for ld/st and one valid bit
    --valid[1]-address[5]

begin
    -- here we start writing processes for the actual fucntions performed by the rs

---------------------------------------------------------------------------------------------------------------
--###########################  RS  INPUT  #####################################################################
    
    
    reset_process:process(reset)
    begin
        if(reset='1') then
            busy_bit <= (others=>'0');
        end if;
    end process;


    -- just looks at the prev_issues bitstring to know which entries have already been issued
    -- and gives two un-issues entries accordingly.
    finding_empty_rs_entries: DoubleEncoder
    -- this isn't a process, it's hardware
        generic map(
            -- the whole point of the generic map is that we can use dbiffernt parameters 
            -- from the original entity definition while instantiating the component
            number_of_inputs => size,
            number_of_outputs => 5 -- hopefully this is log to base 2.-- yes this is
        )
        port map(
            -- input_string <= prev_issued, -- redundant prev_issued
            -- its task just to be done by busy bit now, as soon as an instruction is issued, its busy bit goes to 0.
            -- #3
            -- it will give two available rs slots based on the mask
            -- there might not be two or even one empty slots, so the address can be invalid.         
            a => busy_bit,
            y_first => encoder1_out(11 downto 7),
            valid_first => encoder1_out(6),
            y_second=> encoder1_out(5 downto 1),
            valid_second=> encoder1_out(0)
        );


    --rs_loader_datapath: process(clk,from_decoder1,from_decoder2)
    rs_loader_datapath: process(clk)
    --distribution of signal "from_decoder1"
    
    --destC[6]-valid[1]-destZ[6]-valid[1]-pc1-control[7]-op1-valid1-op2-valid2-imm-c-validc-z-validz
    --(6+1+6+1+16+7+16+1+16+1+16+6+1+6+1) = 101 bits
    --#6 Major mess fixed


    begin
        if (encoder1_out(6)='1') then
            --if address one is valid
		
	    busy_bit(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(99);
            destC(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(98 downto 93);
            destZ(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(92 downto 87);
            pc(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(86 downto 71);
            control(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(70 downto 64);
            operand_1(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(63 downto 48);
            valid_1(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(47);
            operand_2(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(46 downto 31);
            valid_2(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(30);
            immediate(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(29 downto 14);
            c(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(13 downto 8);
            valid_c(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(7);
            z(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(6 downto 1);
            valid_z(to_integer(unsigned(encoder1_out(11 downto 7)))) <= from_decoder1(0);
            
        else 
         busy_bit(to_integer(unsigned(encoder1_out(11 downto 7)))) <= '0';
        end if ;

        if (encoder1_out(0) = '1') then
            -- if address two is valid

	    busy_bit(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(99);
            destC(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(98 downto 93);
            destZ(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(92 downto 87);
            pc(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(86 downto 71);
            control(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(70 downto 64);
            operand_1(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(63 downto 48);
            valid_1(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(47);
            operand_2(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(46 downto 31);
            valid_2(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(30);
            immediate(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(29 downto 14);
            c(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(13 downto 8);
            valid_c(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(7);
            z(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(6 downto 1);
            valid_z(to_integer(unsigned(encoder1_out(5 downto 1)))) <= from_decoder2(0);
        else 
         busy_bit(to_integer(unsigned(encoder1_out(5 downto 1)))) <= '0';  
        end if;
    
    end process;

------------------------------------------------------------------------------------------------------------------
--###########################  RS  INTERNAL PROCESSES  ###########################################################


    -- just calculating the ready bit for the instruction based on valid bits of operands.
    -- will be different conditions for different instructions
    ready_bit_calculator: process(valid_1,valid_2,valid_c,valid_z,busy_bit)
    begin
        if (reset='1') then
            ready_bit<= (others => '0');
        else
            for i in 0 to size-1 loop
                if(control(i)(6 downto 3) = "0001" or control(i)(6 downto 3) = "0010") then
                    if (control(i)(1 downto 0) = "00") then
                        -- ADA, ACA, NDU, NCU
                        ready_bit(i) <= valid_1(i) AND valid_2(i);
                    elsif (control(i)(1 downto 0) = "10") then
                        -- ADC, ACC, NDC, NCC
                        ready_bit(i) <= valid_1(i) AND valid_2(i) AND valid_c(i);
                    elsif (control(i)(1 downto 0) = "01") then
                        -- ADZ, ACZ, NDZ, NCZ
                        ready_bit(i) <= valid_1(i) AND valid_2(i) AND valid_z(i);
                    else 
                        -- AWC, ACW -- they also need the carry bit
                        ready_bit(i) <= valid_1(i) AND valid_2(i) AND valid_c(i);
                    end if;
                
                elsif (control(i)(6 downto 3) = "0000" or control(i)(6 downto 3) = "0110" 
                            or control(i)(5 downto 2) = "0111" or control(i)(6 downto 3) = "0100") then
                    -- ADI, LM, SM, LW
                    -- just need first operand
                    ready_bit(i) <= valid_1(i);
                elsif (control(i)(6 downto 3) = "0101" or control(i)(6 downto 3) = "1000" 
                            or control(i)(5 downto 2) = "1001" or control(i)(5 downto 2) = "1010") then
                    -- SW, BEQ, BLT, BLE
                    -- needs both operands
                    ready_bit(i) <= valid_1(i) and valid_2(i);
                
                else 
                    -- some instructions have no requirements like    
                    -- LLI, JAL, JRI, JLR
                    -- hence they are always ready
                    ready_bit(i) <= '1';
                end if;
            end loop;
        end if;
    end process ready_bit_calculator;


    rs_data_update: process(validbits_fromrrf,validbits_fromCrrf,validbits_fromZrrf)
    --it needs to check the rrf in each cycle
    --refreshing rs data entries each cycle
    -- we take a 1024 bits wide signal from the rrf which gives all the data in it.
    -- then each entry of the rs takes the required segment of it.

    -- this also needs to be done for c and z entries. ONLY THE SOURCE Z,C NOT THE DESTINATION  
    begin
        for i in 0 to size-1 loop
            if (valid_1(i)='0' and busy_bit(i)='1' and validbits_fromrrf(to_integer(unsigned(operand_1(i)(5 downto 0))))='1') then
                operand_1(i) <= data_from_rrf(((to_integer(unsigned(operand_1(i)(5 downto 0)))+1)*16 -1) downto ((to_integer(unsigned(operand_1(i)(5 downto 0))))*16));
                valid_1(i)<='1';
            end if;

            if (valid_2(i)='0' and busy_bit(i)='1' and validbits_fromrrf(to_integer(unsigned(operand_2(i)(5 downto 0))))='1') then
                operand_2(i) <= data_from_rrf(((to_integer(unsigned(operand_2(i)(5 downto 0)))+1)*16 -1) downto ((to_integer(unsigned(operand_2(i)(5 downto 0))))*16));
                valid_2(i) <= '1';
            end if;

            
            if (valid_c(i)='0' and busy_bit(i)='1' and validbits_fromCrrf(to_integer(unsigned(c(i)(5 downto 0)))) = '1') then
                c(i)(0) <= data_from_Crrf(to_integer(unsigned(c(i)(5 downto 0)))); -- as after taking the valid data from rrf, it will only have one signigicant bit.
                c(i)(5 downto 1) <= "00000";-- others will always be zero
                valid_c(i) <= '1';
            end if;

            if (valid_z(i)='0' and busy_bit(i)='1' and validbits_fromZrrf(to_integer(unsigned(z(i)(5 downto 0)))) = '1') then
                z(i)(0) <= data_from_Zrrf(to_integer(unsigned(z(i)(5 downto 0))));
                z(i)(5 downto 1) <= "00000";
                valid_z(i) <= '1';
            end if;
        end loop;
    end process;

------------------------------------------------------------------------------------------------------
--###########################  RS  OUTPUT  ###########################################################
    -- decinding which pipeline to use and whether instruction is ready or not
    -- decision based on opcode/control bits, valid bits of operand (in the form of the ready bit)
    -- we are making two integer pipelines and one load store pipeline

    -- from all the ready instruc,
    -- -- first we find a loadstore instruc and send to pipeline
    -- -- then two instruc which are not ldsd and sent to int pipelines,

    ldsd_mask_creator: process(control)
    begin
    for i in 0 to size-1 loop
    if (control(i)(6 downto 3) = "0100" or control(i)(6 downto 3) = "0101") then
        ldsd_mask(i) <= '1';
    else
        ldsd_mask(i) <= '0';
    end if;
    end loop; 
    end process;

    and1 <= busy_bit and ready_bit and not(ldsd_mask);
    int_pipeline_scheduler: DoubleEncoder
        generic map(
            number_of_inputs => size,
            number_of_outputs => 5 
        )
        port map(
            a => and1,
            -- trying to get all ready non ld/st instructions
            y_first => encoder2_out(11 downto 7),
            valid_first => encoder2_out(6),
            -- these the rows corresponding to these addresses needs to be provided to the pipelines
            -- if the valid bit is 0 then we send a NOP in the respective pipelines.
            y_second => encoder2_out(5 downto 1),
            valid_second=> encoder2_out(0)
        );
	
    and2 <= busy_bit and ready_bit and (ldsd_mask);
    store_pipeline_scheduler: PriorityEncoderActiveHigh
        generic map(
            input_width => size,
            output_width => 5 
        )
        port map(
            a => and2,
            -- this mess is me trying to get the rows which are occupied, have a ld/store instruction and are ready to go.
            y => encoder3_out(5 downto 1),
            all_zeros => encoder3_out(0)            
        );
    
    scheduling_datapath: process(clk,immediate,operand_1,operand_2,control,encoder3_out,encoder2_out)
    --its task is to take the rows given by the store_pipeline_scheduler and int_pipeline_scheduler
    -- and send the data to output ports to the pipelines after concatenating.
    begin
    -- first writing for ld/store
        --taking data from the corresponding entry of each column data structure.
        --to_store_pipeline(15 downto 0) <= immediate(to_integer(unsigned(encoder3_out(5 downto 1))));
        --to_store_pipeline(31 downto 16) <= operand_2(to_integer(unsigned(encoder3_out(5 downto 1))));
        --to_store_pipeline(47 downto 32) <= operand_1(to_integer(unsigned(encoder3_out(5 downto 1))));
        --to_store_pipeline(48) <= encoder3_out(0); -- valid bit for the row address in question
        --to_store_pipeline(55 downto 49) <= control(to_integer(unsigned(encoder3_out(5 downto 1)))); -- for choosing between load and store.

    -- for int1
        -- there can be huge vareity in int instructions, so we send both operands and also the c,z flags and control bits.
        to_int1_pipeline(15 downto 0) <= immediate(to_integer(unsigned(encoder2_out(11 downto 7)))); --immediate
        to_int1_pipeline(31 downto 16) <= operand_2(to_integer(unsigned(encoder2_out(11 downto 7)))); --operand_2
        to_int1_pipeline(47 downto 32) <= operand_1(to_integer(unsigned(encoder2_out(11 downto 7)))); --operand_1
        to_int1_pipeline(48) <= encoder2_out(6); --valid for the particular row address provided
        to_int1_pipeline(54 downto 49) <= c(to_integer(unsigned(encoder2_out(11 downto 7))));
        to_int1_pipeline(60 downto 55) <= z(to_integer(unsigned(encoder2_out(11 downto 7))));
        to_int1_pipeline(67 downto 61) <= control(to_integer(unsigned(encoder2_out(11 downto 7))));
        to_int1_pipeline(83 downto 68) <= pc(to_integer(unsigned(encoder2_out(11 downto 7))));
        to_int1_pipeline(89 downto 84) <= destZ(to_integer(unsigned(encoder2_out(11 downto 7))));
        to_int1_pipeline(95 downto 90) <= destC(to_integer(unsigned(encoder2_out(11 downto 7))));

        -- for int2
        to_int2_pipeline(15 downto 0) <= immediate(to_integer(unsigned(encoder2_out(5 downto 1)))); --immediate
        to_int2_pipeline(31 downto 16) <= operand_2(to_integer(unsigned(encoder2_out(5 downto 1)))); --operand_2
        to_int2_pipeline(47 downto 32) <= operand_1(to_integer(unsigned(encoder2_out(5 downto 1)))); --operand_1
        to_int2_pipeline(48) <= encoder2_out(0); --valid for the particular row address provided
        to_int2_pipeline(54 downto 49) <= c(to_integer(unsigned(encoder2_out(5 downto 1))));
        to_int2_pipeline(60 downto 55) <= z(to_integer(unsigned(encoder2_out(5 downto 1))));
        to_int2_pipeline(67 downto 61) <= control(to_integer(unsigned(encoder2_out(5 downto 1))));
        to_int2_pipeline(83 downto 68) <= pc(to_integer(unsigned(encoder2_out(5 downto 1))));
        to_int2_pipeline(89 downto 84) <= destZ(to_integer(unsigned(encoder2_out(5 downto 1))));
        to_int2_pipeline(95 downto 90) <= destZ(to_integer(unsigned(encoder2_out(5 downto 1))));

    end process;

end rs_arch;
