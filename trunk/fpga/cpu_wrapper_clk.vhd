library IEEE;
Library UNISIM;
use UNISIM.vcomponents.all;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_ARITH.ALL;
use ieee.std_logic_UNSIGNED.ALL;

entity cpu_wrapper_clk is
    port (
        RESET           : in std_logic;
        CLK             : in std_logic;
        CLK_CPU         : in std_logic;

        ADDR            : out std_logic_vector(15 downto 0);
        DIN             : in  std_logic_vector(7 downto 0);
        DOUT            : out std_logic_vector(7 downto 0);
        
        MEM_DIN_RD      : out std_logic;
        MEM_DIN_VLD     : in std_logic;
        MEM_DOUT_WR     : out std_logic;
        MEM_DOUT_VLD    : in std_logic;        
    
        IO_DIN_RD       : out std_logic;
        IO_DIN_VLD      : in std_logic;
        IO_DOUT_WR      : out std_logic;
        IO_DOUT_VLD     : in std_logic;        

        INT             : in std_logic
    );
end entity;

architecture cpu_wrapper_clk_inst of cpu_wrapper_clk is

    signal cpu_addr             : std_logic_vector(15 downto 0);
    signal cpu_din              : std_logic_vector(7 downto 0);
    signal cpu_dout             : std_logic_vector(7 downto 0);
        
    signal cpu_mem_din_rd       : std_logic;
    signal cpu_mem_din_vld      : std_logic;
    signal cpu_mem_dout_wr      : std_logic;
    signal cpu_mem_dout_vld     : std_logic;
    
    signal cpu_io_din_rd        : std_logic;
    signal cpu_io_din_vld       : std_logic;
    signal cpu_io_dout_wr       : std_logic;
    signal cpu_io_dout_vld      : std_logic;

    signal din_reset            : std_logic;

    signal reg_cpu_mem_din_rd   : std_logic;
    signal reg_cpu_mem_dout_wr  : std_logic;

    signal reg_cpu_io_din_rd    : std_logic;
    signal reg_cpu_io_dout_wr   : std_logic;
    
    signal cpu_int              : std_logic;
    signal cpu_int_counter      : std_logic_vector(5 downto 0);
begin

    process(CLK)
    begin
        if CLK'event and CLK='1' then
            ADDR <= cpu_addr;
            DOUT <= cpu_dout;
            
            if RESET='1' or din_reset='1' then
                cpu_din <= (others=>'0');
                cpu_mem_din_vld <= '0';
                cpu_mem_dout_vld <= '0';
                cpu_io_din_vld <= '0';
                cpu_io_dout_vld <= '0';
            elsif MEM_DIN_VLD='1' or MEM_DOUT_VLD='1' or IO_DIN_VLD='1' or IO_DOUT_VLD='1' then
                cpu_din <= DIN;
                cpu_mem_din_vld <= MEM_DIN_VLD;
                cpu_mem_dout_vld <= MEM_DOUT_VLD;
                cpu_io_din_vld <= IO_DIN_VLD;
                cpu_io_dout_vld <= IO_DOUT_VLD;
            end if;
            
            if RESET='1' or cpu_int_counter(5)='1' then
                cpu_int <= '0';
            elsif INT='1' then
                cpu_int <= '1';
            end if;
            
            reg_cpu_mem_din_rd <= cpu_mem_din_rd;
            if RESET='1' or MEM_DIN_VLD='1' then
                MEM_DIN_RD <= '0';
            elsif cpu_mem_din_rd='1' and reg_cpu_mem_din_rd='0' then
                MEM_DIN_RD <= '1';
            end if;
            
            reg_cpu_mem_dout_wr <= cpu_mem_dout_wr;
            if RESET='1' or MEM_DOUT_VLD='1' then
                MEM_DOUT_WR <= '0';
            elsif cpu_mem_dout_wr='1' and reg_cpu_mem_dout_wr='0' then
                MEM_DOUT_WR <= '1';
            end if;

            reg_cpu_io_din_rd <= cpu_io_din_rd;
            if RESET='1' or IO_DIN_VLD='1' then
                IO_DIN_RD <= '0';
            elsif cpu_io_din_rd='1' and reg_cpu_io_din_rd='0' then
                IO_DIN_RD <= '1';
            end if;
            
            reg_cpu_io_dout_wr <= cpu_io_dout_wr;
            if RESET='1' or IO_DOUT_VLD='1' then
                IO_DOUT_WR <= '0';
            elsif cpu_io_dout_wr='1' and reg_cpu_io_dout_wr='0' then
                IO_DOUT_WR <= '1';
            end if;
            
        end if;
    end process;

    din_reset <= not (cpu_mem_din_rd or cpu_mem_dout_wr or cpu_io_din_rd or cpu_io_dout_wr);


    process(CLK_CPU)
    begin
        if CLK_CPU'event and CLK_CPU='1' then
            if RESET='1' or cpu_int='0' then
                cpu_int_counter <= (others=>'0');
            else
                cpu_int_counter <= cpu_int_counter + 1;
            end if;
        end if;
    end process;


    cpu_wrapper_inst : entity work.cpu_wrapper
    port map (
        RESET           => RESET,
        CLK             => CLK_CPU,

        ADDR            => cpu_addr,
        DIN             => cpu_din,
        DOUT            => cpu_dout,
        
        MEM_DIN_RD      => cpu_mem_din_rd,
        MEM_DIN_VLD     => cpu_mem_din_vld,
        MEM_DOUT_WR     => cpu_mem_dout_wr,
        MEM_DOUT_VLD    => cpu_mem_dout_vld,
    
        IO_DIN_RD       => cpu_io_din_rd,
        IO_DIN_VLD      => cpu_io_din_vld,
        IO_DOUT_WR      => cpu_io_dout_wr,
        IO_DOUT_VLD     => cpu_io_dout_vld,

        INT             => cpu_int
    );

end cpu_wrapper_clk_inst;

