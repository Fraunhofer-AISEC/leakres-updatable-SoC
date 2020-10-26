-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity mixcolumns is
  port (mixcolumns_i    : in  std_ulogic_vector(127 downto 0);
        mixcolumns_o    : out std_ulogic_vector(127 downto 0);
        encrypt_i       : in  std_ulogic
  );
end mixcolumns;

architecture rtl of mixcolumns is

  component column_mult
    port(
      col_i     : in  std_ulogic_vector(31 downto 0);
      col_o     : out std_ulogic_vector(31 downto 0);
      encrypt_i : std_ulogic
    );
  end component;

begin

  column_mult_array : for i in 0 to 3 generate
  begin
    column_mult0 : column_mult port map(
      col_i     => mixcolumns_i((128-1-i*32) downto (128-(i+1)*32)),
      col_o     => mixcolumns_o((128-1-i*32) downto (128-(i+1)*32)),
      encrypt_i => encrypt_i
    );
  end generate;

end rtl;
