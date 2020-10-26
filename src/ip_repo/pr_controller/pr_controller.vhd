-------------------------------------------------------------------------------
-- Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
-- acting on behalf of its Fraunhofer Institute AISEC.
-- All rights reserved.
-------------------------------------------------------------------------------

----------------------------------------------------------------------------------
--! @file pr_controller.vhd
--! @author Jakob Wittmann
--! @date 3.2.2016
--! @brief Hardware module containing the PR controller's state machine and related
--!        logic descriptions
--
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/02/2016 11:35:13 AM
-- Design Name: 
-- Module Name: pr_controller - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
--              0.01   File Created
--              1.00   Simple ICAP controller for handling 128-bit blocks
-- 2016-11-29   1.10   Added aditional ports to gain more control over the
--                     configuration process. New ports are 'first', 'last', 'rfc'
--                     and 'config'. Changed 'br' port to 'dv' for "data valid".
-- 2017-05-05   2.00   Removed 'mode' FSM and control of decoupler. Changed data
--                     input interface to one 32-bit word instead of four and
--                     adapted the FSM acordingly. The FSM has now only one state
--                     for configuration ("STATE_TRANSPARENT") where all input
--                     data is passed to the output register stage and then to
--                     ICAP.
-- 
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

--! @brief Controlling unit of PR controller AXI IP
entity pr_controller is
   generic(
      counterRegWidth_gen    : integer := 16);
   port(
      --! @name System ports
      reset                   : in std_logic;                      --! resets module, low-active
      clk                     : in std_logic;                      --! clock input

      --! @name Data interface ports
      tdata                   : in std_logic_vector(31 downto 0);  --! data input
      abort                   : in std_logic;                      --! abort signal
      tvalid                  : in std_logic;                      --! input data valid            
      tready                  : out std_logic;                     --! ready to write data to ICAPE

      --! @name CPU signal ports
      status_icap             : out std_logic_vector(3 downto 0);  --! bits [7:4] of 'icap_o' input port
      status_fsm              : out std_logic_vector(7 downto 0);  --! encoded FSM state

      --! ICAPE2 interface ports
      icap_o                  : in std_logic_vector(31 downto 0);  --! ICAPE2 Configuration data output bus
      icap_clk                : out std_logic;                     --! ICAPE2 Clock Input                    
      icap_i                  : out std_logic_vector(31 downto 0); --! ICAPE2 Active-Low ICAP Enable         
      icap_csib               : out std_logic;                     --! ICAPE2 Configuration data input bus  
      icap_rdwrb              : out std_logic);                    --! ICAPE2 Read/Write Select input        
end pr_controller;


--! @brief Architecture definition of the pr_controller
--!
--! This is an abstracted overview of the pr_controller architecture.
--! The logical block \em State \em Machine contains the processes
--!   - fsmInComb_proc()
--!   - fsmOutComb_proc()
--!   - fsmReg_proc()
--!
--! The block \em FSM \em state \em encoder contains the process fsmStateEncoderComb_proc
--! \image html pr_controller_module.svg
--! \image latex pr_controller_module.eps
--!
--! State diagram of the state machine implemented in the processes fsmInComb_proc(), fsmOutComb_proc() and fsmReg_proc()
--! \image html pr_controller_fsm.svg
--! \image latex pr_controller_fsm.eps
architecture Behavioral of pr_controller is

   --################################--
   --###   CONSTANTS DEFINITIONS   ##--
   --################################--

   --#################################--
   --###   COMPONENT DECLARATIONS   ##--
   --#################################--


   --#############################--
   --###    TYPE DEFINITIONS    ##--
   --#############################--

   ------ ctrl fsm ------
   --! State machine's internal state type
   type STATE_TYPE is (STATE_RESET,
                       STATE_TRANSPARENT,
                       STATE_ABORT_INIT0,
                       STATE_ABORT_INIT1,
                       STATE_ABORT_WAIT0,
                       STATE_ABORT_WAIT1,
                       STATE_ABORT_WAIT2,
                       STATE_ABORT_WAIT3);

   --###############################--
   --###    SIGNAL DECLARATION    ##--
   --###############################--

   --! @name Signals driven by process fsmOutComb
   signal fsmOutComb_tready          : std_logic;                       --! tready signal
   signal fsmOutComb_icap_i          : std_logic_vector(31 downto 0);   --! Input data to ICAP2 primitive
   signal fsmOutComb_icap_csib       : std_logic;                       --! CSIB signal to ICAP2 primitive
   signal fsmOutComb_icap_rdwrb      : std_logic;                       --! RDWRB signal to ICAP2 primitive

   --! @name Signals driven by process fsmInComb
   signal fsmInComb_nextState      : STATE_TYPE;   --! State after next positive clock edge

   --! @name Signals driven by process fsmReg
   signal fsmReg_curStateReg       : STATE_TYPE;   --! Current state of state machine

   --! @name Signals driven by process fsmStateEncoderComb
   signal fsmStateEncoderComb_fsmState       : std_logic_vector(7 downto 0);   --! Binary signal corresponding to the state machine's state

   --! @name Signals driven by process icapOutputPipelineReg
   signal icapOutputPipelineReg_icap_i_reg           : std_logic_vector(31 downto 0);  --! Registerd input data signal to ICAPE
   signal icapOutputPipelineReg_icap_csib_reg        : std_logic;   --! Registerd input CSIB signal to ICAPE 
   signal icapOutputPipelineReg_icap_rdwrb_reg       : std_logic;   --! Registerd input RDWRB signal to ICAPE

   --! @name Internal system signals
   signal system_clk                : std_logic;   --! The architectures internal clock signal, driven by port \em reset
   signal system_reset              : std_logic;   --! The architectures internal reset signal, driven by port \em clk

   --! @name Internal signals from input ports
   signal i_tdata               : std_logic_vector(31 downto 0);   --! Signal from data input port \em tdata
   signal i_abort               : std_logic;                       --! Signal from input port \em abort
   signal i_tvalid              : std_logic;                       --! Signal from input port \em tvalid
   signal i_icap_o              : std_logic_vector(31 downto 0);   --! Signal from input port \em icap_o


   -- close last block
   --! @}

begin


   --##################################--
   --###   COMPONENT INSTANTIATION   ##--
   --##################################--


   --#################################--
   --###    PROCESS DEFINITIONS     ##--
   --#################################--
   
   ---------------------------------------------------------------------------------------------------------
   --                                    PROCESS : fsmInComb_proc                                         --
   ---------------------------------------------------------------------------------------------------------
   --! @brief Input combinatorics of the FSM.
   --!
   --! <B>Input Signals:</B>
   --!
   --! Signal              |  Type
   --! ------------------- | ------------
   --! #fsmReg_curStateReg |  #STATE_TYPE
   --! #i_abort            |  std_logic
   --! #i_tvalid           |  std_logic
   --!
   --! <B>Drives Signals:</B>
   --!
   --! Signal                |  Type
   --! --------------------- | ------------------------------
   --! #fsmInComb_nextState  |  #STATE_TYPE
   --!
   --! @dot
   --! digraph finite_state_machine {
   --!     node [shape = oval];
   --!     RESET_STATE -> RESET_STATE [ label = "system_reset = '1'" ]
   --!     RESET_STATE -> STATE_TRANSPARENT [ label = "system_reset = '0'" ] 
   --!     STATE_TRANSPARENT -> STATE_ABORT_INIT0 [ label = "i_abort = '1'" ]
   --!     STATE_ABORT_INIT0 -> STATE_ABORT_INIT1
   --!     STATE_ABORT_INIT1 -> STATE_ABORT_WAIT1
   --!     STATE_ABORT_WAIT1 -> STATE_ABORT_WAIT2
   --!     STATE_ABORT_WAIT2 -> STATE_ABORT_WAIT3
   --!     STATE_ABORT_WAIT3 -> STATE_TRANSPARENT [ label = "i_abort = '0'" ]
   --!     STATE_ABORT_WAIT3 -> STATE_ABORT_WAIT3 [ label = "i_abort = '1'" ]
   --! }
   --! @enddot
   --------------------------------------------------------------------------------------------------------- 
   fsmInComb_proc : process(  fsmReg_curStateReg, 
                              i_abort,
                              i_tvalid)
   begin
      case fsmReg_curStateReg is
         when STATE_RESET =>
            fsmInComb_nextState     <= STATE_TRANSPARENT;

         when STATE_TRANSPARENT =>
            if i_abort = '1' then
               fsmInComb_nextState     <= STATE_ABORT_INIT0;
            else
               -- stay here
               fsmInComb_nextState     <= STATE_TRANSPARENT;
            end if;

         when STATE_ABORT_INIT0 =>
            fsmInComb_nextState     <= STATE_ABORT_INIT1;

         when STATE_ABORT_INIT1 =>
            fsmInComb_nextState     <= STATE_ABORT_WAIT0;

         when STATE_ABORT_WAIT0 =>
            fsmInComb_nextState     <= STATE_ABORT_WAIT1;

         when STATE_ABORT_WAIT1 =>
            fsmInComb_nextState     <= STATE_ABORT_WAIT2;

         when STATE_ABORT_WAIT2 =>
            fsmInComb_nextState     <= STATE_ABORT_WAIT3;

         when STATE_ABORT_WAIT3 =>
            if i_abort = '0' then
               fsmInComb_nextState     <= STATE_TRANSPARENT;
            else
               -- stay here
               fsmInComb_nextState     <= STATE_ABORT_WAIT3;
            end if;

         when others =>
            fsmInComb_nextState     <= STATE_RESET;
      end case;
   end process fsmInComb_proc;


   ---------------------------------------------------------------------------------------------------------
   --                                 PROCESS : fsmOutComb_proc                                           --
   ---------------------------------------------------------------------------------------------------------
   --! @fn fsmOutComb_proc
   --! @brief Output combinatorics of the FSM
   --!
   --! <B>Input Signals:</B>
   --!
   --! Signal                 |  Type
   --! ---------------------- | ------------------------------
   --! #fsmReg_curStateReg    |  #STATE_TYPE
   --! #i_tdata               |  std_logic_vector(31 downto 0)
   --! #i_tvalid              |  std_logic
   --!
   --! <B>Driver Signals:</B>
   --!
   --! Signal                 |  Type
   --! ---------------------- | ------------------------------
   --! #fsmOutComb_tready     | std_logic
   --! #fsmOutComb_icap_i     | std_logic_vector(31 downto 0)
   --! #fsmOutComb_icap_csib  | std_logic
   --! #fsmOutComb_icap_rdwrb | std_logic
   ---------------------------------------------------------------------------------------------------------
   fsmOutComb_proc : process( fsmReg_curStateReg,
                              i_tdata,
                              i_tvalid)


      ---------------------------------------------------------------------------------------------------------
      --                                      FUNCTION : swap_bits                                           --
      ---------------------------------------------------------------------------------------------------------
      --! @brief Swaps bit-order of intput vector
      --!
      --! Swaps bit-order of ICAPE_2's input-data and reverses byte-order (reverses bit-order of complete
      --! vector). See UG470, p. 79 "Bit Swapping" and DPR Lab#5 source file "icap_top.v", line 31
      --!
      --!     Input:     word [31 ...  0]
      --!                      \       /
      --!                        \   /
      --!                          |
      --!                        /   \
      --!                      /       \
      --!     Output: swapped [ 0 ... 31]
      --!
      --! @param word                         : std_logic_vector(31 downto 0);
      --!
      --! @return swapped                      : std_logic_vector(31 downto 0);
      ---------------------------------------------------------------------------------------------------------
      function swap_bits(word : std_logic_vector) return std_logic_vector is
   
         variable swapped : std_logic_vector(31 downto 0);
      
      begin
      
         swapped(7) := word(24);
         swapped(6) := word(25);
         swapped(5) := word(26);
         swapped(4) := word(27);
         swapped(3) := word(28);
         swapped(2) := word(29);
         swapped(1) := word(30);
         swapped(0) := word(31);
   
         swapped(15) := word(16);
         swapped(14) := word(17);
         swapped(13) := word(18);
         swapped(12) := word(19);
         swapped(11) := word(20);
         swapped(10) := word(21);
         swapped(9)  := word(22);
         swapped(8)  := word(23);
   
         swapped(23) := word(8); 
         swapped(22) := word(9); 
         swapped(21) := word(10);
         swapped(20) := word(11);
         swapped(19) := word(12);
         swapped(18) := word(13);
         swapped(17) := word(14);
         swapped(16) := word(15);
   
         swapped(31) := word(0);
         swapped(30) := word(1);
         swapped(29) := word(2);
         swapped(28) := word(3);
         swapped(27) := word(4);
         swapped(26) := word(5);
         swapped(25) := word(6);
         swapped(24) := word(7);
         
         return swapped;
   
      end swap_bits;
      
   begin
      case fsmReg_curStateReg is
         when STATE_RESET =>
            fsmOutComb_tready                    <= '0';
            fsmOutComb_icap_i                    <= (others=>'0');
            fsmOutComb_icap_csib                 <= '1';
            fsmOutComb_icap_rdwrb                <= '0';
            
         when STATE_TRANSPARENT =>
            fsmOutComb_tready                    <= '1';
            fsmOutComb_icap_i                    <= swap_bits(i_tdata);
            fsmOutComb_icap_csib                 <= not i_tvalid;
            fsmOutComb_icap_rdwrb                <= '0';
            
         when STATE_ABORT_INIT0 =>
            fsmOutComb_tready                    <= '0';
            fsmOutComb_icap_i                    <= (others=>'0');
            fsmOutComb_icap_csib                 <= '0';
            fsmOutComb_icap_rdwrb                <= '0';
                        
         when STATE_ABORT_INIT1 =>
            fsmOutComb_tready                    <= '0';
            fsmOutComb_icap_i                    <= (others=>'0');
            fsmOutComb_icap_csib                 <= '0';
            fsmOutComb_icap_rdwrb                <= '1';
                        
         when STATE_ABORT_WAIT0 =>
            fsmOutComb_tready                    <= '0';
            fsmOutComb_icap_i                    <= (others=>'0');
            fsmOutComb_icap_csib                 <= '1';
            fsmOutComb_icap_rdwrb                <= '0';
         
         when STATE_ABORT_WAIT1 =>
            fsmOutComb_tready                    <= '0';
            fsmOutComb_icap_i                    <= (others=>'0');
            fsmOutComb_icap_csib                 <= '1';
            fsmOutComb_icap_rdwrb                <= '0';
         
         when STATE_ABORT_WAIT2 =>
            fsmOutComb_tready                    <= '0';
            fsmOutComb_icap_i                    <= (others=>'0');
            fsmOutComb_icap_csib                 <= '1';
            fsmOutComb_icap_rdwrb                <= '0';
         
         when STATE_ABORT_WAIT3 =>
            fsmOutComb_tready                    <= '0';
            fsmOutComb_icap_i                    <= (others=>'0');
            fsmOutComb_icap_csib                 <= '1';
            fsmOutComb_icap_rdwrb                <= '0';
         
         when others =>
            fsmOutComb_tready                    <= '0';
            fsmOutComb_icap_i                    <= (others=>'0');
            fsmOutComb_icap_csib                 <= '1';
            fsmOutComb_icap_rdwrb                <= '0';

      end case;
   end process fsmOutComb_proc;

   ---------------------------------------------------------------------------------------------------------
   --                                         PROCESS : fsmReg                                            --
   ---------------------------------------------------------------------------------------------------------
   --! @brief Register process of the FSM.
   --!
   --! <B>Input Signals:</B>
   --!
   --! Signal                 |  Type
   --! ---------------------- | ------------------------------
   --! #system_reset          | std_logic
   --! #system_clk            | std_logic
   --! #fsmInComb_nextState   | #STATE_TYPE
   --!
   --! <B>Driver Signals:</B>
   --!
   --! Signal                 |  Type
   --! ---------------------- | ------------------------------
   --! #fsmReg_curStateReg    | #STATE_TYPE
   ---------------------------------------------------------------------------------------------------------
   fsmReg_proc : process(  system_reset, 
                           system_clk, 
                           fsmInComb_nextState)
   begin
      if rising_edge(system_clk) then
         if system_reset = '0' then
            fsmReg_curStateReg <= STATE_RESET;
         else
            fsmReg_curStateReg <= fsmInComb_nextState;
         end if;
      end if;
   end process fsmReg_proc;
	
   ---------------------------------------------------------------------------------------------------------
   --                               icapOutputPipelineReg_proc : PROCESS                                  --
   ---------------------------------------------------------------------------------------------------------
   --! @brief Output registers
   --!
   --! All outputs to ICAP interface are registered before the are passed to ICAP (one state pipeline)
   --!
   --! <B>Input Signals:</B>
   --!
   --! Signal                 |  Type
   --! ---------------------- | ------------------------------
   --! #system_clk            | std_logic
   --! #system_reset          | std_logic
   --! #fsmOutComb_icap_i     | std_logic_vector(31 downto 0)
   --! #fsmOutComb_icap_csib  | std_logic
   --! #fsmOutComb_icap_rdwrb | std_logic
   --!
   --! <B>Driver Signals:</B>
   --!
   --! Signal                                | Type
   --! ------------------------------------- | --------------------------------------------------
   --! #icapOutputPipelineReg_icap_i_reg     | std_logic_vector(31 downto 0)
   --! #icapOutputPipelineReg_icap_csib_reg  | std_logic
   --! #icapOutputPipelineReg_icap_rdwrb_reg | std_logic
   ---------------------------------------------------------------------------------------------------------
   icapOutputPipelineReg_proc : process(system_clk,
                                        system_reset,
                                        fsmOutComb_icap_i,
                                        fsmOutComb_icap_csib,
                                        fsmOutComb_icap_rdwrb)
   begin
   
      if rising_edge(system_clk) then
         if system_reset = '0' then
            icapOutputPipelineReg_icap_i_reg      <= (others=>'0');
            icapOutputPipelineReg_icap_csib_reg   <= '1'; -- ICAP: ignore input from ICAP controller
            icapOutputPipelineReg_icap_rdwrb_reg  <= '0';
         else
            icapOutputPipelineReg_icap_i_reg      <= fsmOutComb_icap_i;
            icapOutputPipelineReg_icap_csib_reg   <= fsmOutComb_icap_csib;
            icapOutputPipelineReg_icap_rdwrb_reg  <= fsmOutComb_icap_rdwrb;
         end if;
      else
         null;
      end if;
   
   end process icapOutputPipelineReg_proc;
   
   
   
   


   ---------------------------------------------------------------------------------------------------------
   --                               PROCESS : fsmStateEncoderComb_proc                                    --
   ---------------------------------------------------------------------------------------------------------
   --! @brief Encodes the state of the fsm to a 8 bit unsigned integer.
   --!
   --! <B>Input Signals:</B>
   --!
   --! Signal                 |  Type
   --! ---------------------- | -----------
   --! #fsmReg_curStateReg    | #STATE_TYPE
   --!
   --! <B>Driver Signals:</B>
   --!
   --! Signal                         |  Type
   --! ------------------------------ | ------------------------------
   --! #fsmStateEncoderComb_fsmState  | std_logic_vector(7 downto 0);
   ---------------------------------------------------------------------------------------------------------
   fsmStateEncoderComb_proc : process(fsmReg_curStateReg)
   begin
      case fsmReg_curStateReg is
         when STATE_RESET =>
            fsmStateEncoderComb_fsmState <= std_logic_vector(to_unsigned(1, 8));
            
         when STATE_TRANSPARENT =>
            fsmStateEncoderComb_fsmState <= std_logic_vector(to_unsigned(2, 8));
            
         when STATE_ABORT_INIT0 =>
            fsmStateEncoderComb_fsmState <= std_logic_vector(to_unsigned(9, 8));
            
         when STATE_ABORT_INIT1 =>
            fsmStateEncoderComb_fsmState <= std_logic_vector(to_unsigned(10, 8));
            
         when STATE_ABORT_WAIT0 =>
            fsmStateEncoderComb_fsmState <= std_logic_vector(to_unsigned(11, 8));
            
         when STATE_ABORT_WAIT1 =>
            fsmStateEncoderComb_fsmState <= std_logic_vector(to_unsigned(12, 8));
         
         when STATE_ABORT_WAIT2 =>
            fsmStateEncoderComb_fsmState <= std_logic_vector(to_unsigned(13, 8));
         
         when STATE_ABORT_WAIT3 =>
            fsmStateEncoderComb_fsmState <= std_logic_vector(to_unsigned(14, 8));
         
         when others =>
            fsmStateEncoderComb_fsmState <= std_logic_vector(to_unsigned(0, 8));

      end case;
   end process fsmStateEncoderComb_proc;
   
   --################################--
   --###   PARALLEL ASSIGNEMENTS   ##--
   --################################--
      
   ------ system ------
   system_clk      <= clk;
   system_reset    <= reset;
	
   ------ input ------
   i_tdata         <= tdata;
   i_abort         <= abort;
   i_tvalid        <= tvalid;
   i_icap_o        <= icap_o;
	
   ------ output ------
   icap_clk    <= system_clk;
   icap_i      <= icapOutputPipelineReg_icap_i_reg;
   icap_csib   <= icapOutputPipelineReg_icap_csib_reg;
   icap_rdwrb  <= icapOutputPipelineReg_icap_rdwrb_reg;
   tready      <= fsmOutComb_tready;
   status_icap <= i_icap_o(7 downto 4);
   status_fsm  <= fsmStateEncoderComb_fsmState;
	

end Behavioral;
