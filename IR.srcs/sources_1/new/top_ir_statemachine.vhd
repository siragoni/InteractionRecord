----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/12/2020 02:47:02 PM
-- Design Name: 
-- Module Name: IR_top - Behavioral
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
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top_ir_statemachine is
  generic (
    g_NUM_BITS_ON_GBT_WORD    : integer := 60
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
    -- ir resets
    --------------------------------------------------------------------------------
    rst_ir_buffer_i          : in std_logic;
    rst_ir_state_machine_i   : in std_logic;
    --------------------------------------------------------------------------------
    -- Data to GBT		
    --------------------------------------------------------------------------------
    d_i_sel                   : in  std_logic_vector(31 downto 0);
--    start_command             : in  std_logic;
    global_orbit              : in  std_logic_vector (31 downto 0);
    s_TTC_RXD	              : in  std_logic_vector(119 downto 0);
    d_i                       : in  std_logic_vector (67 downto 0); --> Generalising the problem to an unprecised number of bits.   
--    bc_number_i               : in  std_logic_vector (11 downto 0); -- BC ID
    d_o                       : out std_logic_vector (79 downto 0); -- GBT data
    dv_o                      : out std_logic;                      -- GBT data flag
    --------------------------------------------------------------------------------
    -- ir start/stop
    --------------------------------------------------------------------------------
    start_ir_data_taking_o   : out std_logic;
    stop_ir_data_taking_o    : out std_logic; 
    --------------------------------------------------------------------------------
    -- ir state machine coders (same interface as IR)
    --------------------------------------------------------------------------------
    ir_state_machine_codes_o : out std_logic_vector (31 downto 0);
    --------------------------------------------------------------------------------
    -- Miscellaneous
    --------------------------------------------------------------------------------
    sn                        : in  std_logic_vector ( 7 downto 0);
    threshold                 : in  std_logic_vector (31 downto 0)

          ); 
end top_ir_statemachine;

architecture Behavioral of top_ir_statemachine is
	signal s_trg_mask	: std_logic_vector(31  downto 0) :=  x"00000090";
--	signal s_TTC_RXD	: std_logic_vector(119 downto 0) := x"8000001C2C00000000200000000880";
	signal random_data_s: std_logic_vector(47  downto 0);
	signal data_s		: std_logic_vector(82  downto 0) := (others=> '0');
	signal s_rd_en		: std_logic := '0';
	signal s_wr_en		: std_logic := '1';
	
--	signal read_fifo	: std_logic := '0';
	signal read_fifo	: std_logic;
	signal empty_fifo	: std_logic := '1';
	signal reset_buffer : std_logic := '0';
	
	signal ir_buffer_rd_en : std_logic := '0';
--	signal tc_buffer_rd_en : std_logic := '0';
	signal tc_buffer_wr_en : std_logic := '0';
	signal tc_buffer_rd_en : std_logic := '0';
	signal ir_buffer_wr_en : std_logic := '0';
	signal valid_data_pack : std_logic := '0';
	signal valid_data_pack2: std_logic := '1';
	signal valid_from_fifo : std_logic;
	signal read_buffer_from_fifo : std_logic := '0';
	
--	signal input_data_s    : std_logic_vector(47 downto 0) := x"000000000000";
	signal input_data_s    : std_logic_vector(67 downto 0) := (others => '0');
	signal input_data_short: std_logic_vector(67 downto 0) := (others => '0');
--	signal count           : std_logic_vector(47 downto 0) := x"000000000000";
	signal count           : std_logic_vector(82 downto 0) := (others => '0');
	signal count_bc        : std_logic_vector(11 downto 0) := (others => '0');
	signal u_orbit_id      : std_logic_vector(31 downto 0) := (others => '0');
--	signal formated_data_s : std_logic_vector(79 downto 0);
	signal formated_data_s : std_logic_vector(82 downto 0);
	signal validated_data  : std_logic_vector(82 downto 0) := (others => '0');
	signal validated_data2 : std_logic_vector(82 downto 0) := (others => '0');
		
	-- ir start/stop protocol	
	signal start_ir_data_taking : std_logic; 
	signal stop_ir_data_taking  : std_logic;
    signal helper_orbit_bc       : std_logic_vector(31 downto 0) := (others => '0');
	signal random_data           : std_logic_vector(47 downto 0) := (others => '0');

	
		
--component prsg
--  port (
--		clk_i		: in  std_logic;
--		clk_en_i    : in  std_logic;
--		rst_i		: in  std_logic;
--		rand_no_o	: out std_logic_vector(47 downto 0)
--	);
--end component;

component packer_ir2
  generic (
    bits_to_get : integer := g_NUM_BITS_ON_GBT_WORD 
    );
  port (
		clk_i       : in  std_logic;
		clk_en_i    : in  std_logic;
		rst_i	    : in  std_logic;
--		data_i      : in  std_logic_vector(47 downto 0);
		data_i      : in  std_logic_vector(67 downto 0);
		BC_count_i  : in  std_logic_vector(11 downto 0);
		trg_i       : in  std_logic_vector(119 downto 0);
--		data_o      : out std_logic_vector(79 downto 0) -- 80 bits
        valid_flag_o: out std_logic;
		data_o      : out std_logic_vector(82 downto 0) -- 80+ HB && EOx && SOx  bits
	);
end component;

component buffer_fifo
  port (
    clk_i    : IN  STD_LOGIC;
    clk_en_i : IN  STD_LOGIC;
    data_i   : IN  STD_LOGIC_VECTOR(82 DOWNTO 0);
    data_o   : OUT STD_LOGIC_VECTOR(82 DOWNTO 0);
    valid    : IN  STD_LOGIC;
    read     : IN  STD_LOGIC;
    reset    : IN  STD_LOGIC
  );
end component;

component ir_fifo
  port (
    clk         : IN STD_LOGIC;
    srst        : IN STD_LOGIC;
--    din         : IN STD_LOGIC_VECTOR(79 DOWNTO 0);
    din         : IN STD_LOGIC_VECTOR(82 DOWNTO 0);
    wr_en       : IN STD_LOGIC;
    rd_en       : IN STD_LOGIC;
--    dout        : OUT STD_LOGIC_VECTOR(79 DOWNTO 0);
    dout        : OUT STD_LOGIC_VECTOR(82 DOWNTO 0);
    full        : OUT STD_LOGIC;
    overflow    : OUT STD_LOGIC;
    empty       : OUT STD_LOGIC;
    valid       : OUT STD_LOGIC;
    wr_rst_busy : OUT STD_LOGIC;
    rd_rst_busy : OUT STD_LOGIC
  );
end component;    


component ir_statemachine
  port (
		--------------------------------------------------------------------------------
    	-- CLK and RESET
    	-------------------------------------------------------------------------------
    	clk_i                     : in  std_logic;
    	clk_en_i                  : in  std_logic;
    	rst_i                     : in  std_logic;
--    	START                     : in  std_logic;
	    start_ir_data_taking_i   : in  std_logic;
	    stop_ir_data_taking_i    : in  std_logic;
    	--------------------------------------------------------------------------------
    	-- TRG interface
    	--------------------------------------------------------------------------------
    	trg_i                     : in  std_logic_vector(119 downto 0);
    	trg_mask_i                : in  std_logic_vector(31  downto 0);
    	ctp_orbit                 : in  std_logic_vector(31  downto 0);
        ------------------------------------------------------
        -- Data Control
        ------------------------------------------------------
        data_i                    : in  std_logic_vector(82  downto 0);
        data_rd_fifo              : out std_logic;
        read_buffer               : out std_logic;
        empty_fifo                : in  std_logic;
        valid_fifo                : in  std_logic;
        reset_buffer              : out std_logic;
--        bc_number_i               : in  std_logic_vector (11 downto 0); -- BC ID
        --------------------------------------------------------------------------------
        -- GBT DATA OUTPUT
        --------------------------------------------------------------------------------
        d_o                       : out std_logic_vector(79  downto 0);
        w_o                       : out std_logic_vector(31  downto 0);
        dv_o                      : out std_logic;
        --------------------------------------------------------------------------------
        -- MONITORING
        --------------------------------------------------------------------------------
        ir_state_machine_codes_o : out std_logic_vector(31  downto 0);
        ev_cnt_o                  : out std_logic_vector(31  downto 0);
        trgmisscnt_o              : out std_logic_vector(31  downto 0);
        sn                        : in  std_logic_vector( 7  downto 0)
	);
end component;




component prsg_tcr
  port (
		clk_i		: in  std_logic;
		clk_en_i    : in  std_logic;
		rst_i		: in  std_logic;
		rand_no_o	: out std_logic_vector(47 downto 0);
		threshold   : in  std_logic_vector(31 downto 0)
	);
end component;



begin

rnd_data : prsg_tcr
  port map (
		clk_i       => clk_bc_240,
		clk_en_i    => tick_bc,
		rst_i	    => ipb_rst,
		rand_no_o   => random_data, -- 48 bits
		threshold   => threshold
	);

process (clk_bc_240, tick_bc)
    begin
        if (clk_bc_240'Event and clk_bc_240 = '1') then
            if (tick_bc = '1') then
                count <= count + '1';   -- counting up
                if count(11 downto 0) = "111111111111" then
                  count <= (others => '0');
                end if;  
            end if;
        end if;
    end process;


  p_bc_cnt_id : process(clk_bc_240)
--          variable helper_orbit_bc : std_logic_vector(31 downto 0) := (others => '0');
  begin
    if rising_edge(clk_bc_240) then
      if tick_bc = '1' then
--        helper_orbit_bc := global_orbit;
        helper_orbit_bc <= global_orbit;
        if (unsigned(helper_orbit_bc) = unsigned(u_orbit_id)) then
            count_bc     <= count_bc + 1;
        else
            count_bc     <= (others => '0');
            u_orbit_id   <= global_orbit;
        end if;
      end if;
    end if;
  end process p_bc_cnt_id;

validated_data2(11 downto  0) <= count_bc;
validated_data2(27 downto 12) <= x"CAFE";

input_data_s <= d_i              when (d_i_sel(2 downto 0) = "001") else -- bit 0 from register ctpreadout.ctrl
                input_data_short when (d_i_sel(2 downto 0) = "100") else
                d_i;

input_data_short(47 downto 0) <= random_data;	

input_data_packer : packer_ir2
  generic map ( bits_to_get => g_NUM_BITS_ON_GBT_WORD )
  port map (
		clk_i       => clk_bc_240,
		clk_en_i    => tick_bc,
		rst_i	    => ipb_rst,
--		data_i      => d_i,  -- 67 bits
--		data_i      => input_data_short,  -- 67 bits
		data_i      => input_data_s,  -- 67 bits
--		BC_count_i  => bc_number_i,    -- 12 bits
		BC_count_i  => count_bc,    -- 12 bits
		trg_i       => s_TTC_RXD,
		valid_flag_o=> valid_data_pack,
		data_o      => formated_data_s -- 82 bits
	);

--ir_buffer_rd_en <= s_rd_en   and tick_bc;
tc_buffer_rd_en <= read_fifo and tick_bc;
--tc_buffer_wr_en <= valid_data_pack and tick_bc;
tc_buffer_wr_en <= valid_data_pack;


-- IR FIFO

ir_fifo_inst: ir_fifo
  port map (
    clk           => clk_bc_240,
    srst          => rst_ir_buffer_i,
    din           => formated_data_s,
--    din           => validated_data2,
    wr_en         => tc_buffer_wr_en,
    rd_en         => tc_buffer_rd_en,
--    rd_en         => read_fifo,
    dout          => data_s,
    full          => open,
    overflow      => open,
--    valid         => open,
    valid         => valid_from_fifo,
    empty         => empty_fifo,
    wr_rst_busy   => open,
    rd_rst_busy   => open
  );


fifo_data_sync_with_valid_data: buffer_fifo
    port map(
        clk_i     => clk_bc_240,
		clk_en_i  => tick_bc,        
        data_i    => data_s,
        data_o    => validated_data,
        valid     => valid_from_fifo,
        read      => read_buffer_from_fifo,
        reset     => reset_buffer
    
    );


------------------------------------------------------
-- START and STOP of ir data taking
------------------------------------------------------
start_ir_data_taking_o <= start_ir_data_taking;
stop_ir_data_taking_o  <= stop_ir_data_taking;
  
ctrl_ir: process (clk_bc_240)
          begin 
          if (rising_edge(clk_bc_240)) then -- 240 MHz !!!
--             if (gbt_rx_clk240_en = '1') then
                         
                if (gbt_rx_data_flag = '0' and gbt_rx_data = x"300000000000DEADBEEF") then -- SWT word is when GBT bits 79:76 = 0x3
                   start_ir_data_taking <= '1';
                elsif (gbt_rx_data_flag = '0' and gbt_rx_data = x"300000000000BEEFDEAD") then -- SWT word is when GBT bits 79:76 = 0x3
                   stop_ir_data_taking <= '1';
                else
                   start_ir_data_taking <= '0';
                   stop_ir_data_taking <= '0';
             end if;
--             end if;
         end if;
         end process;






ir_state_machine : ir_statemachine
  port map (
    clk_i                     => clk_bc_240,		
    clk_en_i                  => tick_bc,		    
    rst_i                     => rst_ir_state_machine_i,			
--    START                     => start_command,	
     --
    start_ir_data_taking_i   => start_ir_data_taking,
    stop_ir_data_taking_i    => stop_ir_data_taking,
    --
    trg_i                     => s_TTC_RXD(119 downto 0),
    trg_mask_i                => s_trg_mask,	
    ctp_orbit                 => global_orbit,	
	data_i                    => validated_data,
--	data_i                    => input_data_s,
	data_rd_fifo              => read_fifo,
	read_buffer               => read_buffer_from_fifo,
	reset_buffer              => reset_buffer,
	empty_fifo                => empty_fifo,
	valid_fifo                => valid_from_fifo,
--    bc_number_i               => bc_number_i,
    --
    d_o                       => d_o,
    w_o                       => open,
    dv_o                      => dv_o,
    --
    ir_state_machine_codes_o => ir_state_machine_codes_o,
    ev_cnt_o                  => open,
    trgmisscnt_o              => open,
    sn                        => sn
      	);




end Behavioral;
