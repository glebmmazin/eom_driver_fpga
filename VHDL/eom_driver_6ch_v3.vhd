library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

entity eom_driver_6ch_v3 is
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
        i_d_data             : in std_logic_vector(g_num_of_channels-1 downto 0); 
        o_trig               : out std_logic;
        o_LD                 : out std_logic;
        o_ch                 : out std_logic_vector(g_num_of_channels-1 downto 0);
        o_ena                : out std_logic
  );
end entity;


architecture behav of eom_driver_6ch_v3 is
--------------------------------------------------------------------------------
constant c_max_period   :   natural := 66_666; --66_666 = 200 us for 300 MHz clk
constant c_min_period   :   natural := 6_666; --6_6666 = 20 us for 300 MHz clk
constant c_trig_edge    :   natural := 10;
constant c_trig_width   :   natural := 3; 
constant c_drive_HI     :   std_logic_vector(g_num_of_channels-1 downto 0) := (others => '1');

type t_seq_mem is array (0 to g_mem_depth-1) of std_logic_vector(g_num_of_channels-1 downto 0);

signal r_mem: t_seq_mem := ( 0 to 8   => "00000000",
                             9 to 17  => "11111111",
                            18 to 26  => "11110110",
                            27 to 35  => "11111111",
                            36 to 44  => "11101101",
                            45 to 53  => "11111111",
                            54 to 62 =>  "11011011",
                               others => "11111111" );                              

signal a0, a1 , b0, b1, c0, c1, d0, d1 : std_logic_vector(7 downto 0) := (others => '0');
signal xa, xb, xc, xd : std_logic := '0';

signal r_init_seq   : std_logic  := '0';
signal r_seq_start  : std_logic  := '0';

signal r_LD         : std_logic := '0';
signal r_trig       : std_logic := '0';
signal r_enable     : std_logic := '0';

signal r_seq_period : natural  := 33_333; -- 33_333 = 100 us for 300 MHz clk
signal r_seq_delay  : natural  := 10;
signal r_LD_edge    : natural  := 18;
signal r_LD_width   : natural  := 2;

signal r_time_cnt   : natural range 0 to (c_max_period - g_mem_depth - 1) := 0;
signal mem_index    : natural range 0 to g_mem_depth - 1  := 0;
signal r_channs     : std_logic_vector(g_num_of_channels-1 downto 0);


--------------------------------------------------------------------------------
begin
-------------------------------------------------------------------------------
p_write_data: process(i_clk)
begin 
    if rising_edge(i_clk) then

      a0 <= i_d_seq_period;
      a1 <= a0;

      b0 <= i_d_seq_delay;
      b1 <= b0;

      c0 <= i_d_LD_start;
      c1 <= c0;

      d0 <= i_d_LD_width;
      d1 <= d0;
        
      xa <= or_reduce( a0 xor a1);
      xb <= or_reduce( b0 xor b1);
      xc <= or_reduce( c0 xor c1);
      xd <= or_reduce( d0 xor d1);

      if xa = '1' then
        r_seq_period <= to_integer(unsigned(i_d_seq_period))*(1000/3);
      end if;
      
      if r_seq_period < c_min_period then 
        r_seq_period <= c_min_period;
      end if;

      if xb = '1' then
        r_seq_delay <= to_integer(unsigned(i_d_seq_delay));
      end if;

      if xc = '1' then
        r_LD_edge <=  to_integer(unsigned(i_d_LD_start));
        end if;

      if xd = '1' then
        r_LD_width <= to_integer(unsigned(i_d_LD_width));
      end if;
           
      if i_d_start_seq = '1' then
          r_init_seq  <= '1';
      end if;

      if i_d_stop_seq = '1' then 
          r_init_seq <= '0';
      end if;
      

      if i_d_wr_en = '1' then
        r_mem(to_integer(unsigned(i_d_addr))) <= i_d_data;
      end if;

    end if;


end process p_write_data;



------------------------------------------------------------------------------------------


p_generate_outputs: process(i_clk, r_init_seq)
begin

  if r_init_seq = '0' then
     mem_index <= 0;
     r_time_cnt <= 0;
     r_seq_start <= '0';
     r_trig <= '0';
     r_LD <= '0';
     r_channs <= c_drive_HI;
     r_enable <= '0';
   else
     r_enable <= '1';
     if rising_edge(i_clk) then

         if (r_time_cnt >= c_trig_edge) and (r_time_cnt <= c_trig_edge + c_trig_width) then
           r_trig <= '1';
         else
           r_trig <= '0';
         end if;

         if (r_time_cnt >= c_trig_edge + r_LD_edge)  and (r_time_cnt <= c_trig_edge + r_LD_edge + r_LD_width) then
           r_LD <= '1';
         else
           r_LD <= '0';
         end if;

         if r_time_cnt = r_seq_period-1 then
           r_time_cnt <= 0;
         else
           r_time_cnt <= r_time_cnt + 1;
         end if;

         if r_time_cnt = c_trig_edge + r_seq_delay then
           r_seq_start <= '1';
         end if;

         if r_time_cnt = (c_trig_edge + r_seq_delay + g_mem_depth - 1) then --add here cut of sequence???
           r_seq_start <= '0';
         end if;

         if r_seq_start = '1' then
           if mem_index = g_mem_depth - 1 then
             mem_index <= 0;
           else
             mem_index <= mem_index + 1;
           end if;
           r_channs <= r_mem(mem_index); -- <= not r_mem(mem_index)
         else
           mem_index <= 0;
           r_channs <= c_drive_HI;
         end if;

    end if;

  end if;

   
   o_trig <= r_trig;
   o_LD   <= r_LD;
   o_ena  <= not r_enable;
   o_ch   <= r_channs;

end process;


end architecture;
