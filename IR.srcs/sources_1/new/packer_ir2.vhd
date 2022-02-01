----------------------------------------------------------------------------------
-- PACKER for State Machine.
-- It takes the input of 68+12 bits 
-- and produces the adequate output.
-- 
-- The way the logic works is that a
-- variable is defined which contains 
-- the meaningful number of bits.
--
-- This is modified in the top file
-- so that in Run 3 only the small number
-- have to be changed...
--
-- The crux of the problem is that both 
-- the CTP readout and the IR readout
-- should handle only a N < 80 bits,
-- while the GBT link can cope with 80 bits 
-- only.
--
-- This means that the rates would not be 
-- optimal. 
--
-- Unfortunately, this becomes more serious
-- for IR as it deals with 60 bits, than 
-- with TC which has 76 bits. 
--
--
-- It also generates a validation signal so 
-- that GBT is sending data only when it is high.
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;


entity packer_ir2 is
  generic (
    bits_to_get : integer := 60
    );

  port (
   clk_i		: in  std_logic;
   clk_en_i		: in  std_logic;   
   rst_i		: in  std_logic;
   data_i 		: in  std_logic_vector(67  downto 0); -- BC_ID + 1 due to the numbering
   bc_count_i	: in  std_logic_vector(11  downto 0);
   trg_i        : in  std_logic_vector(119 downto 0);
   valid_flag_o	: out std_logic;
   data_o		: out std_logic_vector(82  downto 0)
);
end packer_ir2;

architecture Behavioral of packer_ir2 is
  signal temp_data_s       : std_logic_vector(299 downto 0):= (others => '0');
  signal zeroes            : std_logic_vector(299 downto 0):= (others => '0');
  signal s_store_count     : std_logic_vector(8   downto 0):= (others => '0');
  signal store_valid       : std_logic := '0';
  signal helper_orbit      : std_logic := '0';
  signal data              : std_logic_vector(82  downto 0);
  signal valid_flag        : std_logic;
  
  alias  s_HB              : std_logic is trg_i(1);
  alias  s_EOx_0           : std_logic is trg_i(8);
  alias  s_EOx_1           : std_logic is trg_i(10);

begin

    process(clk_i)
      variable store_count     : natural := 0;
      variable new_store_count : natural := 0;
      variable flag            : natural := 0;
      variable write_flag      : std_logic := '0';
    begin
--      if rising_edge(clk_i) and clk_en_i = '1' then
      if rising_edge(clk_i) then
      if clk_en_i = '1' then
        store_count := to_integer(unsigned(s_store_count(8 downto 0)));
        write_flag  := or_reduce(data_i);
        if( rst_i = '1' ) then
           s_store_count   <= (others => '0');
           temp_data_s     <= (others => '0');
           data            <= (others => '0');
           valid_flag      <= '0';
           new_store_count := 0;
           store_count     := 0;
           helper_orbit    <= '0';
           
           
-- PACKER RELEASE
        elsif( s_HB = '1' or s_EOx_0 = '1' or s_EOx_1 = '1' ) then       
               if helper_orbit = '0' then     
               data(82)                               <= s_EOx_1;  
               else 
               data(82)                               <= '0';
               end if;    
               data(81)                               <= s_EOx_0;  
               data(80)                               <= s_HB;  
               data(79            downto 0)           <= temp_data_s(79 downto 0);
               valid_flag      <= '1';
               s_store_count   <= (others => '0');
               temp_data_s     <= (others => '0');
               new_store_count := 0;
               store_count     := 0;
               helper_orbit    <= '1';
        
        elsif( write_flag = '0' and store_valid = '1' ) then
               valid_flag <= '0';   
               store_valid <= '0';   
               helper_orbit    <= '0';

-- ZERO SUPPRESSION
        elsif( write_flag = '1' ) then   
          helper_orbit    <= '0';
          case store_count is
	           when 0 =>
	               temp_data_s(59  downto  0) <= data_i(47 downto 0) & bc_count_i;
	               temp_data_s(299 downto 61) <= (others => '0');
	               store_count := 60;
	               data <= (others => '0');
	               valid_flag <= '0';
	               store_valid <= '0';
	           when 20 =>
	               data(82)                               <= s_EOx_1;  
                   data(81)                               <= s_EOx_0;  
                   data(80)                               <= s_HB;  
                   data(79           downto  0)           <= data_i(47 downto 0) & bc_count_i(11 downto 0) & temp_data_s(19 downto 0);
--                 temp_data_s(15      downto  0)           <= data_i(63 downto 48);
--	               temp_data_s(299     downto 16)           <= (others => '0');                   
                   temp_data_s(299     downto  0)           <= (others => '0');
     	           store_count := 0;
	               valid_flag <= '1';  
 	               store_valid <= '1';    	           	               	                  	           
	           when 40 =>
	               data(82)                               <= s_EOx_1;  
                   data(81)                               <= s_EOx_0;  
                   data(80)                               <= s_HB;  
                   data(79           downto  0)           <= data_i(27 downto 0) & bc_count_i(11 downto 0) & temp_data_s(39 downto 0);
                   temp_data_s(19      downto  0)           <= data_i(47 downto 28);
	               temp_data_s(299     downto 20)           <= (others => '0');                   
     	           store_count := 20;
 	               valid_flag <= '1';
  	               store_valid <= '1';    	           	                	                   	           
	           when 60 =>
	               data(82)                               <= s_EOx_1;  
                   data(81)                               <= s_EOx_0;  
                   data(80)                               <= s_HB;  
                   data(79           downto  0)           <= data_i(7 downto 0) & bc_count_i(11 downto 0) & temp_data_s(59 downto 0);
                   temp_data_s(39      downto  0)           <= data_i(47 downto 8);
	               temp_data_s(299     downto 40)           <= (others => '0');                   
     	           store_count := 40;
	               valid_flag <= '1';
 	               store_valid <= '1';    	           	               
	            when others =>   
                   data      <= (others => '0');
                   temp_data_s <= (others => '0');
                   valid_flag  <= '0';
                   store_count := 0;
                   store_valid <= '0'; 

            end case;
            s_store_count <= std_logic_vector(to_unsigned(store_count,s_store_count'length));
         
         else
               data     <= (others => '0');
               valid_flag <= '0';
               helper_orbit    <= '0';
            
         end if;
       end if;
    end if;        
    end process;

   
    process(clk_i)
    begin
      if rising_edge(clk_i) then
      if clk_en_i = '1' then
        data_o <= data;
        valid_flag_o <= valid_flag;
      end if;
      end if;
    end process;         
    
end;
