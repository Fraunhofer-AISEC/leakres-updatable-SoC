-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity aes_icap_data is
    Port ( 
           clk_i : in STD_LOGIC;
           rst_i : in STD_LOGIC;
		-- aes interface
           aes_data_i : in STD_LOGIC_VECTOR (127 downto 0);
           aes_data_stb_i : in STD_LOGIC;
           aes_tag_valid_i : in STD_LOGIC;
           aes_tag_invalid_i : in STD_LOGIC;
		-- ICAP interface
           icap_tdata_o : out STD_LOGIC_VECTOR (31 downto 0);
           icap_abort_o : out STD_LOGIC;
           icap_tvalid_o : out STD_LOGIC;
           icap_tready_i : in STD_LOGIC);
end aes_icap_data;

architecture Behavioral of aes_icap_data is
	------ state reg ------
	type state_t is (IDLE_e,
					TX_START_e,
					INIT_TX_DATA_1_e,
					INIT_TX_DATA_2_e,
					INIT_TX_DATA_3_e,
					INIT_TX_DATA_4_e,
					INIT_TX_DATA_LAST_e,
					INIT_TX_DATA_ERROR_e,
					CLEANUP_e);
	signal state_reg, next_state_s : state_t;
	------ data reg ------
	signal data_reg1 : std_logic_vector(31 downto 0);
	signal data_reg2 : std_logic_vector(31 downto 0);
	signal data_reg3 : std_logic_vector(31 downto 0);
	signal data_reg4 : std_logic_vector(31 downto 0);


   ------ system ------
	signal clk_int    : std_logic;
	signal rst_int    : std_logic;

   ------ inputs ------
	signal aes_data_int           : std_logic_vector(127 downto 0);
	signal aes_data_stb_int       : std_logic;
	signal aes_tag_valid_int      : std_logic;
	signal aes_tag_invalid_int    : std_logic;

   ------ outputs ------
	signal icap_tdata_int         : std_logic_vector(31 downto 0);
	signal icap_abort_int         : std_logic;
	signal icap_tvalid_int        : std_logic;
	signal aes_ready_int          : std_logic;

begin

	-- State machine --
	nxt_state_p : process(state_reg,aes_data_stb_i,icap_tready_i,aes_tag_valid_i)
	begin
		next_state_s <= state_reg;

		case state_reg is
			when IDLE_e =>
				if aes_data_stb_i = '1' and aes_tag_valid_i = '1' then
					next_state_s <= INIT_TX_DATA_1_e;
				else
					next_state_s <= IDLE_e;
				end if;

			when INIT_TX_DATA_1_e =>
				if icap_tready_i ='1' then
					next_state_s <= INIT_TX_DATA_2_e;
				else
					next_state_s <= INIT_TX_DATA_ERROR_e;
				end if;

			when INIT_TX_DATA_2_e =>
				if icap_tready_i ='1' then
					next_state_s <= INIT_TX_DATA_3_e;
				else
					next_state_s <= INIT_TX_DATA_ERROR_e;
				end if;

			when INIT_TX_DATA_3_e =>
				if icap_tready_i ='1' then
					next_state_s <= INIT_TX_DATA_4_e;
				else
					next_state_s <= INIT_TX_DATA_ERROR_e;
				end if;

			when INIT_TX_DATA_4_e =>
					next_state_s <= INIT_TX_DATA_LAST_e;

			when INIT_TX_DATA_LAST_e =>
					next_state_s <= CLEANUP_e;
			when INIT_TX_DATA_ERROR_e =>
					next_state_s <= INIT_TX_DATA_ERROR_e;

			when CLEANUP_e =>
				next_state_s <= IDLE_e;
			when others =>
				null;
		end case;
	end process;

  state_reg_p : process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      state_reg <= IDLE_e;
    elsif clk_i'event and clk_i = '1' then
      state_reg <= next_state_s;
    end if;
  end process;

  --------------------------------
  -- AES data out process
  --------------------------------
  aes_data_out_p : process(clk_i, rst_i)
  begin
	  if rst_i = '1' then
		  data_reg1 <= (others => '0');
		  data_reg2 <= (others => '0');
		  data_reg3 <= (others => '0');
		  data_reg4 <= (others => '0');
		  icap_tvalid_int <= '0';
	  elsif clk_i'event and clk_i = '1' then
		  if aes_data_stb_i = '1' then
			  data_reg1 <= aes_data_i(127 downto 96);
			  data_reg2 <= aes_data_i(95 downto 64);
			  data_reg3 <= aes_data_i(63 downto 32);
			  data_reg4 <= aes_data_i(31 downto 0);
			  icap_tvalid_int <= '1';
		  elsif (state_reg = CLEANUP_e ) then
			  data_reg1 <= (others => '0');
			  data_reg2 <= (others => '0');
			  data_reg3 <= (others => '0');
			  data_reg4 <= (others => '0');
			  icap_tvalid_int <= '0';
		  else
			  data_reg1 <= data_reg1;
			  data_reg2 <= data_reg2;
			  data_reg3 <= data_reg3;
			  data_reg4 <= data_reg4;
			  icap_tvalid_int <= icap_tvalid_int;
	  end if;
  end if;
  end process;

  icap_tdata_o <= data_reg1 when state_reg = INIT_TX_DATA_1_e else
				  data_reg2 when state_reg = INIT_TX_DATA_2_e else
				  data_reg3 when state_reg = INIT_TX_DATA_3_e else
				  data_reg4 when state_reg = INIT_TX_DATA_4_e else
				  (others => '0');

  icap_abort_o <= '1' when  state_reg = INIT_TX_DATA_ERROR_e else '0';

  icap_tvalid_o <= '1' when (state_reg = INIT_TX_DATA_1_e) or
							(state_reg = INIT_TX_DATA_2_e) or
							(state_reg = INIT_TX_DATA_3_e) or
					   		(state_reg = INIT_TX_DATA_4_e) 
						else'0';

end Behavioral;
