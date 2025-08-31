-- This file contains the UART Transmitter.  This transmitter is able
-- to transmit 8 bits of serial data, one start bit, one stop bit,
-- and no parity bit.  When transmit is complete o_TX_Done will be
-- driven high for one clock cycle.
--
-- Set Generic g_CLKS_PER_BIT as follows:
-- g_CLKS_PER_BIT = (Frequency of i_Clk)/(Frequency of UART)
-- Example: 10 MHz Clock, 115200 baud UART
-- (10000000)/(115200) = 87
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity eom_uart_v3_c8m256 is
  generic (
    g_CLKS_PER_BIT : integer := 4340     -- 50 MHz clock and 115200 baud rate 434/50MHz/115200Baud
    );

  port (
    i_Clk           :         in  std_logic;
    i_TX_DV         :         in  std_logic;
    i_TX_Byte       :         in  std_logic_vector(7 downto 0);
    o_RX_DV         :         out std_logic;
    o_RX_Byte       :         out std_logic_vector(7 downto 0);
    o_start_seq     :         out std_logic;
    o_stop_seq      :         out std_logic;
    o_sp_en         :         out std_logic; 
    o_sd_en         :         out std_logic;
    o_lt_en         :         out std_logic;
    o_lp_en         :         out std_logic;
    o_seq_period    :         out std_logic_vector(7 downto 0);
    o_seq_delay     :         out std_logic_vector(7 downto 0);
    o_LD_time       :         out std_logic_vector(7 downto 0);
    o_LD_PW         :         out std_logic_vector(7 downto 0);
    o_wd_wr_en      :         out std_logic;
    o_wd_num        :         out std_logic_vector(7 downto 0);
    o_wd_ww         :         out std_logic_vector(7 downto 0);
    o_wd_pw         :         out std_logic_vector(7 downto 0);
    o_wd_ch         :         out std_logic_vector(7 downto 0)
    );
end eom_uart_v3_c8m256;



architecture behav of eom_uart_v3_c8m256 is

constant c_start_byte       : std_logic_vector := x"55";

constant c_start_sequence   : std_logic_vector := x"41";
constant c_stop_sequence    : std_logic_vector := x"42";

constant c_sequence_period  : std_logic_vector := x"44";
constant c_sequence_delay   : std_logic_vector := x"45";
constant c_LD_pulse_width   : std_logic_vector := x"46";
constant c_LD_start_time    : std_logic_vector := x"47";

constant c_window_data      : std_logic_vector := X"52";
constant c_window_number    : std_logic_vector := x"48";
constant c_window_width     : std_logic_vector := x"49";
constant c_pulse_width      : std_logic_vector := x"50";
constant c_channel_values   : std_logic_vector := x"51";

function checksum8(b0: in std_logic_vector; b1: in std_logic_vector;
                   b2: in std_logic_vector; b3: in std_logic_vector;
                   b4: in std_logic_vector; b5: in std_logic_vector;
                   b6: in std_logic_vector
                  ) return std_logic_vector is

    variable r_checksum: std_logic_vector(7 downto 0) := (others => '0');
    begin
      r_checksum := std_logic_vector((unsigned(b0)+unsigned(b1)+unsigned(b2)+unsigned(b3)+unsigned(b4)+unsigned(b5)+unsigned(b6)) mod 256);
      return r_checksum;
    end function;



type t_SM_Main is (s_Idle, s_Pause, s_Calc_Checksum, s_Send_Checksum, s_Detect_Command, s_Command_ERR, s_Start_Byte, s_Start_Byte_OK, s_Start_Byte_ERR, s_Checksum_OK, s_Checksum_ERR, s_Cleanup, s_OK);
signal r_SM_Main : t_SM_Main := s_Idle;


--Buffer for message from UART PC
type t_Memory_8X8 is array (0 to 7) of std_logic_vector(7 downto 0);
signal r_Msg_Buf : t_Memory_8X8 :=  ( others => (others =>'0'));
signal r_Msg_Buf_Index : integer range 0 to 7 := 0;

signal r_Clk_Count : integer range 0 to 2*g_CLKS_PER_BIT := 0;
signal r_checksum:std_logic_vector(7 downto 0) := (others => '0');
signal r_RX_Data: std_logic_vector(7 downto 0) := (others => '0');
signal r_RX_DV:   std_logic := '0';

signal r_start_seq, r_stop_seq,  r_sp_en, r_sd_en, r_lt_en, r_lp_en : std_logic;
signal r_seq_period, r_seq_delay, r_LD_time, r_LD_PW : std_logic_vector(7 downto 0);


begin

  o_RX_DV   <= r_RX_DV;
  o_RX_Byte <= r_RX_Data;

  o_start_seq <= r_start_seq;
  o_stop_seq  <= r_stop_seq;


  o_sp_en <= r_sp_en;
  o_sd_en <= r_sd_en;
  o_lt_en <= r_lt_en;
  o_lp_en <= r_lp_en;

  o_seq_period <= r_seq_period;
  o_seq_delay  <= r_seq_delay;
  o_LD_time    <= r_LD_time;
  o_LD_PW      <= r_LD_PW;

  p_uart_data_ctrl : process (i_Clk)
  begin
    if rising_edge(i_Clk) then

      case r_SM_Main is

--------Idle state and save the data to Buffer----------------------------------
        when s_Idle =>
          r_RX_DV   <= '0';

          if i_TX_DV = '1' then

            r_Msg_Buf(r_Msg_Buf_Index) <= i_TX_Byte;

              if r_Msg_Buf_Index < 7 then
                r_Msg_Buf_Index <= r_Msg_Buf_Index + 1;
                r_SM_Main <= s_Idle;
              else
                r_checksum <= checksum8(r_Msg_Buf(0), r_Msg_Buf(1), r_Msg_Buf(2), r_Msg_Buf(3), r_Msg_Buf(4), r_Msg_Buf(5), r_Msg_Buf(6));
                r_Msg_Buf_Index <= 0;
                r_SM_Main <= s_Calc_Checksum;
              end if;

          end if;



--------Check the data checksum  first----------------------------------
      when s_Calc_Checksum =>
        if r_Msg_Buf(0) = c_start_byte then
          if r_checksum = r_Msg_Buf(7) then
            r_SM_Main <= s_Checksum_OK;
          else
            r_SM_Main <= s_Checksum_ERR;
          end if;
        else
          r_SM_Main <= s_Start_Byte_ERR;
        end if;

------Send the message to UART--------------------------------------------------

      when s_Checksum_OK =>
         -- r_RX_DV     <= '1';
			 --r_RX_Data   <= x"01";
          r_SM_Main   <= s_Detect_Command;


        when s_Detect_Command =>
          case r_Msg_Buf(1) is

            when c_start_sequence =>
              r_start_seq <= '1';
              r_SM_Main <= s_OK;

            when c_stop_sequence =>
              r_stop_seq <= '1';
              r_SM_Main <= s_OK;

            when c_sequence_period =>
                r_sp_en <= '1';
                r_seq_period <= r_Msg_Buf(2);
                r_SM_Main <= s_OK;
                
            when c_sequence_delay =>
                r_sd_en <= '1';
                r_seq_delay <= r_Msg_Buf(2);
                r_SM_Main <= s_OK;
                
            when c_LD_pulse_width =>
                r_lp_en <= '1';
                r_LD_PW <= r_Msg_Buf(2);
                r_SM_Main <= s_OK;

            when c_LD_start_time =>
                r_lt_en <= '1';
                r_LD_time <= r_Msg_Buf(2);
                r_SM_Main <= s_OK;

            when c_window_data =>
              o_wd_wr_en <= '1';
              o_wd_num <= r_Msg_Buf(2);         
              o_wd_ww  <= r_Msg_Buf(3);  
              o_wd_pw  <= r_Msg_Buf(4);               
              o_wd_ch  <= r_Msg_Buf(5); 
              r_SM_Main <= s_OK;               

            when others => r_SM_Main <= s_Command_ERR;

          end case;


      when s_Start_Byte_ERR =>
        r_RX_DV <= '1';
        r_RX_Data <= x"02";
        r_SM_Main <= s_Cleanup;

      when s_Checksum_ERR =>
        r_RX_DV <= '1';
        r_RX_Data <= x"03";
        r_SM_Main <= s_Cleanup;

      when s_Command_ERR =>
      r_RX_DV <= '1';
      r_RX_Data <= x"04";
      r_SM_Main <= s_Cleanup;

     when s_OK => 
      --o_wd_wr_en <= '0';
        r_RX_DV <= '1';
        r_RX_Data <= x"05";
        r_SM_Main <= s_Cleanup;

------Clean up, stay here for 1 clock-------------------------------------------
      when s_Cleanup =>
        r_RX_DV   <= '0';
        r_start_seq <= '0';
        r_stop_seq <= '0';
        r_sp_en <= '0';
        r_sd_en <= '0';
        r_lt_en <= '0';
        r_lp_en <= '0';
        o_wd_wr_en <= '0';
		  r_SM_Main <= s_Idle;
        --r_seq_period <= '0';
        --r_seq_delay <= '0';
        --r_LD_PW <= '0';
        --r_LD_time <= '0';
        --if r_Clk_Count < 1*g_CLKS_PER_BIT-1 then
          --r_Clk_Count <= r_Clk_Count +1;
          --r_SM_Main <= s_Cleanup;
        --else
          --r_Clk_Count <= 0;
          --r_SM_Main <= s_Idle;
        --end if;
--------------------------------------------------------------------------------
        when others =>
          r_SM_Main <= s_Idle;

      end case;
    end if;


  end process p_uart_data_ctrl;


end behav;
--------------------------COMMENTS----------------------------------------------
--Why device answers with ERR at first sending and then OK ???
