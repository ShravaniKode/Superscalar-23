library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DoubleEncoder is
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
end entity DoubleEncoder;

architecture behavioural of DoubleEncoder is
    component PriorityEncoderActiveHigh is
        generic (
            number_of_inputs : integer := 2 ** 8;
            number_of_outputs : integer := 8 
        );
        port (
            a: in std_logic_vector(number_of_inputs - 1 downto 0);
            y: out std_logic_vector(number_of_outputs - 1 downto 0);
            all_zeros: out std_logic
        );
    end component;

    component Decoder is 
        generic (
            number_of_inputs : integer := 8;
            number_of_outputs : integer := 2 ** 8
        );
        port (
            address: in std_logic_vector(number_of_inputs - 1 downto 0);
            one_hot_encoding_out: out std_logic_vector(number_of_outputs - 1 downto 0)
        );
    end component;

    signal address_first: std_logic_vector(number_of_outputs - 1 downto 0) := (others => '0');
    signal decoder_out: std_logic_vector(number_of_inputs - 1 downto 0) := (others => '0');
    signal second_encoder_in: std_logic_vector(number_of_inputs - 1 downto 0) := (others => '0');

begin
    first_encoder: PriorityEncoderActiveHigh
        generic map(
            number_of_inputs, 
            number_of_outputs
        )

        port map(
            a => a,
            y => address_first,
            all_zeros => valid_first
        );

    dec: Decoder
        generic map(
            number_of_outputs,
            number_of_inputs
        )

        port map(
            address => address_first,
            one_hot_encoding_out => decoder_out
        );

    mark_process: process(a, decoder_out)
    begin
        second_encoder_in <= a and (not decoder_out);
    end process mark_process;

    second_encoder: PriorityEncoderActiveHigh
        generic map(
            number_of_inputs,
            number_of_outputs
        )

        port map(
            a => second_encoder_in,
            y => y_second,
            all_zeros => valid_second
        );

    y_first <= address_first;

end behavioural;