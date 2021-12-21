----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/04/2020 03:16:42 PM
-- Design Name: 
-- Module Name: TC_statemachine_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
-- Testbench for the ctp readout state machine.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_misc.ALL;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;
--use std.env.all;


-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity IR_tb is
--  Port ( );
end IR_tb;

architecture Behavioral of IR_tb is
	--constant period		: time : (1 us/ 240);
	signal CLK_0 	     	: std_logic := '1';
	signal reset_s	    	: std_logic := '0';
	signal clk_en_s		    : std_logic;
	signal start_command    : std_logic := '0';
	signal data_sel_s	    : std_logic := '0';
	signal data_s		    : std_logic_vector( 67 downto 0) := (others => '0');
--	signal data_s		    : std_logic_vector( 67 downto 0);
	signal bc_number_s     	: std_logic_vector( 11 downto 0) := (others => '0');
	signal generated_orbit	: std_logic_vector( 31 downto 0) := (others => '0');
	signal trigger_string	: std_logic_vector(119 downto 0) := (others => '0');
	signal gbt_connection	: std_logic_vector( 79 downto 0) := (others => '0');
	signal gbt_rx_s		    : std_logic_vector( 79 downto 0) := (others => '0');
	signal gbt_flag_s      	: std_logic := '0';
	signal starting_flag    : std_logic := '0';
	file   out_file         : text open write_mode is "output.txt";
    file   in_file          : text;
    signal s_state_num      : std_logic_vector(31 downto 0);
    signal s_state_num_1    : std_logic_vector(3  downto 0);

    signal sn_i             : std_logic_vector( 7 downto 0) := "00010001";
--    signal threshold        : std_logic_vector(31 downto 0) := (30 => '1', others => '1');
    signal threshold        : std_logic_vector(31 downto 0) := (30 => '0', others => '0');


	
component top_ir_statemachine is
  generic (
    g_NUM_BITS_ON_GBT_WORD    : integer := 76
    );
    port (
    --------------------------------------------------------------------------------
    -- RESET
    --------------------------------------------------------------------------------
    ipb_rst                   : in  std_logic;          --  General Reset
	--------------------------------------------------------------------------------
    -- TIMING 
    --------------------------------------------------------------------------------
    clk_bc_240                : in  std_logic;
    tick_bc                   : in  std_logic;
    --------------------------------------------------------------------------------
    -- GBT monitoring
    --------------------------------------------------------------------------------
    gbt_rx_clk240_en          : in std_logic;
    gbt_rx_data               : in  std_logic_vector (79 downto 0);
    gbt_rx_data_flag          : in  std_logic;
   	--------------------------------------------------------------------------------
    -- TCR resets
    --------------------------------------------------------------------------------
    rst_tcr_buffer_i          : in std_logic;
    rst_tcr_state_machine_i   : in std_logic;
    --------------------------------------------------------------------------------
    -- Data to GBT		
    --------------------------------------------------------------------------------
    d_i_sel                   : in  std_logic;
--    start_command             : in  std_logic;
    global_orbit              : in  std_logic_vector (31 downto 0);
    s_TTC_RXD	              : in  std_logic_vector(119 downto 0);
    d_i                       : in  std_logic_vector (67 downto 0); --> Generalising the problem to an unprecised number of bits.   
--    bc_number_i               : in  std_logic_vector (11 downto 0); -- BC ID
    d_o                       : out std_logic_vector (79 downto 0); -- GBT data
    dv_o                      : out std_logic;                      -- GBT data flag
    --------------------------------------------------------------------------------
    -- TCR start/stop
    --------------------------------------------------------------------------------
    start_tcr_data_taking_o   : out std_logic;
    stop_tcr_data_taking_o    : out std_logic; 
    --------------------------------------------------------------------------------
    -- TCR state machine coders (same interface as IR)
    --------------------------------------------------------------------------------
    tcr_state_machine_codes_o : out std_logic_vector (31 downto 0);
    --------------------------------------------------------------------------------
    -- Miscellaneous
    --------------------------------------------------------------------------------
    sn                        : in  std_logic_vector ( 7 downto 0);
    threshold                 : in  std_logic_vector (31 downto 0)

          ); 
end component;
	
begin

	CLK_0 <= not(CLK_0) after (1 us/240);
	data_sel_s <= '0';

	process(CLK_0)                          -- process for clk_en
        variable count  : integer := 0;
        begin
        -- Clk Enable
                if rising_edge(CLK_0) then
                        clk_en_s <='0';
                        if(count= 6) then
                                clk_en_s <='1';
                                count:=0;
                        end if;
                        count:=count+1;
                end if;
        end process;

--	process					-- process for reset
--  	begin
--    	-- Assert Reset
--    		reset_s <= '1';
--    		wait for (12ns);           --change time if needed
--    		reset_s <= '0';
--    		wait;
--  	end process;

--	process(CLK_0)                  -- process for input data
--        begin
--                if rising_edge(CLK_0) and clk_en_s = '1' then
--                        --data_s <= std_logic_vector(to_unsigned(to_integer(unsigned(data_s)) + 1, 48));
--			data_s <= (others => '0');
--                end if;
--        end process;

        process(CLK_0)
        begin
                if rising_edge(CLK_0) and clk_en_s = '1' then
--		    if bc_number_s = x"DEB" then
--		    if bc_number_s = "000010000000" then
--		    if bc_number_s = "000000101101" then
            if gbt_rx_s = x"300000000000DEADBEEF" then
			     bc_number_s     <= (others =>'0');            
--		    elsif bc_number_s = "000000101101" then
		    elsif bc_number_s = "000000001101" then
--		    elsif bc_number_s = "110111101011" then
			     bc_number_s     <= (others =>'0');
			     trigger_string  <= x"000000000000000000000000000002"; -- assert SOx
--                 generated_orbit <= std_logic_vector(unsigned(generated_orbit) + 1);
--                 generated_orbit <= std_logic_vector(to_unsigned(to_integer(unsigned(generated_orbit)) + 1, 31));
		    else
                 bc_number_s     <= std_logic_vector(to_unsigned(to_integer(unsigned(bc_number_s)) + 1, 12));
                 trigger_string  <= (others =>'0');
		    end if;	
                end if;
        end process;

	

	comp_top: top_ir_statemachine
	    generic map ( g_NUM_BITS_ON_GBT_WORD => 60 )
        port map (
--            start_command=> start_command,
            --------------------------------------------------------------------------------
            -- RESET
            --------------------------------------------------------------------------------
            ipb_rst                   => reset_s,          --  General Reset
            --------------------------------------------------------------------------------
            -- TIMING 
            --------------------------------------------------------------------------------
            clk_bc_240                => CLK_0,
            tick_bc                   => clk_en_s,
            --------------------------------------------------------------------------------
            -- GBT monitoring
            --------------------------------------------------------------------------------
            gbt_rx_clk240_en          => CLK_0,
            gbt_rx_data               => gbt_rx_s,
            gbt_rx_data_flag          => gbt_flag_s,
            --------------------------------------------------------------------------------
            -- TCR resets
            --------------------------------------------------------------------------------
            rst_tcr_buffer_i          => reset_s, 
            rst_tcr_state_machine_i   => reset_s, 
            --------------------------------------------------------------------------------
            -- Data to GBT		
            --------------------------------------------------------------------------------
            d_i_sel                   => data_sel_s,
        --    start_command             : in  std_logic;
            global_orbit              => generated_orbit,
            s_TTC_RXD	              => trigger_string,
            d_i                       => data_s,   
--            bc_number_i               => bc_number_s, -- BC ID
            d_o                       => gbt_connection, -- GBT data
            dv_o                      => open,  
            --------------------------------------------------------------------------------
            -- TCR start/stop
            --------------------------------------------------------------------------------
            start_tcr_data_taking_o   => open,
            stop_tcr_data_taking_o    => open,
            --------------------------------------------------------------------------------
            -- TCR state machine coders (same interface as IR)
            --------------------------------------------------------------------------------
            tcr_state_machine_codes_o => s_state_num,
--            tcr_state_machine_codes_o => open
            sn                        => sn_i,
            threshold                 => threshold       

        );



        -- ==================================
        -- Saving to TXT
        -- ==================================
        p_file_write:process(clk_en_s)
                variable v_oline : line;
                variable s_state_num_1: std_logic_vector(3 downto 0);
        begin
                if rising_edge(clk_en_s) then
                        --file_open(out_file, "abcd.txt", write_mode);
                        --hwrite(v_oline, s_d);
                        --writeline(out_file,v_oline);
--                        init_signal_spy("/TC_statemachine_tb/comp_top/tcr_state_machine_codes_o","/s_state_num_1",1);
--                        s_state_num_1 <= s_state_num(3 downto 0);
                        s_state_num_1 := s_state_num(3 downto 0);
--                        hwrite(v_oline, s_rand);
--                        write(v_oline, string'("     "));
                        hwrite(v_oline, gbt_connection);      -- original 
--                        write(v_oline, gbt_connection);
                        write(v_oline, string'("             "));
--                        write(v_oline, s_dv);
--                        write(v_oline, string'("       "));
                        case s_state_num_1 is
--                          when "1000" =>
--                            write(v_oline, string'("IDLE"));
                          when "1000" =>
                            write(v_oline, string'("IDLE/WAIT_TRIGG/SEND_IDLE/NEW_RDH"));
                          when "0001" =>
                            write(v_oline, string'("SEND_SOP"));
                          when "0010" =>
                            write(v_oline, string'("SEND_RDH_WORD0"));
                          when "0011" =>
                            write(v_oline, string'("SEND_RDH_WORD1"));
                          when "0100" =>
                            write(v_oline, string'("SEND_RDH_WORD2"));
                          when "0101" =>
                            write(v_oline, string'("SEND_RDH_WORD3"));
--                          when "0110" =>
--                            write(v_oline, string'("WAIT_FOR_TRIGGER"));
                          when "0110" =>
                            write(v_oline, string'("SEND_DATA"));
                          when "0111" =>
                            write(v_oline, string'("SEND_EOP"));
--                          when x"9" =>
--                            write(v_oline, string'("NEW_RDH"));
--                          when x"A" =>
--                            write(v_oline, string'("SEND_IDLE"));
                          when others =>
                            write(v_oline, string'("ERR"));
                        end case;
                        writeline(out_file,v_oline);
                        --writeline(in_file, v_iline);
                end if;
        end process;



    -- ================================== 
    -- Complete simulation
    -- ================================== 
    p_GBT_validation:process(CLK_0, gbt_rx_s)
    begin
        if(rising_edge(CLK_0)) then
            if( gbt_rx_s = x"300000000000DEADBEEF" ) then
                starting_flag      <= '1';
            elsif(starting_flag = '1') then
                data_s(39 downto 8) <= x"CAFECAFE";
--                data_s(0 downto 0) <= "0";
            elsif( gbt_rx_s = x"300000000000BEEFDEAD" ) then     
                data_s             <= (others => '0');
                starting_flag      <= '0';
            else  
                data_s             <= (others => '0');
                starting_flag      <= '0';
            end if;
        end if;
    end process p_GBT_validation;            
              

    
	p_main:process
--	        variable v_line : line ;
	begin
--            write(v_line, string'("Random Input     GBT Output           isdatasel            State"));
--            writeline(out_file, v_line);	       
	    	-- Assert Reset
--	    	data_s <= (others => '0');
    		reset_s  <= '1';	
    		wait for 200 ns;           --change time if needed
    		reset_s  <= '0';
    		gbt_rx_s <= (others => '0');
		    wait for 1000 ns;
		    wait until CLK_0 = '1';
--		    start_command <= '1'; -- assert SOx
		    gbt_rx_s <= x"300000000000DEADBEEF";
--		    wait until CLK_0 = '1';
--		    start_command <= '0'; -- assert SOx
    		wait for 130 ns;           --change time if needed
		    gbt_rx_s <= (others => '0');
--    		wait for 130 ns;           --change time if needed
--		    wait until CLK_0 = '0';
--            data_s(0 downto 0) <= "1";
--		    wait for 20 ns;           --change time if needed
--            wait until CLK_0 = '1';
--            data_s <= (others => '0');
--            wait for 140 ns;           --change time if needed
--		    wait until clk_en_s = '1';
--            data_s(0 downto 0) <= "1";
--		    wait for 20 ns;           --change time if needed
--            wait until clk_en_s = '0';
--            data_s <= (others => '0');
--            wait for 890 ns;
--		    wait until clk_en_s = '1';
--		    trigger_string <= x"000000000000000000000000000002"; -- assert SOx
--		    wait until clk_en_s = '0';
		    
--		    trigger_string <= (others => '0');
--		    wait for 200 ns;
--		    gbt_rx_s <= x"300000000000BEEFDEAD";



    		wait for 4000 ns;           --change time if needed

		    gbt_rx_s <= x"300000000000DEADBEEF";

		    wait for 300 ms;
	
	end process;


--    -- ==================================
--    -- Easy simulation
--    -- ================================== 
--	p_main:process
--	begin
--	    	-- Assert Reset
----	    	data_s <= (others => '0');
--    		reset_s  <= '1';	
--    		wait for 200 ns;           --change time if needed
--    		reset_s  <= '0';
--    		gbt_rx_s <= (others => '0');
--		    wait for 1000 ns;
--		    wait until CLK_0 = '1';
----		    start_command <= '1'; -- assert SOx
--		    gbt_rx_s <= x"300000000000DEADBEEF";
----		    wait until CLK_0 = '1';
----		    start_command <= '0'; -- assert SOx
--    		wait for 130 ns;           --change time if needed
--		    gbt_rx_s <= (others => '0');
--    		wait for 130 ns;           --change time if needed
--		    wait until CLK_0 = '0';
--            data_s(0 downto 0) <= "1";
--		    wait for 20 ns;           --change time if needed
--            wait until CLK_0 = '1';
--            data_s <= (others => '0');
--            wait for 140 ns;           --change time if needed
--		    wait until clk_en_s = '1';
--            data_s(0 downto 0) <= "1";
--		    wait for 20 ns;           --change time if needed
--            wait until clk_en_s = '0';
--            data_s <= (others => '0');
--            wait for 890 ns;
--		    wait until clk_en_s = '1';
--		    trigger_string <= x"000000000000000000000000000002"; -- assert SOx
--		    wait until clk_en_s = '0';
		    
--		    trigger_string <= (others => '0');
--		    wait for 200 ns;
--		    gbt_rx_s <= x"300000000000BEEFDEAD";
--		    wait for 30 ms;
	
--	end process;
	
	
	
end Behavioral;
