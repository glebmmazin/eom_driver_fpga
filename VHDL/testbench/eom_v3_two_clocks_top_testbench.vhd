library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

entity eom_v3_two_clocks_top_testbench is
end eom_v3_two_clocks_top_testbench ;

architecture testbench of eom_v3_two_clocks_top_testbench is
    component eom_v3_two_clocks_top is
        port (
            i_clk_50MHz         :    in  std_logic;
            i_clk_300MHz        :    in  std_logic;
            i_RXD               :    in std_logic;
            o_TXD               :    out std_logic;
            o_TX_Active         :    out std_logic;
            o_TX_Done           :    out std_logic;
            o_trigger           :    out std_logic;
            o_LD_drive          :    out std_logic;
            o_channels_enable   :    out std_logic;
            o_eom_channels      :    out std_logic_vector(7 downto 0)
        );
    end component;

    type t_PACKET is array (0 to 7) of std_logic_vector(7 downto 0);
    signal r_packet : t_packet;
    constant c_clk_period : time := 3.3 ns;
    constant c_clk_50_MHz : time := 20 ns;
    constant c_bit_period : time := 4340*2 ns;

    constant c_start_byte       : std_logic_vector := x"55";
    constant c_start_sequence   : std_logic_vector := x"41";
    constant c_stop_sequence    : std_logic_vector := x"42";
    constant c_clear_sequence   : std_logic_vector := x"43";
    constant c_sequence_period  : std_logic_vector := x"44";
    constant c_sequence_delay   : std_logic_vector := x"45";
    constant c_LD_pulse_width   : std_logic_vector := x"46";
    constant c_LD_start_time    : std_logic_vector := x"47";

 
    constant c_window_number    : std_logic_vector := x"48";
    constant c_window_width     : std_logic_vector := x"49";
    constant c_pulse_width      : std_logic_vector := x"50";
    constant c_channel_values   : std_logic_vector := x"51";
    constant c_window_data      : std_logic_vector := X"52";

    signal w_clk :  std_logic := '0';
    signal w_clk_50MHz : std_logic := '0';
    
    signal w_RXD :  std_logic := '1';
    signal w_TXD, w_TX_Active, w_TX_Done :  std_logic;

    signal w_trigger, w_LD_drive, w_channels_enable  : std_logic;
    signal w_eom_channels : std_logic_vector(7 downto 0);

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

     -- Low-level byte-write
    procedure UART_WRITE_BYTE (
        i_data_in       : in  std_logic_vector(7 downto 0);
        signal o_serial : out std_logic) is
    begin
    
        -- Send Start Bit
        o_serial <= '0';
        wait for c_bit_period;
    
        -- Send Data Byte
        for ii in 0 to 7 loop
        o_serial <= i_data_in(ii);
        wait for c_bit_period;
        end loop;  -- ii
    
        -- Send Stop Bit
        o_serial <= '1'; wait for c_bit_period; 
    end UART_WRITE_BYTE; 



    procedure UART_WRITE_PACKET (
        i_PACKET : t_PACKET;
        signal o_Byte_serial : out std_logic ) is 
    begin 
        for ii in 0 to 7 loop        
            UART_WRITE_BYTE(i_PACKET(ii), o_Byte_serial);
            wait for c_bit_period;
        end loop;

    end UART_WRITE_PACKET;
        

        procedure UART_WRITE_MESSAGE(i_command, i_data_1, i_data_2, i_data_3, i_data_4, i_data_5 : in std_logic_vector(7 downto 0);
                                     signal o_Byte_serial : out std_logic ) is
        
        begin            
            UART_WRITE_BYTE(c_start_byte, o_Byte_serial);
            wait for c_bit_period;

            UART_WRITE_BYTE(i_command, o_Byte_serial);
            wait for c_bit_period;

            UART_WRITE_BYTE(i_data_1, o_Byte_serial);
            wait for c_bit_period;

            UART_WRITE_BYTE(i_data_2, o_Byte_serial);
            wait for c_bit_period;

            UART_WRITE_BYTE(i_data_3, o_Byte_serial);
            wait for c_bit_period;

            UART_WRITE_BYTE(i_data_4, o_Byte_serial);
            wait for c_bit_period;

            UART_WRITE_BYTE(i_data_5, o_Byte_serial);
            wait for c_bit_period;
            
            UART_WRITE_BYTE(checksum8(c_start_byte, i_command, i_data_1, i_data_2, i_data_3, i_data_4, i_data_5), o_Byte_serial);
            wait for c_bit_period;
            
        end procedure;

begin

    UUT : eom_v3_two_clocks_top
    port map(
            i_clk_50MHz         => w_clk_50MHz,
            i_clk_300MHz        => w_clk,
            i_RXD               => w_RXD,   
            o_TXD               => w_TXD, 
            o_TX_Active         => w_TX_Active,
            o_TX_Done           => w_TX_Done,
            o_trigger           => w_trigger,
            o_LD_drive          => w_LD_drive,
            o_channels_enable   => w_channels_enable,
            o_eom_channels      => w_eom_channels
    );


    p_clk_300_MHz : process is
    begin 
        wait for c_clk_period/2;
        w_clk <= not w_clk; 
    end process;

    p_clk_50_MHz : process is
    begin 
        wait for c_clk_50_MHz/2;
        w_clk_50MHz <= not w_clk_50MHz; 
    end process;

    p_uart_data: process is
    begin 
		
		--start sequence
        wait until rising_edge(w_clk_50MHz);
        UART_WRITE_MESSAGE(c_start_sequence, X"00", X"00", X"00", X"00", X"00",  w_RXD);

		--window 0
		UART_WRITE_MESSAGE(c_window_data, X"00", X"15", X"05", X"01", X"00",  w_RXD);
		wait until rising_edge(w_clk_50MHz);
		--window 1
		UART_WRITE_MESSAGE(c_window_data, X"01", X"15", X"05", X"02", X"00",  w_RXD);					
		wait until rising_edge(w_clk_50MHz);
		--window 2
		UART_WRITE_MESSAGE(c_window_data, X"02", X"15", X"05", X"03", X"00",  w_RXD);					
		wait until rising_edge(w_clk_50MHz);		
		--window 3
		UART_WRITE_MESSAGE(c_window_data, X"03", X"15", X"05", X"04", X"00",  w_RXD);					
		wait until rising_edge(w_clk_50MHz);		
		--window 4
		UART_WRITE_MESSAGE(c_window_data, X"04", X"15", X"05", X"05", X"00",  w_RXD);					
		wait until rising_edge(w_clk_50MHz);
		--window 5
		UART_WRITE_MESSAGE(c_window_data, X"05", X"15", X"05", X"06", X"00",  w_RXD);					
		wait until rising_edge(w_clk_50MHz);
		--window 6
		UART_WRITE_MESSAGE(c_window_data, X"06", X"15", X"05", X"07", X"00",  w_RXD);					
		wait until rising_edge(w_clk_50MHz);
		--window 7
		UART_WRITE_MESSAGE(c_window_data, X"07", X"15", X"05", X"08", X"00",  w_RXD);					
		wait until rising_edge(w_clk_50MHz);
		--window 8
		UART_WRITE_MESSAGE(c_window_data, X"08", X"15", X"05", X"09", X"00",  w_RXD);					
		wait until rising_edge(w_clk_50MHz);		
		--window 9
		UART_WRITE_MESSAGE(c_window_data, X"09", X"15", X"05", X"0A", X"00",  w_RXD);					
		wait until rising_edge(w_clk_50MHz);

		wait for 200 us;
		--stop sequence
        UART_WRITE_MESSAGE(c_stop_sequence, X"00", X"00", X"00", X"00", X"00",  w_RXD);

        wait for 200 us;

        --wait until rising_edge(w_clk_50MHz);
        --UART_WRITE_MESSAGE(c_sequence_period, X"05", X"1E", X"0F", X"33", X"00",  w_RXD);
        --wait until rising_edge(w_clk_50MHz);
        --UART_WRITE_MESSAGE(c_sequence_period, X"09", X"1E", X"0F", X"33", X"00",  w_RXD);
        --wait for 200 us;




    end process;





end architecture ; 

