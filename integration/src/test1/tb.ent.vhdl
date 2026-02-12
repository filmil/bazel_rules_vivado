library ieee;
    use ieee.std_logic_1164.all;

entity tb is
end entity;

architecture sim of tb is
    signal clk: std_ulogic := '0';
    signal reset: std_ulogic := '1';
    signal output: std_ulogic;
begin
    clk <= not clk after 5 ns;

    dut: entity work.test port map(clk => clk, reset => reset, output => output);

    p0: process
    begin
        reset <= '1';
        wait for 50 ns;
        reset <= '0';
        wait for 50 ns;
        std.env.stop;
    end process;
end architecture;
