library ieee;
    use ieee.std_logic_1164.all;

entity test is
    port(
        clk, reset: in std_ulogic;
        output: out work.spec.bus_t);
end entity;


architecture rtl of test is
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

