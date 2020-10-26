-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.std_iopak.all;



entity aes_lrprf_streamcipher_tb is
end aes_lrprf_streamcipher_tb;



architecture behavioral of aes_lrprf_streamcipher_tb is

  component aes_lrprf_streamcipher
    port (
      clk_i       : in std_ulogic;
      rst_i       : in std_ulogic;
      k_i         : in std_ulogic_vector(127 downto 0);  -- AES key
      prf_i       : in std_ulogic_vector(127 downto 0);  -- PRF Input
      k_we_i      : in std_ulogic;                       -- write enable for key
      prf_we_i    : in std_ulogic;                       -- write enable for PRF
      data_i      : in std_ulogic_vector(127 downto 0);  -- authenticated data or plain-/ciphertext input
      load_i      : in std_ulogic;                       -- process next block
      prfmode_i      : in std_ulogic;                       -- block is last block (length)
--      aad_i       : in std_ulogic;                       -- block is aad, do not decrypt
      decrypt_i   : in std_ulogic;                       -- set for decryption
      busy_o      : out std_ulogic;                      -- core is busy and not accepting data
      rdy_o       : out std_ulogic;                      -- core is initialized and ready for the first/next data block
      data_o      : out std_ulogic_vector(127 downto 0); -- cipher-/plaintext output
      data_rdy_o  : out std_ulogic
--      t_valid_o   : out std_ulogic
    );
  end component;

  signal clk_s      : std_ulogic := '0';
  signal rst_s      : std_ulogic := '0';

  signal k_s         : std_ulogic_vector(127 downto 0) := (others => '0');
  signal prf_s        : std_ulogic_vector(127 downto 0) := (others => '0');
  signal k_we_s      : std_ulogic := '0';
  signal prf_we_s     : std_ulogic := '0';
  signal data_in_s   : std_ulogic_vector(127 downto 0) := (others => '0');
  signal load_s      : std_ulogic := '0';
  signal prfmode_s      : std_ulogic := '0';
--  signal aad_s       : std_ulogic := '0';
  signal decrypt_s   : std_ulogic := '0';
  signal busy_s      : std_ulogic;
  signal rdy_s       : std_ulogic;
  signal data_out_s  : std_ulogic_vector(127 downto 0) := (others => '0');
  signal data_rdy_s  : std_ulogic;
--  signal t_valid_s   : std_ulogic;

  signal key_tmp : std_ulogic_vector(127 downto 0)
 := to_StdULogicVector(From_HexString("00010203050607080A0B0C0D0F101112"));
  signal data_in_tmp : std_ulogic_vector(127 downto 0)
 := to_StdULogicVector(From_HexString("506812A45F08C889B97F5980038B8359"));
  signal data_out_tmp : std_ulogic_vector(127 downto 0)
 := to_StdULogicVector(From_HexString("D8F532538289EF7D06B506A4FD5BE9C9"));

  type data_array is array (NATURAL range<>) of std_ulogic_vector(127 downto 0);
  type aad_identifier_array is array (NATURAL range <>) of std_ulogic;

  ----------------------------------------------------------------------------- 
  -- Testcase TC1 from sw/ui-lrprf_ofb_gmac/testcases/tc1/
  signal key_tc1_enc    : std_ulogic_vector(127 downto 0) := x"0F92E787FC829C8F7EBE69E6EC8721BB";
  signal key_tc1_mac    : std_ulogic_vector(127 downto 0) := x"641DFFB4CC2250431853B3D7EF536F8A";
  signal nonce_tc1      : std_ulogic_vector(127 downto 0) := x"BEC108E3A3AF18F7F0660EDCECABB28D";
  signal hash_tc1       : std_ulogic_vector(127 downto 0) := x"F82D571C512119FFDA1E4669E5954FB5";
  signal tag_tc1        : std_ulogic_vector(127 downto 0) := x"E275F6DABD0F52E45BF471F6EACA9AEA";


  signal ciphertext_tc1 : data_array (0 to 2)  := (x"D7CAE9AD89D417CD43D8C7BD1BC42CB5",
                                                  x"A93576BFE58F29CFDCC4087013FE150B",
                                                  x"34E4DE142C0EC524A03C37F121F7823F");


  signal plaintext_tc1 : data_array (0 to 2) := (x"56563FB8280299A4D680B493C8E66D1D",
                                                 x"E6815CFD90F8B16546DA0FC5B687094D",
                                                 x"7878A35F10BCA8D10C1167594F000000");

  ----------------------------------------------------------------------------- 

begin
  clk_s <= not clk_s after 50 ns;

  dut : aes_lrprf_streamcipher
  port map (
    clk_i       => clk_s,
    rst_i       => rst_s,
    k_i         => k_s,
    prf_i        => prf_s,
    k_we_i      => k_we_s,
    prf_we_i     => prf_we_s,
    data_i      => data_in_s,
    load_i      => load_s,
    prfmode_i   => prfmode_s,
    decrypt_i   => decrypt_s,
    busy_o      => busy_s,
    rdy_o       => rdy_s,
    data_o      => data_out_s,
    data_rdy_o  => data_rdy_s
  );

  process
  begin

    wait until rising_edge(clk_s);
    rst_s <= '1';
    wait for 500 ns;
    rst_s <= '0';
    wait for 500 ns;

    report "************************************************************";
    report "RUN 1 - calc Tag = LRPRF(hash)";
    report "************************************************************";

    report "SETUP KEY MAC";
    -- write key
    k_s <= key_tc1_mac;
    k_we_s <= '1';
    wait for 100 ns;
    k_we_s <= '0';

    report "SETUP hash";
    -- write IV
    prf_s <= hash_tc1;
    prf_we_s <= '1';
    prfmode_s <= '1';
    wait for 100 ns;
    prf_we_s <= '0';
    prfmode_s <= '0';
    wait until data_rdy_s = '1';
    assert data_out_s = tag_tc1
    report "Wrong tag" severity failure;
    
    report "************************************************************";
    report "RUN 2 - rerun";
    report "************************************************************";

    report "SETUP KEY MAC";
    -- write key
    k_s <= key_tc1_mac;
    k_we_s <= '1';
    wait for 100 ns;
    k_we_s <= '0';

    report "SETUP hash";
    -- write IV
    prf_s <= hash_tc1;
    prf_we_s <= '1';
    prfmode_s <= '1';
    wait for 100 ns;
    prf_we_s <= '0';
    prfmode_s <= '0';
    wait until data_rdy_s = '1';
    assert data_out_s = tag_tc1
    report "Wrong tag" severity failure;
    
    
    report "************************************************************";
    report "RUN 3 - decrypt";
    report "************************************************************";
    
    report "SETUP KEY";
    -- write key
    k_s <= key_tc1_enc;
    k_we_s <= '1';
    wait for 100 ns;
    k_we_s <= '0';

    report "SETUP nonce";
    -- write IV
    prf_s <= nonce_tc1;
    prf_we_s <= '1';
    prfmode_s <= '0';
    wait for 100 ns;
    prf_we_s <= '0';
    prfmode_s <= '0';
    wait until busy_s = '0';    
    
    -- write data
    tc1_l : for i in 0 to ciphertext_tc1'length-1 loop
        data_in_s <= ciphertext_tc1(i);
        load_s <= '1';
        decrypt_s <= '1';
        wait for 100 ns;
        load_s <= '0';
        wait until busy_s = '0';
        assert data_out_s = plaintext_tc1(i)
        report "Wrong output" severity failure;
      end loop;
    

    assert false report "Simulation Finished Successfully" severity failure;
    end process;
end behavioral;
