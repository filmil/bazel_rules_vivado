library ieee;
use ieee.std_logic_1164.all;

entity ila_top_vhdl is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        data_bus : in  std_logic_vector(7 downto 0)
    );
end entity ila_top_vhdl;

architecture rtl of ila_top_vhdl is
    signal data_reg : std_logic_vector(7 downto 0);
    signal active   : std_logic;

    -- Declare the ILA IP core as a component
    component my_ila_core is
        port (
            clk    : in std_logic;
            probe0 : in std_logic_vector(0 downto 0);
            probe1 : in std_logic_vector(7 downto 0)
        );
    end component my_ila_core;

begin
    process(clk, rst)
    begin
        if rst = '1' then
            data_reg <= (others => '0');
            active   <= '0';
        elsif rising_edge(clk) then
            data_reg <= data_bus;
            if data_bus /= "00000000" then
                active <= '1';
            else
                active <= '0';
            end if;
        end if;
    end process;

    -- Instantiate the ILA IP core
    ila_inst : my_ila_core
        port map (
            clk       => clk,
            probe0(0) => active,
            probe1    => data_reg
        );

end architecture rtl;
