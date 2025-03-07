library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

entity integer_pipeline is 
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
    valid_to_Zrrf: out std_logic;
    
    exe_PC: out std_logic_vector(15 downto 0);
    exe_valid: out std_logic
    );

end integer_pipeline;

architecture integer_pipeline_arch of integer_pipeline is
function add(A: in std_logic_vector(15 downto 0);
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
        end add;



signal opcode: std_logic_vector(3 downto 0);
signal complement: std_logic;
signal cflag: std_logic;
signal zflag: std_logic;
signal c: std_logic;
signal z: std_logic;
signal valid: std_logic; -- whether the entire thing in the input is valid or garbage
signal operand_1: std_logic_vector(15 downto 0);
signal operand_2: std_logic_vector(15 downto 0);
signal immediate: std_logic_vector(15 downto 0);
signal pc: std_logic_vector(15 downto 0);
signal destC: std_logic_vector(6 downto 0);
signal destZ: std_logic_vector(6 downto 0);

begin
    distribute: process(from_rs)
    begin
        destC<=from_rs(95 downto 90); -- we take all six bits as it will contain the destination rrf address of c and z.
        destZ<=from_rs(89 downto 84);
        pc<=from_rs(83 downto 68);
        opcode <= from_rs(67 downto 64);
        complement <= from_rs(63);
        cflag <= from_rs(62);
        zflag <= from_rs(61);
        z <= from_rs(55);--we only take single bit because instruction 
            -- comes to rs only after getting valus of source c and z which are single bit
        c <= from_rs(49);
        valid <= from_rs(48);
        operand_1 <= from_rs(47 downto 32);
        operand_2 <= from_rs(31 downto 16);
        immediate <= from_rs(15 downto 0);
    end process;

    
    evaluation: process
    begin
        if (valid = '1') then
            exe_valid <= '1';
            to_Crrf(6 downto 1) <= destC;
            to_Zrrf(6 downto 1) <= destZ;
            if (opcode = "0001") then
                to_rrf(21 downto 16) <= immediate(5 downto 0);
                if (cflag = '1' and zflag ='1') then
                --ACW,AWC
                    valid_to_rrf <= '1';
                    valid_to_Crrf <= '1';
                    valid_to_Zrrf <= '1';
                    if(complement = '1') then
                        to_rrf(15 downto 0) <= add(operand_1,not(operand_2),c)(15 downto 0);
                        to_Crrf(0) <= add(operand_1,not(operand_2),c)(16);
                        if(unsigned(add(operand_1,not(operand_2),c)(15 downto 0))=x"0000") then
                            to_Zrrf(0) <= '1';
                        else
                            to_Zrrf(0) <= '0';
                        end if;
                    else  
                        to_rrf(15 downto 0) <= add(operand_1,operand_2,c)(15 downto 0);
                        to_Crrf(0) <= add(operand_1,operand_2,c)(16);
                        if(unsigned(add(operand_1,operand_2,c)(15 downto 0))=x"0000") then
                            to_Zrrf(0) <= '1';
                        else
                            to_Zrrf(0) <= '0';
                        end if;
                    end if;

                elsif (cflag = '0' and zflag ='0') then
                --ACA,ADA
                    valid_to_rrf <= '1';
                    valid_to_Crrf <= '1';
                    valid_to_Zrrf <= '1';
                    if(complement = '1') then
                        to_rrf(15 downto 0) <= add(operand_1,not(operand_2),'0')(15 downto 0);
                        to_Crrf(0) <= add(operand_1,not(operand_2),'0')(16);
                        if(unsigned(add(operand_1,not(operand_2),'0')(15 downto 0))=x"0000") then
                            to_Zrrf(0) <= '1';
                        else
                            to_Zrrf(0) <= '0';
                        end if;
                    else 
                        to_rrf(15 downto 0) <= add(operand_1,operand_2,'0')(15 downto 0);
                        to_Crrf(0) <= add(operand_1,operand_2,'0')(16);
                        if(unsigned(add(operand_1,operand_2,'0')(15 downto 0))=x"0000") then
                            to_Zrrf(0) <= '1';
                        else
                            to_Zrrf(0) <= '0';
                        end if;
                    end if;

                elsif (cflag = '1' and zflag ='0') then
                --ACC,ADC
                    if(c='1') then
                        valid_to_rrf <= '1';
                        valid_to_Crrf <= '1';
                        valid_to_Zrrf <= '1';
                        if(complement = '1') then
                            to_rrf(15 downto 0) <= add(operand_1,not(operand_2),'0')(15 downto 0);
                            to_Crrf(0) <= add(operand_1,not(operand_2),'0')(16);
                            if(unsigned(add(operand_1,not(operand_2),'0')(15 downto 0))=x"0000") then
                                to_Zrrf(0) <= '1';
                            else
                                to_Zrrf(0) <= '0';
                            end if;
                        else 
                            to_rrf(15 downto 0) <= add(operand_1,operand_2,'0')(15 downto 0);
                            to_Crrf(0) <= add(operand_1,operand_2,'0')(16);
                            if(unsigned(add(operand_1,operand_2,'0')(15 downto 0))=x"0000") then
                                to_Zrrf(0) <= '1';
                            else
                                to_Zrrf(0) <= '0';
                            end if;
                        end if;
                    else
                        valid_to_rrf<='0';
                    end if;

                elsif (cflag = '0' and zflag ='1') then
                --ACZ,ADZ
                    if(z='1') then
                        valid_to_rrf <= '1';
                        valid_to_Crrf <= '1';
                        valid_to_Zrrf <= '1';
                        if(complement = '1') then
                            to_rrf(15 downto 0) <= add(operand_1,not(operand_2),'0')(15 downto 0);
                            to_Crrf(0) <= add(operand_1,not(operand_2),'0')(16);
                            if(unsigned(add(operand_1,not(operand_2),'0')(15 downto 0))=x"0000") then
                                to_Zrrf(0) <= '1';
                            else
                                to_Zrrf(0) <= '0';
                            end if;
                        else 
                            to_rrf(15 downto 0) <= add(operand_1,operand_2,'0')(15 downto 0);
                            to_Crrf(0) <= add(operand_1,operand_2,'0')(16);
                            if(unsigned(add(operand_1,operand_2,'0')(15 downto 0))=x"0000") then
                                to_Zrrf(0) <= '1';
                            else
                                to_Zrrf(0) <= '0';
                            end if;
                        end if;
                    else
                        valid_to_rrf<='0';
                    end if;
                end if;

            elsif (opcode="0000") then
            --ADI
                to_rrf(21 downto 16) <= immediate(5 downto 0);
                valid_to_rrf <= '1';
                valid_to_Crrf <= '1';
                valid_to_Zrrf <= '1';
                to_rrf(15 downto 0) <= add(operand_1,operand_2,'0')(15 downto 0);
                to_Crrf(0) <= add(operand_1,operand_2,'0')(16);
                if(unsigned(add(operand_1,operand_2,'0')(15 downto 0))=x"0000") then
                    to_Zrrf(0) <= '1';
                else
                    to_Zrrf(0) <= '0';
                end if;

            elsif (opcode = "0010") then
                to_rrf(21 downto 16) <= immediate(5 downto 0);
                if (cflag = '0' and zflag ='0') then
                --NCU,NDU
                    valid_to_rrf <= '1';
                    valid_to_Crrf <= '0';
                    valid_to_Zrrf <= '1';
                    if(complement = '1') then
                        to_rrf(15 downto 0) <= operand_1 nand not(operand_2);
                        if((operand_1 nand not(operand_2))=x"0000") then
                            to_Zrrf(0) <= '1';
                        else
                            to_Zrrf(0) <= '0';
                        end if;
                    else 
                        to_rrf(15 downto 0) <= operand_1 nand operand_2;
                        if((operand_1 nand operand_2)=x"0000") then
                            to_Zrrf(0) <= '1';
                        else
                            to_Zrrf(0) <= '0';
                        end if;
                    end if;

                elsif (cflag = '1' and zflag ='0') then
                --NCC,NDC
                    if(c='1') then
                        valid_to_rrf <= '1';
                        valid_to_Crrf <= '0';
                        valid_to_Zrrf <= '1';
                        if(complement = '1') then
                            to_rrf(15 downto 0) <= operand_1 nand not(operand_2);
                            if((operand_1 nand not(operand_2))=x"0000") then
                                to_Zrrf(0) <= '1';
                            else
                                to_Zrrf(0) <= '0';
                            end if;
                        else 
                            to_rrf(15 downto 0) <= operand_1 nand operand_2;
                            if((operand_1 nand operand_2)=x"0000") then
                                to_Zrrf(0) <= '1';
                            else
                                to_Zrrf(0) <= '0';
                            end if;
                        end if;
                    else
                        valid_to_rrf<='0';
                    end if;

                elsif (cflag = '0' and zflag ='1') then
                --NCZ,NDZ
                    if(z='1') then
                        valid_to_rrf <= '1';
                        valid_to_Crrf <= '0';
                        valid_to_Zrrf <= '1';
                        if(complement = '1') then
                            to_rrf(15 downto 0) <= operand_1 nand not(operand_2);
                            if((operand_1 nand not(operand_2))=x"0000") then
                                to_Zrrf(0) <= '1';
                            else
                                to_Zrrf(0) <= '0';
                            end if;
                        else 
                            to_rrf(15 downto 0) <= operand_1 nand operand_2;
                            if((operand_1 nand operand_2)=x"0000") then
                                to_Zrrf(0) <= '1';
                            else
                                to_Zrrf(0) <= '0';
                            end if;
                        end if;
                    else
                        valid_to_rrf<='0';
                    end if;
                end if;
            
            elsif(opcode="0011") then
                --LLI
                to_rrf(21 downto 16) <= immediate(5 downto 0);
                to_rrf(15 downto 0) <= operand_1;
                valid_to_rrf <= '1';
                valid_to_Crrf <= '0';
                valid_to_Zrrf <= '0';
                -- check the doc #6, for LLI we store the immediate in operand1

            -- For Conditional branches we send to rrf the value depicting take/no-take.
            elsif(opcode="1000") then
            --BEQ
            to_rrf(21 downto 16) <= immediate(5 downto 0);
            valid_to_rrf <= '1';
            valid_to_Crrf <= '0';
            valid_to_Zrrf <= '0';
                if (operand_1 = operand_2) then
                    to_rrf(15 downto 0) <= x"0001";
                else 
                    to_rrf(15 downto 0) <= x"0000";
                end if;
            
            elsif (opcode="1001") then
            --BLT
            to_rrf(21 downto 16) <= immediate(5 downto 0);
            valid_to_rrf <= '1';
            valid_to_Crrf <= '0';
            valid_to_Zrrf <= '0';
                -- RA<RB, then we jump
                if (to_integer(unsigned(operand_1)) < to_integer(unsigned(operand_1))) then
                    to_rrf(15 downto 0) <= x"0001";
                else 
                    to_rrf(15 downto 0) <= x"0000";
                end if;


            elsif(opcode="1010") then
            --BLE
            to_rrf(21 downto 16) <= immediate(5 downto 0);
            valid_to_rrf <= '1';
            valid_to_Crrf <= '0';
            valid_to_Zrrf <= '0';
                -- RA<=RB, then we jump
                if (to_integer(unsigned(operand_1)) <= to_integer(unsigned(operand_1))) then
                    to_rrf(15 downto 0) <= x"0001";
                else 
                    to_rrf(15 downto 0) <= x"0000";
                end if;

            -- for unconditional branches we will send the to_rrf(15 downto 0) to be stored in the register.
            elsif(opcode="1100") then
            --JAL
            to_rrf(21 downto 16) <= immediate(5 downto 0);
            valid_to_rrf <= '1';
            valid_to_Crrf <= '0';
            valid_to_Zrrf <= '0';
                --writing pc+2
                to_rrf(15 downto 0) <= std_logic_vector(unsigned(to_integer(pc)+2));
                valid_to_rrf <= '1';

            elsif(opcode="1101") then
            --JLR
            to_rrf(21 downto 16) <= immediate(5 downto 0);
            valid_to_rrf <= '1';
            valid_to_Crrf <= '0';
            valid_to_Zrrf <= '0';
                --writing pc+2 
                to_rrf(15 downto 0) <= std_logic_vector(unsigned(to_integer(pc)+2));
                valid_to_rrf <= '1';

            elsif(opcode="1111") then
            --JRI
                --##
                valid_to_rrf<='0';
                valid_to_Crrf <= '0';
                valid_to_Zrrf <= '0';
                --as we won't be writing anything

            else
                valid_to_rrf <= '0';
                valid_to_Crrf <= '0';
                valid_to_Zrrf <= '0';

            end if;
        else
            valid_to_rrf <= '0';
            valid_to_Crrf <= '0';
            valid_to_Zrrf <= '0';
            
            exe_valid <= '0';
        end if;
        
    end process;
    
    exe_PC <= pc;
     
end architecture;
