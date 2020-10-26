-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity shiftrows is
  port( shiftrows_i : in  std_ulogic_vector (127 downto 0);
        shiftrows_o : out std_ulogic_vector (127 downto 0);
        encrypt_i   : in  std_ulogic
  );
end shiftrows;

architecture rtl of shiftrows is
begin

  shiftrows_o <=  shiftrows_i(127 downto 120) &
                  shiftrows_i(87  downto 80) &
                  shiftrows_i(47  downto 40) &
                  shiftrows_i(7   downto 0) &

                  shiftrows_i(95  downto 88) &
                  shiftrows_i(55  downto 48) &
                  shiftrows_i(15  downto 8) &
                  shiftrows_i(103 downto 96) &

                  shiftrows_i(63  downto 56) &
                  shiftrows_i(23  downto 16) &
                  shiftrows_i(111 downto 104) &
                  shiftrows_i(71  downto 64) &

                  shiftrows_i(31  downto 24) &
                  shiftrows_i(119 downto 112) &
                  shiftrows_i(79  downto 72) &
                  shiftrows_i(39  downto 32);

end rtl;

