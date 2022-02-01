--------------------------------------------------------------------------------
-- Title      : Continous Packet Sap Generator
-- Project    : CRU
-------------------------------------------------------------------------------
-- File       : cont_sap.vhd
-- Author     : Filippo Costa (filippo.costa@cern.ch), Tuan Mate Nguyen (tuan.mate.nguyen@cern.ch)
-------------------------------------------------------------------------------
-- Description: Generating standard (see RDH fields) formatted packets
--              emulating detector FEEs (see DDG/README.md)
-- 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

entity ir_statemachine is
  port (
    --------------------------------------------------------------------------------
    -- CLK and RESET
    --------------------------------------------------------------------------------
    clk_i                     : in  std_logic;
    clk_en_i                  : in  std_logic;
    rst_i                     : in  std_logic;
--    START                     : in  std_logic;
    ------------------------------------------------------
	-- START and STOP of IR data taking
	------------------------------------------------------
	start_ir_data_taking_i   : in std_logic;
	stop_ir_data_taking_i    : in std_logic;
    --------------------------------------------------------------------------------
    -- TRG interface
    --------------------------------------------------------------------------------
    trg_i                     : in  std_logic_vector(119 downto 0);
    trg_mask_i                : in  std_logic_vector(31 downto 0);
    ctp_orbit                 : in  std_logic_vector(31 downto 0);
    --------------------------------------------------------------------------------
    -- Control signals
    --------------------------------------------------------------------------------
--    cfg_i                   : in  std_logic_vector(31 downto 0);
--    cfg2_i                  : in  std_logic_vector(31 downto 0);
--    cfg3_i                  : in  std_logic_vector(31 downto 0);
	------------------------------------------------------
	-- Data Control
	------------------------------------------------------
	data_i		              : in  std_logic_vector(82 downto 0);
	data_rd_fifo              : out std_logic;
	read_buffer               : out std_logic;
	empty_fifo                : in  std_logic;
	valid_fifo                : in  std_logic;
	reset_buffer              : out std_logic; 
--	bc_number_i               : in  std_logic_vector (11 downto 0); -- BC ID
    --------------------------------------------------------------------------------
    -- GBT DATA OUTPUT
    --------------------------------------------------------------------------------
    d_o                       : out std_logic_vector(79 downto 0);
    w_o                       : out std_logic_vector(31 downto 0);
    dv_o                      : out std_logic;
    --------------------------------------------------------------------------------
    -- MONITORING
    --------------------------------------------------------------------------------
   	ir_state_machine_codes_o : out std_logic_vector(31 downto 0);
    ev_cnt_o                  : out std_logic_vector(31 downto 0);
    trgmisscnt_o              : out std_logic_vector(31 downto 0);
    sn                        : in  std_logic_vector( 7 downto 0)
    );
end ir_statemachine;

architecture rtl of ir_statemachine is
  -- CONSTANT
  constant c_PIPE_LENGTH       : natural := 5;
  constant c_SOP               : std_logic_vector(3 downto 0)  := x"1";
  constant c_EOP               : std_logic_vector(3 downto 0)  := x"2";
  constant c_MAX_EVENT_SIZE    : natural := 508;
--  constant c_MAX_EVENT_SIZE    : natural := 20;
  constant c_ZERO              : std_logic_vector(31 downto 0) := (others => '0');
  constant c_DETECTOR_ID       : std_logic_vector(7 downto 0) := x"CD"; -- why?
  -- HEADER
  signal c_HEADER_VERSION      : std_logic_vector(7 downto 0)  := x"06";
--  constant c_FEE_ID            : std_logic_vector(15 downto 0) := x"CAFE";  -- > sn(7 downto 0) & "0001" &  "0000"
  constant c_FEE_ID            : std_logic_vector(15 downto 0) := "0000" & "0000" & sn(7 downto 0);
  -- header size = 4 words x 80 bits / (8 bit/byte) = 40 bytes
  signal c_HEADER_SIZE         : std_logic_vector(7 downto 0)  := x"40";
  signal c_DET_FIELD           : std_logic_vector(31 downto 0) := x"12345678"; -- originally x"00000000"
  signal c_PAR                 : std_logic_vector(15 downto 0) := x"0000";
  signal c_PRIORITY_BIT        : std_logic_vector(7 downto 0)  := x"00";
  constant c_SOURCE_ID         : std_logic_vector(7 downto 0)  := "00010001"; --> TRG is 17
  -- UNSIGNED
  signal u_pat_cnt             : unsigned(31 downto 0) := (others => '0');
  signal u_bc_cnt              : unsigned(11 downto 0) := (others => '0');
  signal u_orbit_cnt           : unsigned(31 downto 0) := (others => '0');
  signal u_ev_cnt              : unsigned(31 downto 0) := (others => '0');
  signal u_page_cnt            : unsigned(15 downto 0) := (others => '0');
  signal trgmisscnt            : unsigned(31 downto 0) := (others => '0');
-- INTEGER
  signal i_plcnt               : natural range 0 to 508;
--  signal i_plcnt		       : natural range 0 to 813; -- why 813??
  signal i_gbt_word            : natural range 0 to 512;
  signal i_gbt_word_limit      : natural range 0 to 512;
  signal i_ev_size             : natural range 0 to 512;
  signal i_wordsize            : natural range 0 to 512;
  signal i_idle_gbt_word       : natural range 0 to 1024;
  signal i_max_idle_btw_events : natural range 0 to 1024;
  signal i_rnd_in_range        : natural range 0 to 512;
  -- SIGNAL
  signal s_prsg_num            : std_logic_vector(23 downto 0);
  signal s_send_data           : std_logic;
  signal s_hbf_stop            : std_logic;
  signal s_trg_masked          : std_logic_vector(31 downto 0);
  signal s_hborbit             : std_logic_vector(31 downto 0);
  signal s_hbbc                : std_logic_vector(11 downto 0);
  signal s_last_orbit          : std_logic_vector(31 downto 0);
  signal s_last_bc             : std_logic_vector(11 downto 0);
  signal s_last_trgorbit       : std_logic_vector(31 downto 0);
  signal s_last_trgbc          : std_logic_vector(11 downto 0);
  signal s_ttype               : std_logic_vector(31 downto 0);
  signal s_last_ttype          : std_logic_vector(31 downto 0);
  signal s_trgd                : std_logic_vector(79 downto 0);
  signal HB, SOx, EOx, TTVALID : std_logic := '0';
  signal wasSOx                : std_logic;
  signal run                   : std_logic := '1';
--  signal run                   : std_logic;
  signal wasHB, wasHBpre       : std_logic := '0';
  signal wasEOx                : std_logic := '0';
  signal eox_pkt_sent          : std_logic_vector(2 downto 0);
  signal s_payload_not_sent    : std_logic := '0';
  signal hbf_closed            : std_logic := '0';
  signal s_last_word           : std_logic;
  signal s_last_idle           : std_logic;
  signal s_no_idle_btw_events  : std_logic;
  --
  constant s_pause             : std_logic := '0';
  constant s_idle_btw          : std_logic_vector(9 downto 0) := (others => '0');
  --
  signal s_trg                 : std_logic;
  --
  signal trgmaskedpre    : std_logic_vector(31 downto 0);
  signal ttvalidpre      : std_logic_vector(c_PIPE_LENGTH-1 downto 0);
  signal trgmaskedorpre  : std_logic_vector(c_PIPE_LENGTH-1 downto 0);
  signal hbpre           : std_logic_vector(c_PIPE_LENGTH-1 downto 0);
  signal soxpre          : std_logic_vector(c_PIPE_LENGTH-1 downto 0);
  signal eoxpre          : std_logic_vector(c_PIPE_LENGTH-1 downto 0);
  --
  alias hb_packer       : std_logic is data_i(80); 
  alias eox_0_packer    : std_logic is data_i(81); 
  alias eox_1_packer    : std_logic is data_i(82); 
  --
  signal valid_fifo_q   : std_logic := '0';
  signal valid_fifo_qq  : std_logic := '0';
  signal helper_bc      : std_logic := '0';
  signal helper_orbit   : std_logic_vector(31 downto 0) := (others => '0');
  signal helper_data_eop: std_logic := '0';
  signal helper_data_eop2: std_logic := '0';
  signal store_data_eop : std_logic_vector(79 downto 0) := (others => '0');

  signal page_counter   : unsigned(15 downto 0) := (others => '0'); 
  signal helper_stopbit : std_logic := '0';



  -- SM
  type t_states is (
    IDLE,
    SEND_SOP,
    SEND_RDH_WORD0,
    SEND_RDH_WORD1,
    SEND_RDH_WORD2,
    SEND_RDH_WORD3,
    WAIT_FOR_TRIGGER,
    SEND_DATA,
    SEND_EOP,
    NEW_RDH,
    SEND_IDLE
    );
  signal s_cs           : t_states;
  signal s_ns           : t_states;
  signal s_previoustate : t_states;


begin




  --------------------------------------------------------------------------------
  -- Process to introduce IDLE words between 2 packets
  --
  -- Is IDLE coming from zero suppression too??
  --------------------------------------------------------------------------------
  p_idle_btw_events : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_cs = SEND_SOP then
--        if s_rnd_idle_num = '1' then
--          i_max_idle_btw_events <= to_integer(unsigned(s_prsg_num(9 downto 0)));
--        else
          i_max_idle_btw_events <= to_integer(unsigned(s_idle_btw));
--        end if;

        -- Create single signal to reduce counter comparisons
        if i_max_idle_btw_events = 0 then
          s_no_idle_btw_events <= '1';
        else
          s_no_idle_btw_events <= '0';
        end if;
      end if;
    end if;
  end process p_idle_btw_events;



  --------------------------------------------------------------------------------
  -- Process used to generate send_data signal to change the frequency data and
  -- stress different scenarios
  --------------------------------------------------------------------------------  
  p_wr : process(clk_i)
  begin
    if rising_edge(clk_i) then
        s_send_data <= '1';
    end if;
  end process p_wr;


  
  ---------------------------------
  -- signal latching EOx trigger:
  -- effect: exit to IDLE at the next opportunity
  ---------------------------------
  p_eox : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then 
        if s_cs = IDLE then
          -- also in reset (because rst->IDLE)
          wasEOx <= '0';
        elsif EOx = '1' then
          wasEOx <= '1';
        end if;
      end if;
    end if;
  end process p_eox;


  ------------------------------------------------------------------
  -- Helper signal to send very last packets with EOx trigger info:
  -- Once the EOx is received, 3 RDH packet needs to be sent (this vector
  -- tracks these RDHs by shifting to the left; '1' for sent, '0' for not sent):
  -- 1. Close current HBF,
  -- 2. New HBF open, containing trigger info of EOx
  -- 3. HBF close
  ------------------------------------------------------------------
  p_eox_sent : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then
        if s_cs = IDLE then
          -- also in reset (because rst->IDLE)
          eox_pkt_sent <= (others => '0');
        elsif s_cs = SEND_EOP then
          if s_payload_not_sent = '0' and wasEOx = '1' then
            eox_pkt_sent <= eox_pkt_sent(eox_pkt_sent'length-2 downto 0) & '1';
          end if;
        end if;
      end if;
    end if;
  end process p_eox_sent;

  ---------------------------------
  -- signal latching HB trigger:
  -- effect: close current HBF at next opporunity
  ---------------------------------
  p_hb : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then
        if s_cs = IDLE then
          -- also in reset (because rst->IDLE) 
          wasHBpre <= '0';
        elsif HB = '1' then
          wasHBpre <= '1';
        elsif s_cs = SEND_RDH_WORD3 and hbf_closed = '1' then
          wasHBpre <= '0';
        end if;
      end if;
    end if;
  end process p_hb;

  wasHB <= wasHBpre or HB;


  
  -------------------------------------------
  -- helper signal to send the HBF-close RDH
  -------------------------------------------
  p_close : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then
        if s_cs = IDLE then
          -- also in reset (because rst->IDLE)           
          hbf_closed <= '0';
        elsif s_cs = SEND_SOP then
          -- if the HBF-close RDH is being sent (either because there was an EoT or a
          -- new HB trigger), toggle the hbf_close signal
          if (wasEOx = '1' or wasHB = '1') and s_payload_not_sent = '0' then
            hbf_closed <= '1';
          else
            hbf_closed <= '0';
          end if;
        end if;
      end if;
    end if;
  end process p_close;

  s_hbf_stop <= hbf_closed;

  

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      ttvalidpre(0) <= clk_en_i and trg_i(119);-- and s_ddg_packet_mode;
      trgmaskedpre  <= trg_mask_i and trg_i(31 downto 0);
      hbpre(0)      <= trg_i(1);
      soxpre(0)     <= trg_i(7) or trg_i(9);
      eoxpre(0)     <= trg_i(8) or trg_i(10);

      ttvalidpre(1)     <= ttvalidpre(0);
      trgmaskedorpre(1) <= or_reduce(trgmaskedpre);
      hbpre(1)          <= hbpre(0) and ttvalidpre(0);
      soxpre(1)         <= soxpre(0) and ttvalidpre(0);
      eoxpre(1)         <= eoxpre(0) and ttvalidpre(0);

      for i in 2 to c_PIPE_LENGTH-1 loop
      ttvalidpre(i)     <= ttvalidpre(i-1);
      trgmaskedorpre(i) <= trgmaskedorpre(i-1);
      hbpre(i)          <= hbpre(i-1);
      soxpre(i)         <= soxpre(i-1);
      eoxpre(i)         <= eoxpre(i-1);
      end loop;

      TTVALID <= ttvalidpre(c_PIPE_LENGTH-1);
      HB      <= hbpre(c_PIPE_LENGTH-1);
      SOx     <= soxpre(c_PIPE_LENGTH-1);
      wasSOx  <= SOx;
      EOx     <= eoxpre(c_PIPE_LENGTH-1);
      s_trg   <= ttvalidpre(c_PIPE_LENGTH-1);

    end if;
  end process;

  
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then
        s_trgd <= trg_i(s_trgd'range);
      end if;
    end if;
  end process;


  -- Track if the full event payload for the last trigger has been sent
  p_hbf : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then
        if s_cs = IDLE then
          -- also in reset (because rst->IDLE)           
          s_payload_not_sent <= '0';
        else
          -- At the last word of the trigger's payload, update status
          -- if there's new valid (no previous HB or EOT) trigger
          if s_last_word = '1' then
            s_payload_not_sent <= s_trg and not wasEOx and not wasHB and run;
          else
            -- otherwise preserve status and check for new valid trigger
            s_payload_not_sent <= s_payload_not_sent or (s_trg and not wasEOx and not wasHB and run);
          end if;
        end if;          
      end if;
        
    end if;
  end process p_hbf;
  

  p_stopdata : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then
        if run = '1' and stop_ir_data_taking_i = '1' then
           run <= '0';
        elsif start_ir_data_taking_i = '1' then
           run <= '1';
        end if;     
      end if;
    end if;
  end process p_stopdata;      
  
  -- State machine
  p_sm : process(clk_i)
  begin
    if rising_edge(clk_i) then
      read_buffer  <= valid_fifo;
      if rst_i = '1' then
        s_cs <= IDLE;
      elsif clk_en_i = '1' then
        s_cs <= s_ns;
        s_previoustate <= s_cs;
        
        -- READ THE FIFO
        if ((s_cs = SEND_RDH_WORD3 and s_ns = WAIT_FOR_TRIGGER) or (s_cs = SEND_DATA and s_ns = WAIT_FOR_TRIGGER) or (s_ns = SEND_DATA) ) then
            data_rd_fifo <= '1';
        else
            data_rd_fifo <= '0';            
        end if;    
        
      end if;
    end if;
  end process p_sm;

  p_pcmb : process(s_cs, run,
                   start_ir_data_taking_i, s_trg, s_payload_not_sent, empty_fifo, hb_packer, eox_0_packer, eox_1_packer,
                   wasHB, wasEOx, HB, i_plcnt, s_last_word, s_last_idle,
                   hbf_closed, s_no_idle_btw_events, eox_pkt_sent)
  begin
    s_ns <= s_cs;

    case s_cs is
      when IDLE =>
        reset_buffer <= '0';
        if ((start_ir_data_taking_i = '1') or (s_trg = '1')) then
          s_ns <= SEND_SOP;
        end if;

        
      when SEND_SOP =>
        reset_buffer <= '0';
        s_ns <= SEND_RDH_WORD0;
        
        
      when SEND_RDH_WORD0 =>
        s_ns <= SEND_RDH_WORD1;        

        
      when SEND_RDH_WORD1 =>
        s_ns <= SEND_RDH_WORD2;        

        
      when SEND_RDH_WORD2 =>
        s_ns <= SEND_RDH_WORD3;        

        
      when SEND_RDH_WORD3 =>
        if helper_stopbit = '1' then
          s_ns <= SEND_EOP;
        elsif s_payload_not_sent = '1' then
          s_ns <= SEND_DATA;
        elsif helper_data_eop = '1' then
          s_ns <= SEND_DATA;  
        elsif hb_packer = '1' or eox_0_packer = '1' or eox_1_packer = '1' then
          s_ns <= SEND_EOP;
        elsif empty_fifo = '0' and run = '1' then
          s_ns <= WAIT_FOR_TRIGGER;
        else
          s_ns <= WAIT_FOR_TRIGGER;
        end if;

        
      when WAIT_FOR_TRIGGER =>
        reset_buffer <= '0';
        if hb_packer = '1' or eox_0_packer = '1' or eox_1_packer = '1' then
          s_ns <= SEND_EOP;
        elsif empty_fifo = '0' and run = '1' then
          s_ns <= SEND_DATA;
        end if;

        
      when SEND_DATA =>
        reset_buffer <= '0';
        -- If reached 8 kB boundary, start new 8 kB page
        if i_plcnt = c_MAX_EVENT_SIZE-1 then
          s_ns <= SEND_EOP;
            
        else
          if hb_packer = '1' or eox_0_packer = '1' or eox_1_packer = '1' or run = '0' then
            s_ns <= SEND_EOP;
          elsif empty_fifo = '0' and run = '1' then
            s_ns <= SEND_DATA;
              
          else
            s_ns <= WAIT_FOR_TRIGGER;
          end if;            
        end if;

        
      when SEND_EOP =>
        -- If full event payload hasn't been sent,
        -- finish sending it first
        if s_payload_not_sent = '1' then
          s_ns <= NEW_RDH;
          
        elsif helper_stopbit = '1' and s_previoustate = SEND_RDH_WORD3 then
          helper_stopbit <= '0';
          s_ns <= NEW_RDH;
            
        elsif hb_packer = '1' or eox_0_packer = '1' or eox_1_packer = '1' then
          reset_buffer <= '1';
          if helper_stopbit = '0' then
             helper_stopbit <= '1';
             s_ns <= NEW_RDH;   
          
          elsif hbf_closed = '1' then
            if eox_0_packer = '1' or eox_1_packer = '1' then
              if eox_pkt_sent(eox_pkt_sent'length-1) = '0' then   
                s_ns <= NEW_RDH;
              else
                s_ns <= IDLE;
              end if;
              
            elsif run = '0' then
              s_ns <= IDLE;
            else
              s_ns <= NEW_RDH;
            end if;
          else -- HBF is not yet closed, send the HBF-close RDH
            s_ns <= NEW_RDH;
          end if;

        else -- Start new HBF if not paused
          if run = '1' then
            s_ns <= NEW_RDH;
          else
            s_ns <= IDLE;
          end if;            
        end if;

        
      when NEW_RDH =>
        reset_buffer <= '0';
        if s_no_idle_btw_events = '1' then
          s_ns <= SEND_SOP;
        else
          s_ns <= SEND_IDLE;
        end if;

        
      when SEND_IDLE =>
          reset_buffer <= '0';
          if s_last_idle = '1' then
            s_ns <= SEND_SOP;
          end if;

        
      when others =>
        reset_buffer <= '0';
        s_ns <= IDLE;
          
    end case;
  end process p_pcmb;



  ------------------------------------------------
  -- Missing payload helper
  ------------------------------------------------
  p_missingpayload : process(clk_i)  
  begin
  if rising_edge(clk_i) then
      if(clk_en_i = '1') then  
      if(helper_data_eop = '0') then  
            if s_ns = NEW_RDH then
                  if or_reduce(data_i) = '1' then
                        helper_data_eop <= '1';
                        store_data_eop  <= data_i(79 downto 0);
                  end if;
            end if;
       elsif (helper_data_eop = '1' and helper_data_eop2 = '0' and s_cs = SEND_DATA)     then
            helper_data_eop2 <= '1';
       elsif (helper_data_eop = '1' and helper_data_eop2 = '1') then
            helper_data_eop  <= '0';
            helper_data_eop2 <= '0';
            store_data_eop   <= (others => '0');
       end if;
       end if;
   end if;
   end process p_missingpayload;
   
                        
  ------------------------------------------------
  -- Process to count the number of payload GBT
  -- words sent for individual triggers
  ------------------------------------------------
  p_gbt_word : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_cs = IDLE then
        i_gbt_word <= 0;
      elsif s_cs = SEND_DATA then
        -- Create signal to indicate last word of the event payload,
        -- and reduce the number of counter comparisons
        if i_gbt_word = i_ev_size - 1 then
          s_last_word <= '1';
        else
          s_last_word <= '0';
        end if;
            
        if clk_en_i = '1' then
          if i_gbt_word = i_ev_size - 1 or i_gbt_word = 511 then
            i_gbt_word <= 0;
          elsif s_send_data = '1' then
            i_gbt_word <= i_gbt_word + 1;
          end if;
        end if;
  
      else
        if s_payload_not_sent = '0' then
          i_gbt_word <= 0;
        end if;
        
      end if;  
    end if;
  end process p_gbt_word;


  
  -------------------------------------------
  -- Counter to make sure that one packet is
  -- max 8KB (see state machine condition)
  -------------------------------------------
  p_payloadcnt : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then
        if s_cs = IDLE then
          i_plcnt <= 0;        
        elsif s_cs = SEND_DATA then
        
          if s_send_data = '1' then
            i_plcnt <= i_plcnt + 1;
          end if;
       
        elsif s_cs = SEND_EOP then
          i_plcnt <= 0;
    
        end if;
      end if;
    end if;
  end process p_payloadcnt;


  
  -----------------------------------------------------------------
  -- Keep track of the number of IDLE words sent between packets
  -----------------------------------------------------------------
  p_gbt_idle_words : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if i_idle_gbt_word = i_max_idle_btw_events then
        s_last_idle <= '1';
      else
        s_last_idle <= '0';
      end if;
      
      if s_cs = SEND_IDLE then
        if clk_en_i = '1' then
          i_idle_gbt_word <= i_idle_gbt_word + 1;
        end if;

      elsif s_cs = NEW_RDH then
        if clk_en_i = '1' and i_max_idle_btw_events /= 0 then
          i_idle_gbt_word <= i_idle_gbt_word + 1;
        end if;
          
      else
        i_idle_gbt_word <= 0;
      end if;
    end if;
  end process p_gbt_idle_words;


  --------------------------------------------------------------
  -- Process to increase the counter part of the data payload
  --------------------------------------------------------------
  p_pat_cnt : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then
        if s_cs = IDLE then
          u_pat_cnt <= (others => '0');
        elsif s_cs = SEND_DATA then
          if s_send_data = '1' and i_gbt_word /= 0 then
            u_pat_cnt <= u_pat_cnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process p_pat_cnt;

  
  
  ----------------------------------------------------------------------
  -- Process to count the number of sent events (1 for every trigger)
  ----------------------------------------------------------------------
  p_ev_cnt : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        u_ev_cnt <= (others => '0');
      elsif clk_en_i = '1' then
        if s_last_word = '1' then
          u_ev_cnt <= u_ev_cnt + 1;
        end if;
      end if;
    end if;
  end process p_ev_cnt;


  
  ---------------------------
  -- Count missed triggers
  ---------------------------
  p_trgmisscnt : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        trgmisscnt <= (others => '0');
      elsif clk_en_i = '1' then
        if s_last_word = '1' and (run = '0' or eox_0_packer = '1' or eox_1_packer = '1') then  
          trgmisscnt <= trgmisscnt - 1;
        elsif run = '1' and (eox_0_packer = '1' or eox_1_packer = '1') then
          trgmisscnt <= trgmisscnt + 1;
        end if;        
      end if;
    end if;
  end process p_trgmisscnt;

  
  
  ------------------------------------------
  -- Page counter, restarts for every HBF
  ------------------------------------------
  p_pagecnt : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then
        if s_cs = IDLE then
          u_page_cnt <= (others => '0');
        elsif s_cs = SEND_EOP then
          -- Reset counter for every HBF
            u_page_cnt <= (others => '0');
        elsif s_cs = SEND_RDH_WORD3 then
            u_page_cnt <= u_page_cnt + 1;
        end if;
        
      end if;      
    end if;
  end process p_pagecnt;

  

  ------------------------------------
  -- Orbit and BC dummy counters
  ------------------------------------
  p_orbit_cnt : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then
          if s_cs = SEND_SOP and helper_stopbit = '0' then
          u_orbit_cnt <= unsigned(ctp_orbit);
          end if;
      end if;
    end if;
  end process p_orbit_cnt;
  


  p_bc_cnt : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if clk_en_i = '1' then
        if (s_cs = SEND_RDH_WORD0 and unsigned(helper_orbit) = u_orbit_cnt) then
            u_bc_cnt     <= u_bc_cnt + 1;
            page_counter <= page_counter + 1;
        elsif (s_cs = SEND_RDH_WORD0) then
            u_bc_cnt     <= (others => '0');
            page_counter <= (others => '0');
            helper_orbit <= ctp_orbit;
        else
            u_bc_cnt     <= u_bc_cnt + 1;   
        end if;
      end if;
    end if;
  end process p_bc_cnt;

  
  ----------------------------------------------------------------------
  -- Latching ttype, orbit and bc based on internal/external trigger
  ----------------------------------------------------------------------
  p_orbitbc : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if HB = '1' or SOx = '1' then
        s_last_ttype <= s_trgd(31 downto 0);
        s_last_orbit <= s_trgd(79 downto 48);
        s_last_bc    <= s_trgd(43 downto 32);
      end if;

      -- Update ttype before very first HBF (wasSOx), and after every HBF-close 
      if (s_cs = SEND_SOP) or wasSOx = '1' then
          s_ttype   <= x"CAFECAFE";
          s_hborbit <= std_logic_vector(u_orbit_cnt);
          s_hbbc    <= std_logic_vector(u_bc_cnt);
      end if;
    end if;
  end process p_orbitbc;


  -------------------------------------------
  -- Register ttype for PHYS trigger, too
  -------------------------------------------
  p_trgid : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_trg = '1' then
        s_last_trgorbit <= s_trgd(79 downto 48);
        s_last_trgbc    <= s_trgd(43 downto 32);
      end if;
    end if;
  end process p_trgid;      


  ev_cnt_o     <= std_logic_vector(u_ev_cnt);
  trgmisscnt_o <= std_logic_vector(trgmisscnt);
  
  --------------------------------------------------------------------------------
  -- Register the output of the SM
  -- DATA conisists of the same 32 bit word repeated all over the GBT word
  --------------------------------------------------------------------------------
  p_out : process(clk_i)
    variable help_vector : std_logic_vector(79 downto 0) := (others => '0');
  begin
    if rising_edge(clk_i) and clk_en_i = '1' then
      case s_cs is
        when SEND_SOP =>
          d_o(79 downto 76) <= c_SOP;
          dv_o <= '0';
          ir_state_machine_codes_o(3 downto 0) <= "0001";
          
        when SEND_RDH_WORD0 =>
          d_o  <= c_ZERO(31 downto 0) & c_SOURCE_ID & c_PRIORITY_BIT & c_FEE_ID & c_HEADER_SIZE & c_HEADER_VERSION;
          dv_o <= '1';
          ir_state_machine_codes_o(3 downto 0) <= "0010";

        when SEND_RDH_WORD1 =>
          d_o  <= c_ZERO(15 downto 0) & std_logic_vector(u_orbit_cnt) & c_ZERO(19 downto 0) & std_logic_vector(u_bc_cnt);
          dv_o <= '1';
          ir_state_machine_codes_o(3 downto 0) <= "0011";

          
        when SEND_RDH_WORD2 =>
          d_o  <= c_ZERO(23 downto 0) & "0000000" & helper_stopbit & std_logic_vector(page_counter) & s_ttype; 
          dv_o <= '1';
          ir_state_machine_codes_o(3 downto 0) <= "0100";

          
        when SEND_RDH_WORD3 =>
          d_o  <= c_ZERO(31 downto 0) & c_PAR & c_DET_FIELD;
          dv_o <= '1';
          ir_state_machine_codes_o(3 downto 0) <= "0101";

          
        when SEND_DATA =>

            if helper_data_eop = '1' and helper_data_eop2 = '0' then
              d_o <= store_data_eop;
              dv_o <= '1';
            else
              d_o <= data_i(79 downto 0);
              w_o <= std_logic_vector(u_pat_cnt);
              ir_state_machine_codes_o(3 downto 0) <= "0110";

            help_vector := data_i(79 downto 0);
            if( or_reduce(help_vector) = '0') then          
               dv_o <= '0';
            else 
               dv_o <= '1';
            end if;   
            end if;



          
        when SEND_EOP =>
          d_o(79 downto 76) <= c_EOP;
          dv_o <= '0';
          ir_state_machine_codes_o(3 downto 0) <= "0111";
          
        when IDLE | NEW_RDH | SEND_IDLE | WAIT_FOR_TRIGGER =>
          d_o  <= (others => '0'); -- my addition, not in the original file
          dv_o <= '0';
          ir_state_machine_codes_o(3 downto 0) <= "1000";
      end case;
    end if;
  end process p_out;

end rtl;
