-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hws_aes is
  port (
    clk_i      : in  std_ulogic;
    rst_i      : in  std_ulogic;
    encrypt_i  : in  std_ulogic; -- unused, decryption is not implemented but signal is kept for easy extension
    key_i      : in  std_ulogic_vector (127 downto 0);
    key_we_i   : in  std_ulogic;
    data_i     : in  std_ulogic_vector (127 downto 0);
    start_i    : in  std_ulogic;
    done_o     : out std_ulogic;
    data_o     : out std_ulogic_vector (127 downto 0)
  );
end hws_aes;

architecture rtl of hws_aes is

  component keysched
    port(
      clk_i      : in  std_ulogic;
      rst_i      : in  std_ulogic;
      start_i    : in  std_ulogic;
      key_we_i   : in  std_ulogic;
      rnd_cnt_i  : in  unsigned(7 downto 0);
      key_i      : in  std_ulogic_vector(127 downto 0);
      roundkey_o : out std_ulogic_vector(127 downto 0);
      encrypt_i  : in  std_ulogic
    );
  end component;

  component addroundkey
    port ( key_i         : in  std_ulogic_vector(127 downto 0);
           addroundkey_i : in  std_ulogic_vector(127 downto 0);
           addroundkey_o : out std_ulogic_vector(127 downto 0)
    );
  end component;

  component subbytes
  port (
    subbytes_i : in  std_ulogic_vector (127 downto 0);
    subbytes_o : out std_ulogic_vector (127 downto 0);
    encrypt_i  : in  std_ulogic
    );
  end component;

  component shiftrows
    port( shiftrows_i : in  std_ulogic_vector (127 downto 0);
          shiftrows_o : out std_ulogic_vector (127 downto 0);
          encrypt_i   : in  std_ulogic
    );
  end component;

  component mixcolumns
    port( mixcolumns_i : in  std_ulogic_vector(127 downto 0);
          mixcolumns_o : out std_ulogic_vector(127 downto 0);
          encrypt_i    : in  std_ulogic
    );
  end component;

  signal roundkey_s       : std_ulogic_vector(127 downto 0);
  signal addroundkey_in_s : std_ulogic_vector(127 downto 0);
  signal state_s          : std_ulogic_vector(127 downto 0);
  signal subbytes_out_s   : std_ulogic_vector(127 downto 0);
  signal shiftrow_out_s   : std_ulogic_vector(127 downto 0);
  signal mixcolumns_out_s : std_ulogic_vector(127 downto 0);

  signal rnd_cnt_r  : unsigned(7 downto 0);
  signal rnd_cnt_s  : unsigned(7 downto 0);
  signal state_r    : std_ulogic_vector(127 downto 0);
  signal state_we_s : std_ulogic;
  signal running_r  : std_ulogic;
  signal done_s     : std_ulogic;
  signal done_r     : std_ulogic;

begin

  keysched0 : keysched port map(
    clk_i       => clk_i,
    rst_i       => rst_i,
    encrypt_i   => encrypt_i,
    key_we_i    => key_we_i,
    start_i     => start_i,
    rnd_cnt_i   => rnd_cnt_s,
    key_i       => key_i,
    roundkey_o  => roundkey_s
  );

  rnd_cnt_s <= (others => '0') when start_i = '1' else rnd_cnt_r;

  -- addroundkey mux
  addroundkey_in_s <= data_i           when rnd_cnt_r = 11
                 else shiftrow_out_s   when rnd_cnt_r = 10
                 else mixcolumns_out_s;

  addroundkey0 : addroundkey port map(
    key_i         => roundkey_s,
    addroundkey_i => addroundkey_in_s,
    addroundkey_o => state_s
  );

  state_p : process(clk_i)
  begin
    if (clk_i'event and clk_i = '1') then
      if rst_i = '1' or key_we_i = '1' then
        state_r <= (others => '0');
      elsif start_i = '1' or state_we_s = '1' then
        state_r <= state_s;
      end if;
    end if;
  end process;

  state_we_s <= running_r;

  subbytes0 : subbytes port map(
    subbytes_i => state_r,
    subbytes_o => subbytes_out_s,
    encrypt_i  => encrypt_i
  );

  shiftrows0 : shiftrows port map(
    shiftrows_i => subbytes_out_s,
    shiftrows_o => shiftrow_out_s,
    encrypt_i  => encrypt_i
  );

  mixcolumns0 : mixcolumns port map(
    mixcolumns_i => shiftrow_out_s,
    mixcolumns_o => mixcolumns_out_s,
    encrypt_i  => encrypt_i
  );


  -- round counter
  rnd_cnt_p : process(clk_i)
  begin
    if (clk_i'event and clk_i = '1') then
      if rst_i = '1' then
        rnd_cnt_r <= to_unsigned(11, 8);
        running_r <= '0';
      else
        if start_i = '1' then
          rnd_cnt_r <= to_unsigned(1,8);
          running_r <= '1';
        elsif rnd_cnt_r = 10 then
          running_r <= '0';
        end if;
        if running_r = '1' then
          rnd_cnt_r <= rnd_cnt_r + 1;
        end if;
      end if;
    end if;
  end process;

  -- emit done signal only for one cycle
  done_p : process(clk_i)
  begin
    if (clk_i'event and clk_i = '1') then
      if rst_i = '1' then
        done_r <= '0';
      else
        done_r <= done_s;
      end if;
    end if;
  end process;

  done_s <= '1' when rnd_cnt_r = 11 else '0';
  done_o <= done_s and not  done_r;
  data_o <= state_r when rnd_cnt_r = 11 else (others => '0');

end rtl;
