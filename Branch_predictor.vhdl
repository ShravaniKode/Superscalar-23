library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

entity branch_predictor is 
    port(
        clk:in std_logic;
        reset: in std_logic;
        result_in: in std_logic;
        valid_in: in std_logic;
        --whenever valid bit goes from low to high, we read the true result of the branch at top of rob
        prediction_out: out std_logic

    );
end entity branch_predictor;

architecture branch_predictor_arch of branch_predictor is
    type state is (s0,s1,s2,s3);
    signal p,n : state :=s0;

    begin

        state_next: process(reset,valid_in)
        begin
            if(reset='1') then
                p<=s0;
            else
                if (valid_in'event and valid_in='1') then
                    p<=n;
                end if;
            end if;
        end process;

        state_output: process(result_in)
        begin
            case p is 
                when s0 =>
                    prediction_out <= '0';
                when s1 =>
                    prediction_out <= '0';
                when s2 =>
                    prediction_out <= '1';
                when s3 =>
                    prediction_out <= '1';
            end case;
        end process;

        state_decision: process(valid_in,reset,clk,result_in)
        begin
            if(reset='1') then
                n<=s0;
            else
                if (valid_in'event and valid_in='1') then
                    case p is
                    when s0 =>
                        if(result_in='0') then
                            n<=s0;
                        else
                            n<=s1;
                        end if;
                    when s1 =>
                        if(result_in='0') then
                            n<=s0;
                        else
                            n<=s3;
                        end if;
                    when s2 =>
                        if(result_in='0') then
                            n<=s0;
                        else
                            n<=s3;
                        end if;
                    when s3 =>
                        if(result_in='0') then
                            n<=s2;
                        else
                            n<=s3;
                        end if;
                    end case;
                end if;
            end if;
        end process;
end architecture;