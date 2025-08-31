library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

-- Window byte is 8 bits, channels byte is 6 - error! 

entity eom_v3_two_clocks_top is
    port (
        i_clk_50MHz         :    in  std_logic;
        i_clk_300MHz        :    in  std_logic;
        i_RXD               :    in  std_logic;
        o_TXD               :    out std_logic;
        o_TX_Active         :    out std_logic;
        o_TX_Done           :    out std_logic;
        o_trigger           :    out std_logic;
        o_LD_drive          :    out std_logic;
        o_channels_enable   :    out std_logic;
        o_eom_channels      :    out std_logic_vector(7 downto 0)
    );
end eom_v3_two_clocks_top;

architecture Behavioral of eom_v3_two_clocks_top is

    component UART_TX is
        generic (
            g_CLKS_PER_BIT : integer := 434     -- 50 MHz clock and 115200 baud rate
            );
        port (
            i_Clk       : in  std_logic;
            i_TX_DV     : in  std_logic;
            i_TX_Byte   : in  std_logic_vector(7 downto 0);
            o_TX_Active : out std_logic;
            o_TX_Serial : out std_logic;
            o_TX_Done   : out std_logic
            );
    end component;

    component UART_RX is
        generic (
            g_CLKS_PER_BIT : integer := 434     --  for 50 MHz clock and 115200 baud rate
            );
        port (
            i_Clk       : in  std_logic;
            i_RX_Serial : in  std_logic;
            o_RX_DV     : out std_logic;
            o_RX_Byte   : out std_logic_vector(7 downto 0)
            );
    end component;

    component eom_uart_v3_c8m256 is
        generic (
          g_CLKS_PER_BIT : integer := 434     -- 500 MHz clock and 115200 baud rate
          );
        port (
          i_clk           :         in  std_logic;
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
      end component;

    component sequence_memory_writer is
        generic(
            g_mem_depth: natural := 1024  
            );
        port (
            i_clk               : in std_logic;
            i_sequence_start    : in std_logic;
            i_sequence_stop     : in std_logic;
            i_sp_en             : in std_logic;
            i_sd_en             : in std_logic;
            i_lt_en             : in std_logic;
            i_lp_en             : in std_logic;
            i_sequence_period   : in std_logic_vector(7 downto 0); 
            i_sequence_delay    : in std_logic_vector(7 downto 0);
            i_LD_time           : in std_logic_vector(7 downto 0);
            i_LD_pulsewidth     : in std_logic_vector(7 downto 0);
            i_wr_en             : in std_logic;
            i_window_number     : in std_logic_vector(7 downto 0);
            i_window_width      : in std_logic_vector(7 downto 0);
            i_pulse_width       : in std_logic_vector(7 downto 0);
            i_channels_data     : in std_logic_vector(7 downto 0);
            o_sequence_start    : out std_logic;
            o_sequence_stop     : out std_logic;
            o_sequence_period   : out std_logic_vector(7 downto 0);
            o_sequence_delay    : out std_logic_vector(7 downto 0);
            o_LD_time           : out std_logic_vector(7 downto 0);
            o_LD_pulsewidth     : out std_logic_vector(7 downto 0);
            o_wr_en             : out std_logic;
            o_wr_addr           : out std_logic_vector(g_mem_depth-1 downto 0);
            o_wr_data           : out std_logic_vector(7 downto 0) 
            );
    end component;

    component eom_driver_6ch_v3 is
        generic(
              g_mem_depth: natural := 1024;
              g_num_of_channels: natural := 8
        );
        port (
              i_clk                : in std_logic;
              i_d_start_seq        : in std_logic;
              i_d_stop_seq         : in std_logic;
              i_d_seq_period       : in std_logic_vector(7 downto 0);
              i_d_seq_delay        : in std_logic_vector(7 downto 0);
              i_d_LD_start         : in std_logic_vector(7 downto 0);
              i_d_LD_width         : in std_logic_vector(7 downto 0);
              i_d_wr_en            : in std_logic;
              i_d_addr             : in std_logic_vector(g_mem_depth-1 downto 0);
              i_d_data             : in std_logic_vector(7 downto 0); 
              o_trig               : out std_logic;
              o_LD                 : out std_logic;
              o_ch                 : out std_logic_vector(7 downto 0);
              o_ena                : out std_logic
        );
      end component;


    constant c_clks_per_bit :   integer := 434;
    constant c_mem_depth    :   natural := 1024;

    signal w_RX_DV, w_TX_DV        :   std_logic;
    signal w_RX_Byte, w_TX_Byte    :   std_logic_vector(7 downto 0);

    signal w_start_seq, w_stop_seq    :   std_logic;
    signal w_sp_en, w_sd_en, w_lt_en, w_lp_en      :   std_logic;
    signal w_seq_period, w_seq_delay, w_LD_time, w_LD_PW    :   std_logic_vector(7 downto 0);
    signal w_wd_num, w_wd_ww, w_wd_pw  :   std_logic_vector(7 downto 0);

    signal w_d_start_seq, w_d_stop_seq   :   std_logic;
    signal w_d_seq_period, w_d_seq_delay, w_d_LD_start, w_d_LD_width : std_logic_vector(7 downto 0);
    
    signal w_d_wr_en, w_wd_wr_en    :   std_logic;
    signal w_d_addr     :   std_logic_vector(c_mem_depth-1 downto 0); 
    signal w_d_data, w_wd_ch     :   std_logic_vector(7 downto 0);

begin


    UART_RX_component : UART_RX
        generic map(
            g_CLKS_PER_BIT => c_clks_per_bit
        )
        port map(
            i_clk       =>  i_clk_50MHz,
            i_RX_Serial =>  i_RXD,
            o_RX_DV     =>  w_RX_DV,
            o_RX_Byte   =>  w_RX_Byte
        );

    UART_TX_component : UART_TX
        generic map(
            g_CLKS_PER_BIT => c_clks_per_bit

        )
        port map(
            i_clk       =>  i_clk_50MHz,
            i_TX_DV     =>  w_TX_DV,
            i_TX_Byte   =>  w_TX_Byte,
            o_TX_Active =>  o_TX_Active,
            o_TX_Serial =>  o_TXD,
            o_TX_Done   =>  o_TX_Done
            
        );

    eom_uart_v3_c8m256_component : eom_uart_v3_c8m256
        generic map(
            g_CLKS_PER_BIT => c_clks_per_bit
        )
        port map(
            i_clk           =>  i_clk_50MHz,
            i_TX_DV         =>  w_RX_DV,
            i_TX_Byte       =>  w_RX_Byte,
            o_RX_DV         =>  w_TX_DV,
            o_RX_Byte       =>  w_TX_Byte,
            o_start_seq     =>  w_start_seq,     
            o_stop_seq      =>  w_stop_seq,
            o_sp_en         =>  w_sp_en,
            o_sd_en         =>  w_sd_en,
            o_lt_en         =>  w_lt_en,
            o_lp_en         =>  w_lp_en,
            o_seq_period    =>  w_seq_period,
            o_seq_delay     =>  w_seq_delay,
            o_LD_time       =>  w_LD_time,
            o_LD_PW         =>  w_LD_PW,
            o_wd_wr_en      =>  w_wd_wr_en,
            o_wd_num        =>  w_wd_num,
            o_wd_ww         =>  w_wd_ww,
            o_wd_pw         =>  w_wd_pw,
            o_wd_ch         =>  w_wd_ch

        );

    sequence_memory_writer_component : sequence_memory_writer
            generic map (
            g_mem_depth =>  c_mem_depth
            )
        port map(
            i_clk               =>  i_clk_300MHz,
            i_sequence_start    =>  w_start_seq,  
            i_sequence_stop     =>  w_stop_seq,
            i_sp_en             =>  w_sp_en,
            i_sd_en             =>  w_sd_en,
            i_lt_en             =>  w_lt_en,
            i_lp_en             =>  w_lp_en,
            i_sequence_period   =>  w_seq_period,
            i_sequence_delay    =>  w_seq_delay,
            i_LD_time           =>  w_LD_time,
            i_LD_pulsewidth     =>  w_LD_PW,
            i_wr_en             =>  w_wd_wr_en,
            i_window_number     =>  w_wd_num,
            i_window_width      =>  w_wd_ww,
            i_pulse_width       =>  w_wd_pw,
            i_channels_data     =>  w_wd_ch,
            o_sequence_start    =>  w_d_start_seq,
            o_sequence_stop     =>  w_d_stop_seq,
            o_sequence_period   =>  w_d_seq_period,
            o_sequence_delay    =>  w_d_seq_delay,
            o_LD_time           =>  w_d_LD_start,
            o_LD_pulsewidth     =>  w_d_LD_width,
            o_wr_en             =>  w_d_wr_en,   
            o_wr_addr           =>  w_d_addr,
            o_wr_data           =>  w_d_data
            
        );

    eom_driver_6ch_v3_component : eom_driver_6ch_v3
            generic map(
              g_mem_depth   => c_mem_depth
        )
        port map(
              i_clk                =>   i_clk_300MHz,
              i_d_start_seq        =>   w_d_start_seq,
              i_d_stop_seq         =>   w_d_stop_seq,
              i_d_seq_period       =>   w_d_seq_period,
              i_d_seq_delay        =>   w_d_seq_delay,
              i_d_LD_start         =>   w_d_LD_start,
              i_d_LD_width         =>   w_d_LD_width,
              i_d_wr_en            =>   w_d_wr_en,
              i_d_addr             =>   w_d_addr,
              i_d_data             =>   w_d_data,
              o_trig               =>   o_trigger,      
              o_LD                 =>   o_LD_drive,
              o_ch                 =>   o_eom_channels,
              o_ena                =>   o_channels_enable
        );


end architecture;