library ieee;
    use ieee.std_logic_1164.all;

library ieee;
    use ieee.std_logic_1164.all;

entity tb is
end entity;

architecture sim of tb is
    signal clk: std_ulogic := '0';
    signal reset: std_ulogic := '1';
    signal output: work.spec.bus_t;
begin
    clk <= not clk after 5 ns;

    dut:
        entity work.gen_test
        generic map(
            --! Wow, package remapping!
            bus_pkg => work.xyz
        )
        port map(clk => clk, reset => reset, output => output);

    p0: process
    begin
        reset <= '1';
        wait for 50 ns;
        reset <= '0';
        wait for 50 ns;
        std.env.stop;
    end process;
end architecture;
