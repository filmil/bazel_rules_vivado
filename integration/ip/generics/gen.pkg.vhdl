library ieee;
    use ieee.std_logic_1164.all;

package gen is
    generic(width: positive);
    subtype bus_t is std_ulogic_vector(width-1 downto 0);
end package;
