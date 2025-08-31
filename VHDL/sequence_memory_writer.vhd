library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


entity sequence_memory_writer is
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
end sequence_memory_writer;

architecture Behavioral of sequence_memory_writer is



type t_SM is (s_Idle, s_Calculate_Parameters, s_Write_To_Memory, s_Set_Counter, s_Cleanup);
signal r_SM_Main: t_SM := s_Idle;


signal r_cnt, r_pulse_end, r_addr_start, r_addr_end : integer range 0 to g_mem_depth - 1;
signal r_win_num, r_win_width, r_pulse_width : natural range 0 to 63;
signal r_ena, r_sequence_start, r_sequence_stop : std_logic;
--signal r_sp_en, r_sd_en, r_lt_en, r_lp_en: std_logic;

signal r_chann_data, r_wr_data : std_logic_vector(7 downto 0);
signal r_wr_addr    : integer range 0 to g_mem_depth-1 := 0;

signal r_sequence_period, r_sequence_delay, r_LD_time, r_LD_pulsewidth : std_logic_vector(7 downto 0);

begin

    o_sequence_start <= r_sequence_start;
    o_sequence_stop  <= r_sequence_stop;

    o_sequence_period <= r_sequence_period;
    o_sequence_delay  <= r_sequence_delay;
    o_LD_time         <= r_LD_time;
    o_LD_pulsewidth   <= r_LD_pulsewidth;
    
    o_wr_en   <= r_ena;
	o_wr_addr <= std_logic_vector(to_unsigned(r_wr_addr, o_wr_addr'length));
	o_wr_data <= r_wr_data;
		
    p_State_Machine : process(i_clk)
    begin
        if rising_edge(i_clk) then

            case r_SM_Main is
                
                when s_Idle =>

                if i_sp_en = '1' then
                    r_sequence_period <= i_sequence_period;
                    r_SM_Main <= s_Cleanup;
                end if;

                if i_sd_en ='1' then
                    r_sequence_delay <= i_sequence_delay;
                    r_SM_Main <= s_Cleanup;
                end if;

                if i_lt_en = '1' then 
                    r_LD_time <= i_LD_time;
                    r_SM_Main <= s_Cleanup;
                end if;
                
                if i_lp_en ='1' then 
                    r_LD_pulsewidth <= i_LD_pulsewidth;
                    r_SM_Main <= s_Cleanup;
                end if;

                if i_sequence_start = '1' then 
                    r_sequence_start <= '1';
                    r_SM_Main <= s_Cleanup;
                end if;

                if i_sequence_stop = '1' then
                    r_sequence_stop <= '1';
                    r_SM_Main <= s_Cleanup; 
                end if;
                
                
                if i_wr_en = '1' then
                    r_win_num     <= to_integer(unsigned(i_window_number)); --window number natural !=0  !
                    r_win_width   <= to_integer(unsigned(i_window_width));
                    r_pulse_width <= to_integer(unsigned(i_pulse_width));
                    r_chann_data  <= i_channels_data;
                    r_SM_Main     <= s_Calculate_Parameters;
                end if;
                
                when s_Calculate_Parameters =>
                    r_addr_start <= r_win_num * r_win_width + r_win_num;
                    r_addr_end   <= (r_win_num + 1) * r_win_width + r_win_num;
                    r_pulse_end	<= (r_win_num * r_win_width) + r_pulse_width + r_win_num;
                    r_SM_Main    <= s_Set_Counter;
                
                when s_Set_Counter => 
                    r_cnt <= r_addr_start;
                    r_SM_Main <= s_Write_To_Memory;
                
                when s_Write_To_Memory =>
                if (r_cnt >= r_addr_start) and (r_cnt <= r_addr_end) then
                    r_ena <= '1';
                    r_wr_addr <= r_cnt;
                    r_cnt <= r_cnt + 1;
                    if (r_cnt <= r_pulse_end) then 
                        r_wr_data <= r_chann_data;
                    else
                        r_wr_data <= (others => '1');
                    end if;
                    r_SM_Main <= s_Write_To_Memory;		
                else
                    r_ena <= '0';
                    r_wr_addr <= 0;
                    r_wr_data <= (others => '1');
                    r_SM_Main <= s_Idle;
                end if;

                when s_Cleanup => 
                    r_sequence_start <= '0';
                    r_sequence_stop  <= '0';
                    r_SM_Main <= s_Idle;
                
                when others => 
                r_SM_Main <= s_Idle;

            end case;
        end if;      

    end process;



end architecture;