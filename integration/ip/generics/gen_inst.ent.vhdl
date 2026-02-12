library ieee;
    use ieee.std_logic_1164.all;

--! This package is a concrete package created from `work.gen` and supplying
--! width => 1!
package xyz is new work.gen generic map(width => 1);

library ieee;
    use ieee.std_logic_1164.all;

entity gen_inst is
    port(
        clk, reset: in std_ulogic;
        output: out work.spec.bus_t);
end entity;


architecture rtl of gen_inst is
    signal x: work.xyz.bus_t;
begin
    output(0) <= x(0);
    e0: entity work.gen_test generic map(
        bus_pkg => work.xyz
    )
    port map(
        clk => clk,
        reset => reset,
        output => x);
end architecture;


