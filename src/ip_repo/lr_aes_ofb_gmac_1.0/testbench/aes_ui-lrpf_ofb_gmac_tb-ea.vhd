-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.std_iopak.all;



entity aes_ui_lrprf_ofb_gmac_tb is
end aes_ui_lrprf_ofb_gmac_tb;



architecture behavioral of aes_ui_lrprf_ofb_gmac_tb is

  component aes_ui_lrprf_ofb_gmac
    generic (
      key_cnt_g         : integer
    );
    port (
      clk_i       : in std_ulogic;
      rst_i       : in std_ulogic;
      k_i         : in std_ulogic_vector(127 downto 0);  -- AES key
      iv_i        : in std_ulogic_vector(127 downto 0);  -- Initialization Vector
      k_we_i      : in std_ulogic;                       -- write enable for key
      iv_we_i     : in std_ulogic;                       -- write enable for IV
      data_i      : in std_ulogic_vector(127 downto 0);  -- authenticated data or plain-/ciphertext input
      load_i      : in std_ulogic;                       -- process next block
      last_i      : in std_ulogic;                       -- block is last block (length)
      aad_i       : in std_ulogic;                       -- block is aad, do not decrypt
      decrypt_i   : in std_ulogic;                       -- set for decryption
      busy_o      : out std_ulogic;                      -- core is busy and not accepting data
      rdy_o       : out std_ulogic;                      -- core is initialized and ready for the first/next data block
      data_o      : out std_ulogic_vector(127 downto 0); -- cipher-/plaintext output
      data_rdy_o  : out std_ulogic;
      t_valid_o   : out std_ulogic
    );
  end component;

  signal clk_s      : std_ulogic := '0';
  signal rst_s      : std_ulogic := '0';

  signal k_s         : std_ulogic_vector(127 downto 0) := (others => '0');
  signal iv_s        : std_ulogic_vector(127 downto 0) := (others => '0');
  signal k_we_s      : std_ulogic := '0';
  signal iv_we_s     : std_ulogic := '0';
  signal data_in_s   : std_ulogic_vector(127 downto 0) := (others => '0');
  signal load_s      : std_ulogic := '0';
  signal last_s      : std_ulogic := '0';
  signal aad_s       : std_ulogic := '0';
  signal decrypt_s   : std_ulogic := '0';
  signal busy_s      : std_ulogic;
  signal rdy_s       : std_ulogic;
  signal data_out_s  : std_ulogic_vector(127 downto 0) := (others => '0');
  signal data_rdy_s  : std_ulogic;
  signal t_valid_s   : std_ulogic;

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
  signal key_tc1_0    : std_ulogic_vector(127 downto 0) := x"0001020304050607080a0b0c0de00f10";
  signal key_tc1_1    : std_ulogic_vector(127 downto 0) := x"1112131415161718191a1b1c1d1e1f20";
  signal iv_gmac_tc1  : std_ulogic_vector(127 downto 0) := x"00000000000000000000000000000000";
  signal iv_tc1       : std_ulogic_vector(127 downto 0) := x"00112233445566778899aabb00000000";
  signal len_tc1      : std_ulogic_vector(127 downto 0) := x"00000000000000000000000000000200";
  signal tag_tc1      : std_ulogic_vector(127 downto 0) := x"65abd05cec6b04933a18e6346ede418d";


  signal ac_tc1 : data_array (0 to 3)         := (x"13ce4b64766d86566a6f9a7c0e8b7ebb",
                                                  x"0992bade144f0694ba4add389b1efaad",
                                                  x"345b259966c5f03a3a04d20f9ee01c64",
                                                  x"5f1b6c138c37e40182d729d181d37f56");
  signal aad_tc1 : aad_identifier_array (0 to 3) := ('0', '0', '0', '0');

  signal plaintext_tc1 : data_array (0 to 3) := (x"11111111111111111111111111111111",
                                                 x"22222222222222222222222222222222",
                                                 x"31313131313131313131313131313131",
                                                 x"13131313131313131313131313131313");
  ----------------------------------------------------------------------------- 
  -- Testcase TC2 from sw/ui-lrprf_ofb_gmac/testcases/tc2/
  signal key_tc2_0    : std_ulogic_vector(127 downto 0) := x"0001020304050607080a0b0c0de00f10";
  signal key_tc2_1    : std_ulogic_vector(127 downto 0) := x"1112131415161718191a1b1c1d1e1f20";
  signal iv_gmac_tc2  : std_ulogic_vector(127 downto 0) := x"abababab12345656fffff221cafe1337";
  signal iv_tc2       : std_ulogic_vector(127 downto 0) := x"00112233445566778899aabb00000000";
  signal len_tc2      : std_ulogic_vector(127 downto 0) := x"00000000000004000000000000002000";
  signal tag_tc2      : std_ulogic_vector(127 downto 0) := x"cea226237157561f889eba227f0d5aaf";

  signal ac_tc2 : data_array (0 to 71)       := (x"129a89872bdfa40e2489c09bfce0e509",
                                                 x"b667dc1ccd7c270b78455421f3daacb5",
                                                 x"cf9ac1602a999d6db03b4b37aec679f7",
                                                 x"27a41511c47dcb211779b0e4833d07d7",
                                                 x"1da14b69b71510e48235e4d6e39ee706",
                                                 x"29448378db94d6eae1c8ef9ec64f0c7a",
                                                 x"ac145d1cadfbd8210b598d59d80a687e",
                                                 x"8351083c587b051357207e6583bb232b",   -- AAD ends here
                                                 x"18533986c0c093d9c95ce08f8f81207f",
                                                 x"c2b9c07e5a439680e6a5afb887b3613a",
                                                 x"389d25aa2dcbcc711b191baaec58239f",
                                                 x"4992abfb663e41f89ef55de1b693f529",
                                                 x"1d3e13fdb8f102f558dbcba710b06856",
                                                 x"3327ff1c58b7a96001a6da6f12894aec",
                                                 x"208123349b65e4323e9cc54036ab71d9",
                                                 x"08a5eda5b0f8e4d035b25baca96b7212",
                                                 x"6ba8dd779f9d7b38a5d7c69f9727f4ed",
                                                 x"e53128ed2537bf1d9e0629ef84e8940e",
                                                 x"1f527481e31ac34c1a3133f7d56c80f2",
                                                 x"35b904c4b91dbf0b19cd65acb585b7ba",
                                                 x"7c50c41171ceb66273bf67ee0a5a5c3a",
                                                 x"e4efcc3eab46b7bdbf092d55e0b3d6f5",
                                                 x"bfea4c49e67907456fd7a8239bf083d3",
                                                 x"29161537d909fe0d43e90827918debfe",
                                                 x"d8c8cf12b4e95f302fd950301443253d",
                                                 x"342c228b55710b43d78adda53b7f8c81",
                                                 x"f1a2c7247f252d864ceeec7d44dd9148",
                                                 x"e557c8214287ed148b61001725051548",
                                                 x"899ba49b8a759ddd6ce7e698fba19b60",
                                                 x"928e327be467883ad044221ac768f889",
                                                 x"31d43a6d722d8c77ae2d1c92b1e01b3e",
                                                 x"c16919edc39863566a6971b922f3ba3f",
                                                 x"93e38d1dcafcabef6c4914fc118f54e9",
                                                 x"468e11820d47f66bc1679b934b1ccc0d",
                                                 x"6557db52f78159d37b5df83b12bd43f7",
                                                 x"e576b53ddd3c14cdd0b02c396648c37a",
                                                 x"3f465f7050784ad2ea18be681d7f65d6",
                                                 x"637c6afd4a8bfb735cae2298696dde4d",
                                                 x"af53c467a064f078ea45799253c23291",
                                                 x"4aa57e6bbb76ef1301d717b9fe0801ca",
                                                 x"495f9be3fb7f511a83febec36a3fc5b1",
                                                 x"6d83c98c384450254f0187e3e0641b86",
                                                 x"74261b4c56169442b7af0da48ebb40f1",
                                                 x"551c553118a9e1bdfecd702be43801bf",
                                                 x"70e3ce7cc5a53446fcb41a8b35d378d9",
                                                 x"95a54070605914fe4c139110f744038f",
                                                 x"da868a9b283702d713cd66b7a0ea288a",
                                                 x"08aef8cd5149184c6bd6735f55675ceb",
                                                 x"ece21660c658c63645e69993dd486fbd",
                                                 x"c741677f7bbe0f8306ee10ec85e4d8bd",
                                                 x"83f5747700e0e43a51f88620e8c5e822",
                                                 x"a772b6feaaf6fae91cf7c3898106ea6a",
                                                 x"3d61b19d79cbb163ac6dbf7f537d3c82",
                                                 x"fd75ab0c3bc1deac74ba57f7abf90c47",
                                                 x"a97e822f74766aa31307fa71d03de6f0",
                                                 x"ac6d7c179cb43b7259e96925d6d65068",
                                                 x"9df884334389d659f175e4db72605ffa",
                                                 x"e86136b40387d3179351dcfc8db5a78d",
                                                 x"89283d2a7df8372d71f5d03fc8e08d02",
                                                 x"ff7679cdec15d0338df76b2a88a3be56",
                                                 x"e96e64b1f0b046e63b68c6c385d647ea",
                                                 x"15f364a3584bef5a3ecc7dc0a9c90af6",
                                                 x"63ec5c6ae0606bca584784b22cf428ac",
                                                 x"580b176fa187ef37f3f82b8b9214c41c",
                                                 x"300bfe1b06817f7f5d66cb2f27bf3e24",
                                                 x"6d64ed66073e4aa7f1448e93f61a9689",
                                                 x"5413db254844e6556ff40ce2f075a2ef",
                                                 x"b04a0707dd0176fb8831e8731e919257",
                                                 x"a5bb1eb8dbbc5fd2c3031b3646af33bd",
                                                 x"394a9398d4b1c3bcb1416d4b412f1fb9",
                                                 x"d6561eccc61095cc20c39412e6f6c474",
                                                 x"2c7bfe532036ae2ff5bad5a95b12fb0b");

  signal aad_tc2 : aad_identifier_array (0 to 71) := ('1', '1', '1', '1', '1', '1', '1', '1',
                                                      '0', '0', '0', '0', '0', '0', '0', '0',
                                                      '0', '0', '0', '0', '0', '0', '0', '0',
                                                      '0', '0', '0', '0', '0', '0', '0', '0',
                                                      '0', '0', '0', '0', '0', '0', '0', '0',
                                                      '0', '0', '0', '0', '0', '0', '0', '0',
                                                      '0', '0', '0', '0', '0', '0', '0', '0',
                                                      '0', '0', '0', '0', '0', '0', '0', '0',
                                                      '0', '0', '0', '0', '0', '0', '0', '0'
                                                     );

  signal plaintext_tc2 : data_array (0 to 71) := (x"00000000000000000000000000000000",
                                                  x"00000000000000000000000000000000",
                                                  x"00000000000000000000000000000000",
                                                  x"00000000000000000000000000000000",
                                                  x"00000000000000000000000000000000",
                                                  x"00000000000000000000000000000000",
                                                  x"00000000000000000000000000000000",
                                                  x"00000000000000000000000000000000",
                                                  x"1a8c63f3a7bc049eb2226be2901b4fd5",
                                                  x"e90958826c2eb2367ecd50a23e8fb9b5",
                                                  x"3df731027a3f0d7a102cf89443890eca",
                                                  x"059ad4fbf91ab6ea0f3167232453996c",
                                                  x"8353681380d050ca12219ad25cc3e90d",
                                                  x"d68b96e3b36329a2a0ba1221a0069d86",
                                                  x"2ddeef791c1fa1daca4b3eafcd555e21",
                                                  x"cc3eec42ae179d96e726db35c069b239",
                                                  x"7dbe0b670262d3b2a8227d41384e2cf9",
                                                  x"10f846cbc2639683e95d3cdf78ce62f9",
                                                  x"c2338b352460a20959955357a60a184b",
                                                  x"205927512b7aa9dadf88ffa1733583b3",
                                                  x"904932ce36686e1a39390fa49ae744ee",
                                                  x"4a6798297ce9a4708c9ca7131d5ddab6",
                                                  x"ccb80d781a3d8bbad6e8043a4558a5f8",
                                                  x"78296cf5cc490b9209fb76657c3eb3cd",
                                                  x"0164ca1df5f148fcfd69ec5fd3666de6",
                                                  x"1e41905afa3d8ba8ec9b39d454d235f9",
                                                  x"b01129a2e1f1b4019b249b68365e0cbd",
                                                  x"82cf8e071d67ac038863e74586e3970d",
                                                  x"55fa5b1a60b2578037a1a56f40d26ae5",
                                                  x"9bb56de2a055540510be36abaeb46a4f",
                                                  x"f1b2e475ac692702c940ca4dfca8292d",
                                                  x"6e3e8ea4d9f058c837257774cd7b36fa",
                                                  x"dd3a29d3c87fc71da1fcdcc2392a2ffe",
                                                  x"a153691e8b41ed73fdfbbfaf45946b89",
                                                  x"c2618f02a43ef1a808460b2ade834252",
                                                  x"0d60815e840d9cc40433c5011217a8b9",
                                                  x"51532aeecc5a38ae6f832f3b348f5d79",
                                                  x"89157fe87e15e6a73d7f65c4baac9081",
                                                  x"4d68c304c4089bf75be090231b87cc72",
                                                  x"29ec875aac840bb8ca63d41e39961f0a",
                                                  x"bc5adf5ad7a35c36de1c192a0f224e8b",
                                                  x"a39010031995aa4945120fa0bca380f0",
                                                  x"ffd8336b91f8bd96f45f609bc01cb094",
                                                  x"93c4289caf20c79d6efcab6fddaacec7",
                                                  x"22f33cecb38a48ded1ace1d6016c7b96",
                                                  x"b4c789cae8d935ce3810e08cb4ecd739",
                                                  x"b8b2445d0efbfe27f8499a028464333e",
                                                  x"d3da831f18b1597ff1a471cc8a6f1a3f",
                                                  x"4d0c88dec28a02c062e297656e0f83f7",
                                                  x"af9d87f192bb740af5e8ba9e0e55b773",
                                                  x"9d459f3408c3fb0dfb7e65ac7659c9ac",
                                                  x"4a2f40664bb61690db49b46228f797bf",
                                                  x"cb94d4c2cd02ab80bf6faf6d97aeebfd",
                                                  x"9edaf01d89ea92a990958b6f48a79d1f",
                                                  x"157e71c7feb953ef2cdf0e6269631eb5",
                                                  x"1ea1fd78ce5e997ffbcd17d585699fad",
                                                  x"5cc80d39d6fb4f573dc512f0068bbbf8",
                                                  x"c9997f5b4a1d5fa0c5274a3d642f389f",
                                                  x"6594827ed701414e62f855ae21177990",
                                                  x"6829dfebcadc5e79a9abd2043cfab5e5",
                                                  x"a7864d0fd3bf1550c943dd389001d55b",
                                                  x"fcb2e617a2ccdf4cfd41b2036497de49",
                                                  x"336af5ace2dea10aca3bc75095dd4c95",
                                                  x"e32d4eb6580606e3c3506e50862069e1",
                                                  x"0b91b76188d7a3f7a954ae0ca5574f83",
                                                  x"7c55a08fc7327b2394773b6c0ded89a4",
                                                  x"1e93fae0adf5bbe98418ea2689ce1a86",
                                                  x"0238d9b9d751a9f9ae0de05c7bc7d571",
                                                  x"82f2accd034299cf71677db12427969c",
                                                  x"ed7561bab144159ab72d349ef1142055",
                                                  x"3e1f0b07e9fa7bc6c124261d44068636",
                                                  x"523c9661daa3057810c5547ae38d502f");

  ----------------------------------------------------------------------------- 
  -- Testcase TC3 from sw/ui-lrprf_ofb_gmac/testcases/tc3/
  signal key_tc3_0    : std_ulogic_vector(127 downto 0) := x"bac102030bc20607080a0bfe0deccdf0";
  signal key_tc3_1    : std_ulogic_vector(127 downto 0) := x"1ff21314151ef23819121b1c10000020";
  signal iv_gmac_tc3  : std_ulogic_vector(127 downto 0) := x"ffffffffffffffffffffffffffffffff";
  signal iv_tc3       : std_ulogic_vector(127 downto 0) := x"ff112233445312778293432b00000000";
  signal len_tc3      : std_ulogic_vector(127 downto 0) := x"00000000000002000000000000000200";
  signal tag_tc3      : std_ulogic_vector(127 downto 0) := x"6aef080a547cbcf4842fb3a1233c5749";

  signal ac_tc3 : data_array (0 to 7)        := (x"25e9c996207a1b2b907b09247086eb88",
                                                 x"975f709869bf45d638ad79b2a19f1d2f",
                                                 x"e82ed35cc61e17bb294156481a1148f0",
                                                 x"09a7871a59648066f2c383b7dd52e68b",   -- AAD ends here
                                                 x"8f01c4f3d53a10c2b5598e61c757d808",
                                                 x"3b21be1f506cbb2f2a6bf1157d3f8a2e",
                                                 x"f1f1a690f452c3a0e679c240cc4b35e7",
                                                 x"502ee19f32dad1133c17ec7dfa33fbd8");

  signal aad_tc3 : aad_identifier_array (0 to 7) := ('1', '1', '1', '1', '0', '0', '0', '0');

  signal plaintext_tc3 : data_array (0 to 7) :=  (x"00000000000000000000000000000000",
                                                  x"00000000000000000000000000000000",
                                                  x"00000000000000000000000000000000",
                                                  x"00000000000000000000000000000000",
                                                  x"96127999ae62cf773e080637c65755cc",
                                                  x"49bce8e10fccf1eba21364dd1122ae43",
                                                  x"c89bf3c3f61aeb9f17f71ee0eb72dc3b",
                                                  x"ce75807ded8b87beb57a994be59b2711");

  ----------------------------------------------------------------------------- 

begin
  clk_s <= not clk_s after 50 ns;

  dut : aes_ui_lrprf_ofb_gmac
  generic map (
    key_cnt_g         => 2
  )
  port map (
    clk_i       => clk_s,
    rst_i       => rst_s,
    k_i         => k_s,
    iv_i        => iv_s,
    k_we_i      => k_we_s,
    iv_we_i     => iv_we_s,
    data_i      => data_in_s,
    load_i      => load_s,
    last_i      => last_s,
    aad_i       => aad_s,
    decrypt_i   => decrypt_s,
    busy_o      => busy_s,
    rdy_o       => rdy_s,
    data_o      => data_out_s,
    data_rdy_o  => data_rdy_s,
    t_valid_o   => t_valid_s
  );

  process
  begin

    wait until rising_edge(clk_s);
    rst_s <= '1';
    wait for 500 ns;
    rst_s <= '0';
    wait for 500 ns;

    report "************************************************************";
    report "RUN 1 - decrypt w/o AAD (TC1)";
    report "************************************************************";

    report "SETUP KEY0";
    -- write key
    k_s <= key_tc1_0;
    k_we_s <= '1';
    wait for 100 ns;
    k_we_s <= '0';

    report "SETUP KEY1";
    -- write key
    k_s <= key_tc1_1;
    k_we_s <= '1';
    wait for 100 ns;
    k_we_s <= '0';
    wait until busy_s = '0';

    report "SETUP IVgmac";
    -- write IV
    iv_s <= iv_gmac_tc1;
    iv_we_s <= '1';
    wait for 100 ns;
    iv_we_s <= '0';
    wait until busy_s = '0';

    report "SETUP IV";
    -- write IV
    iv_s <= iv_tc1;
    iv_we_s <= '1';
    wait for 100 ns;
    iv_we_s <= '0';
    wait until busy_s = '0';

    -- write data
    tc1_l : for i in 0 to ac_tc1'length-1 loop
      data_in_s <= ac_tc1(i);
      aad_s <= aad_tc1(i);
      load_s <= '1';
      decrypt_s <= '1';
      wait for 100 ns;
      load_s <= '0';
      wait until busy_s = '0';
      assert data_out_s = plaintext_tc1(i)
      report "Wrong output" severity failure;
    end loop;

    -- write length
    data_in_s <= len_tc1;
    load_s <= '1';
    last_s <= '1';
    wait for 100 ns;
    load_s <= '0';
    last_s <= '0';
    wait until busy_s = '0';

    -- write tag for comparison
    data_in_s <= tag_tc1;
    load_s <= '1';
    wait for 100 ns;
    load_s <= '0';
    wait for 100 ns;
    assert t_valid_s = '1' and data_out_s = tag_tc1
    report "Tag invalid" severity failure;

    wait for 5000 ns;

    report "************************************************************";
    report "RUN 2 -  Rewrite IV and repeat Run 1 (TC1)";
    report "************************************************************";

    report "SETUP IV";
    -- write IV
    iv_s <= iv_tc1;
    iv_we_s <= '1';
    wait for 100 ns;
    iv_we_s <= '0';
    wait until busy_s = '0';

    -- write data
    tcr3_l : for i in 0 to ac_tc1'length-1 loop
      data_in_s <= ac_tc1(i);
      aad_s <= aad_tc1(i);
      load_s <= '1';
      decrypt_s <= '1';
      wait for 100 ns;
      load_s <= '0';
      wait until busy_s = '0';
      assert data_out_s = plaintext_tc1(i)
      report "Wrong output" severity failure;
    end loop;

    -- write length
    data_in_s <= len_tc1;
    load_s <= '1';
    last_s <= '1';
    wait for 100 ns;
    load_s <= '0';
    last_s <= '0';
    wait until busy_s = '0';

    -- write tag for comparison
    data_in_s <= tag_tc1;
    load_s <= '1';
    wait for 100 ns;
    load_s <= '0';
    wait for 100 ns;
    assert t_valid_s = '1' and data_out_s = tag_tc1
    report "Tag invalid" severity failure;

    wait for 5000 ns;

    report "************************************************************";
    report "RUN 3 - decrypt w/ AAD (TC2)";
    report "************************************************************";

    report "SETUP KEY0";
    -- write key
    k_s <= key_tc2_0;
    k_we_s <= '1';
    wait for 100 ns;
    k_we_s <= '0';

    report "SETUP KEY1";
    -- write key
    k_s <= key_tc2_1;
    k_we_s <= '1';
    wait for 100 ns;
    k_we_s <= '0';
    wait until busy_s = '0';

    report "SETUP IVgmac";
    -- write IV
    iv_s <= iv_gmac_tc2;
    iv_we_s <= '1';
    wait for 100 ns;
    iv_we_s <= '0';
    wait until busy_s = '0';

    report "SETUP IV";
    -- write IV
    iv_s <= iv_tc2;
    iv_we_s <= '1';
    wait for 100 ns;
    iv_we_s <= '0';
    wait until busy_s = '0';

    -- write data
    tc2_l : for i in 0 to ac_tc2'length-1 loop
      data_in_s <= ac_tc2(i);
      aad_s <= aad_tc2(i);
      load_s <= '1';
      decrypt_s <= '1';
      wait for 100 ns;
      load_s <= '0';
      wait until busy_s = '0';
      if aad_tc2(i) = '0' then
        assert data_out_s = plaintext_tc2(i)
        report "Wrong output" severity failure;
      end if;
    end loop;

    -- write length
    data_in_s <= len_tc2;
    load_s <= '1';
    last_s <= '1';
    wait for 100 ns;
    load_s <= '0';
    last_s <= '0';
    wait until busy_s = '0';

    -- write tag for comparison
    data_in_s <= tag_tc2;
    load_s <= '1';
    wait for 100 ns;
    load_s <= '0';
    wait for 100 ns;
    assert t_valid_s = '1' and data_out_s = tag_tc2
    report "Tag invalid" severity failure;

    wait for 5000 ns;

    report "************************************************************";
    report "RUN 4 - change keys and decrypt w AAD (TC3)" ;
    report "************************************************************";

    report "SETUP KEY0";
    -- write key
    k_s <= key_tc3_0;
    k_we_s <= '1';
    wait for 100 ns;
    k_we_s <= '0';

    report "wait between keys";
    wait for 1000 ns;

    report "SETUP KEY1";
    -- write key
    k_s <= key_tc3_1;
    k_we_s <= '1';
    wait for 100 ns;
    k_we_s <= '0';
    wait until busy_s = '0';

    report "SETUP IVgmac";
    -- write IV
    iv_s <= iv_gmac_tc3;
    iv_we_s <= '1';
    wait for 100 ns;
    iv_we_s <= '0';
    wait until busy_s = '0';

    report "wait before iv";
    wait for 1000 ns;
    report "SETUP IV";
    -- write IV
    iv_s <= iv_tc3;
    iv_we_s <= '1';
    wait for 100 ns;
    iv_we_s <= '0';
    wait until busy_s = '0';

    -- write data
    tcr4_l : for i in 0 to ac_tc3'length-1 loop
      data_in_s <= ac_tc3(i);
      aad_s <= aad_tc3(i);
      load_s <= '1';
      decrypt_s <= '1';
      wait for 100 ns;
      load_s <= '0';
      wait until busy_s = '0';
      wait for 1000 ns;
      if aad_tc3(i) = '0' then
        assert data_out_s = plaintext_tc3(i)
        report "Wrong output" severity failure;
      end if;
    end loop;

    -- write length
    data_in_s <= len_tc3;
    load_s <= '1';
    last_s <= '1';
    wait for 100 ns;
    load_s <= '0';
    last_s <= '0';
    wait until busy_s = '0';
    wait for 1000 ns;

    -- write tag for comparison
    data_in_s <= tag_tc3;
    load_s <= '1';
    wait for 100 ns;
    load_s <= '0';
    wait for 100 ns;
    assert t_valid_s = '1' and data_out_s = tag_tc3
    report "Tag invalid" severity failure;

    assert false report "Simulation Finished Successfully" severity failure;
    end process;
end behavioral;
