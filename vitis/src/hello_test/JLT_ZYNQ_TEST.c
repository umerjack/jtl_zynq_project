/*
 * Mini-JLT Interactive SCPI Console
 *
 * PC Terminal / PS UART:
 *     Used for user input and displaying NMEA.
 *
 * AXI UART Lite:
 *     TX -> Zynq D20 -> Mini-JLT J1 Pin 3 (Mini-JLT RX)
 *     RX <- Zynq B20 <- Mini-JLT J1 Pin 2 (Mini-JLT TX)
 *
 * Operation:
 *     1. Type any Mini-JLT SCPI command in the PC terminal.
 *     2. Press ENTER.
 *     3. Command is sent through AXI UART Lite TX to Mini-JLT.
 *     4. AXI UART Lite RX is continuously drained.
 *     5. NMEA received from Mini-JLT is printed on the PC terminal.
 *
 * No interrupts are used.
 */

#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xuartps.h"


/* ============================================================
 * AXI UART Lite
 * ============================================================ */

#define UARTLITE_BASEADDR    XPAR_AXI_UARTLITE_0_BASEADDR

#define UART_RX_FIFO         0x00U
#define UART_TX_FIFO         0x04U
#define UART_STATUS          0x08U
#define UART_CONTROL         0x0CU

/* Status register bits */
#define RX_FIFO_VALID_DATA   (1U << 0)
#define TX_FIFO_FULL         (1U << 3)

/* Control register bits */
#define TX_FIFO_RESET        (1U << 0)
#define RX_FIFO_RESET        (1U << 1)


/* ============================================================
 * PS UART
 *
 * Your BSP only contains XPAR_XUARTPS_0_BASEADDR.
 * ============================================================ */

#define PS_UART_BASEADDR     XPAR_XUARTPS_0_BASEADDR


/* ============================================================
 * Buffers
 * ============================================================ */

#define COMMAND_MAX_LEN      128U
#define NMEA_MAX_LEN         128U

static char command_buffer[COMMAND_MAX_LEN];
static unsigned int command_length = 0;

static char nmea_buffer[NMEA_MAX_LEN];
static unsigned int nmea_length = 0;
static int nmea_receiving = 0;


/* ============================================================
 * AXI UART Lite functions
 * ============================================================ */

static unsigned int uartlite_status(void)
{
    return Xil_In32(UARTLITE_BASEADDR + UART_STATUS);
}


static int uartlite_rx_available(void)
{
    return (uartlite_status() & RX_FIFO_VALID_DATA) != 0;
}


static int uartlite_tx_full(void)
{
    return (uartlite_status() & TX_FIFO_FULL) != 0;
}


static unsigned char uartlite_rx_byte(void)
{
    return (unsigned char)
           Xil_In32(UARTLITE_BASEADDR + UART_RX_FIFO);
}


static void uartlite_tx_byte(unsigned char data)
{
    /*
     * Wait until TX FIFO has space.
     */
    while (uartlite_tx_full())
    {
        /* Poll */
    }

    Xil_Out32(UARTLITE_BASEADDR + UART_TX_FIFO, data);
}


static void uartlite_reset(void)
{
    Xil_Out32(
        UARTLITE_BASEADDR + UART_CONTROL,
        TX_FIFO_RESET | RX_FIFO_RESET
    );
}


/* ============================================================
 * Send SCPI command to Mini-JLT
 * ============================================================ */

static void send_command_to_jlt(const char *command)
{
    unsigned int i;

    for (i = 0; command[i] != '\0'; i++)
    {
        uartlite_tx_byte((unsigned char)command[i]);
    }

    /*
     * Mini-JLT SCPI command termination.
     */
    uartlite_tx_byte('\r');
}


/* ============================================================
 * NMEA receiver
 *
 * Continuously drains AXI UART Lite RX FIFO.
 * ============================================================ */

static void process_nmea_byte(unsigned char c)
{
    /*
     * Start of NMEA sentence.
     */
    if (c == '$')
    {
        nmea_receiving = 1;
        nmea_length = 0;

        nmea_buffer[nmea_length++] = '$';
        return;
    }

    /*
     * Ignore anything before '$'.
     */
    if (!nmea_receiving)
    {
        return;
    }

    /*
     * End of NMEA sentence.
     */
    if ((c == '\r') || (c == '\n'))
    {
        if (nmea_length > 0)
        {
            nmea_buffer[nmea_length] = '\0';

            xil_printf("\r\nNMEA: %s\r\n", nmea_buffer);
        }

        nmea_receiving = 0;
        nmea_length = 0;

        return;
    }

    /*
     * Store character if there is room.
     */
    if (nmea_length < (NMEA_MAX_LEN - 1U))
    {
        nmea_buffer[nmea_length++] = (char)c;
    }
    else
    {
        /*
         * Sentence too long.
         * Discard it and wait for the next '$'.
         */
        nmea_receiving = 0;
        nmea_length = 0;
    }
}


/* ============================================================
 * Continuously drain Mini-JLT RX FIFO
 * ============================================================ */

static void process_mini_jlt_rx(void)
{
    unsigned char c;

    /*
     * IMPORTANT:
     *
     * Do not read only one byte.
     * Drain the complete RX FIFO every time.
     */
    while (uartlite_rx_available())
    {
        c = uartlite_rx_byte();

        process_nmea_byte(c);
    }
}


/* ============================================================
 * Process character typed on PC terminal
 * ============================================================ */

static void process_terminal_character(unsigned char c)
{
    /*
     * ENTER
     */
    if ((c == '\r') || (c == '\n'))
    {
        if (command_length == 0)
        {
            xil_printf("\r\nSCPI> ");
            return;
        }

        /*
         * Terminate command string.
         */
        command_buffer[command_length] = '\0';

        /*
         * Show what will be transmitted.
         */
        xil_printf("\r\nTX -> Mini-JLT: %s\r\n", command_buffer);

        /*
         * Send command through AXI UART Lite TX.
         */
        send_command_to_jlt(command_buffer);

        /*
         * Clear command buffer.
         */
        command_length = 0;

        xil_printf("SCPI> ");

        return;
    }


    /*
     * BACKSPACE / DELETE
     */
    if ((c == '\b') || (c == 127U))
    {
        if (command_length > 0)
        {
            command_length--;

            /*
             * Erase character on terminal.
             */
            xil_printf("\b \b");
        }

        return;
    }


    /*
     * Printable ASCII character.
     */
    if ((c >= 32U) && (c <= 126U))
    {
        if (command_length < (COMMAND_MAX_LEN - 1U))
        {
            command_buffer[command_length++] = (char)c;

            /*
             * Echo character to PC terminal.
             */
            xil_printf("%c", c);
        }

        return;
    }
}


/* ============================================================
 * Main
 * ============================================================ */

int main(void)
{
    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf(" Mini-JLT SCPI Console\r\n");
    xil_printf("========================================\r\n");

    xil_printf("PS UART      : 0x%08X\r\n", PS_UART_BASEADDR);
    xil_printf("AXI UART Lite: 0x%08X\r\n", UARTLITE_BASEADDR);

    xil_printf("\r\n");
    xil_printf("Connections:\r\n");
    xil_printf("  Mini-JLT TX -> B20 / AXI UART RX\r\n");
    xil_printf("  Mini-JLT RX <- D20 / AXI UART TX\r\n");

    xil_printf("\r\n");
    xil_printf("Type any SCPI command and press ENTER.\r\n");
    xil_printf("Example: GPS:GPZDA 5\r\n");
    xil_printf("\r\n");

    /*
     * Reset AXI UART Lite FIFOs.
     */
    uartlite_reset();

    command_length = 0;
    nmea_length = 0;
    nmea_receiving = 0;

    xil_printf("SCPI> ");


    /*
     * ========================================================
     * MAIN POLLING LOOP
     * ========================================================
     */
    while (1)
    {
        /*
         * 1. Continuously drain Mini-JLT RX FIFO.
         *
         * Mini-JLT NMEA can arrive at any time.
         */
        process_mini_jlt_rx();


        /*
         * 2. Check whether user typed something
         *    on the PC terminal.
         */
        if (XUartPs_IsReceiveData(PS_UART_BASEADDR))
        {
            unsigned char c;

            c = XUartPs_RecvByte(PS_UART_BASEADDR);

            process_terminal_character(c);
        }
    }

    return 0;
}
