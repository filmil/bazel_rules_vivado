library ieee;
    use ieee.std_logic_1164.all;

--! Demo of an entity which takes its values from a generic map.
entity gen_test is
    generic(
        --! Bah, this does not work in xsim.
        package bus_pkg is new work.gen generic map (<>)
    );
    port(
        clk, reset: in std_ulogic;
        output: out work.spec.bus_t);
end entity;


architecture rtl of gen_test is
begin
    p0: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                output <= (others => '0');
            else
                output <= not output;
            end if;
        end if;
    end process;
end architecture;

