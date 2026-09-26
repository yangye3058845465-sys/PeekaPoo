#include <stdio.h>
#include <string.h>

#include "cmsis_os2.h"
#include "ohos_init.h"
#include "iot_gpio.h"
#include "iot_i2c.h"
#include "iot_uart.h"
#include "hi_adc.h"
#include "hi_io.h"

#define LED_GPIO            9
#define PIR_GPIO            10
#define BTN_GPIO            11      /* active low */
#define PRESSURE_ADC_CH     HI_ADC_CHANNEL_2   /* GPIO5 */
#define UART_ID             1       /* GPIO0 TXD, GPIO1 RXD */
#define I2C_ID              0       /* GPIO13 SDA, GPIO14 SCL */
#define ADS7828_ADDR        0x48
#define N_GAS               8

#define PRESSURE_THRESHOLD  600
#define END_WAIT_MS         30000
#define LOOP_MS             100
#define GAS_PERIOD_MS       500
#define HEARTBEAT_MS        10000

static void uart_send(const char *s)
{
    IoTUartWrite(UART_ID, (const unsigned char *)s, strlen(s));
}

static unsigned short read_pressure(void)
{
    unsigned short v = 0;
    if (hi_adc_read(PRESSURE_ADC_CH, &v, HI_ADC_EQU_MODEL_4, HI_ADC_CUR_BAIS_DEFAULT, 0) != 0) {
        return 0;
    }
    return v;
}

/* ADS7828 single-ended: CH0,2,4,6 -> 0..3, CH1,3,5,7 -> 4..7 */
static int read_gas(int ch)
{
    unsigned char sel = (unsigned char)(((ch >> 1) & 0x03) | ((ch & 0x01) << 2));
    unsigned char cmd = 0x80 | (sel << 4) | 0x0C;   /* SD=1, PD=11 */
    unsigned char buf[2] = {0};
    if (IoTI2cWrite(I2C_ID, (ADS7828_ADDR << 1) | 0, &cmd, 1) != 0) {
        return -1;
    }
    if (IoTI2cRead(I2C_ID, (ADS7828_ADDR << 1) | 1, buf, 2) != 0) {
        return -1;
    }
    return ((buf[0] & 0x0F) << 8) | buf[1];
}

static void led_set(int on)
{
    IoTGpioSetOutputVal(LED_GPIO, on ? IOT_GPIO_VALUE1 : IOT_GPIO_VALUE0);
}

static void poll_commands(void)
{
    unsigned char rx[64] = {0};
    int n = IoTUartRead(UART_ID, rx, sizeof(rx) - 1);
    if (n > 0 && strstr((char *)rx, "\"led\"") != NULL) {
        led_set(strstr((char *)rx, "\"v\":1") != NULL);
    }
}

static void hw_init(void)
{
    IotUartAttribute uart = {
        .baudRate = 115200, .dataBits = IOT_UART_DATA_BIT_8,
        .stopBits = IOT_UART_STOP_BIT_1, .parity = IOT_UART_PARITY_NONE,
        .rxBlock = IOT_UART_BLOCK_STATE_NONE_BLOCK, .txBlock = IOT_UART_BLOCK_STATE_BLOCK,
    };
    hi_io_set_func(HI_IO_NAME_GPIO_0, HI_IO_FUNC_GPIO_0_UART1_TXD);
    hi_io_set_func(HI_IO_NAME_GPIO_1, HI_IO_FUNC_GPIO_1_UART1_RXD);
    IoTUartInit(UART_ID, &uart);

    hi_io_set_func(HI_IO_NAME_GPIO_13, HI_IO_FUNC_GPIO_13_I2C0_SDA);
    hi_io_set_func(HI_IO_NAME_GPIO_14, HI_IO_FUNC_GPIO_14_I2C0_SCL);
    IoTI2cInit(I2C_ID, 400000);

    IoTGpioInit(LED_GPIO);
    IoTGpioSetDir(LED_GPIO, IOT_GPIO_DIR_OUT);
    led_set(0);
    IoTGpioInit(PIR_GPIO);
    IoTGpioSetDir(PIR_GPIO, IOT_GPIO_DIR_IN);
    IoTGpioInit(BTN_GPIO);
    IoTGpioSetDir(BTN_GPIO, IOT_GPIO_DIR_IN);
}

static void ctrl_task(void *arg)
{
    (void)arg;
    char line[160];
    int occupied = 0;
    int below_ms = 0;
    int gas_ms = 0;
    int hb_ms = 0;
    int user = 1;
    IotGpioValue btn_prev = IOT_GPIO_VALUE1;

    hw_init();
    uart_send("{\"t\":\"hb\"}\n");

    while (1) {
        unsigned short p = read_pressure();
        IotGpioValue pir = IOT_GPIO_VALUE0;
        IoTGpioGetInputVal(PIR_GPIO, &pir);
        int present = (p > PRESSURE_THRESHOLD) || (pir == IOT_GPIO_VALUE1);

        if (present) {
            below_ms = 0;
            if (!occupied) {
                occupied = 1;
                led_set(1);
                snprintf(line, sizeof(line), "{\"t\":\"occ\",\"v\":1,\"p\":%u}\n", p);
                uart_send(line);
            }
        } else if (occupied) {
            below_ms += LOOP_MS;
            if (below_ms >= END_WAIT_MS) {
                occupied = 0;
                below_ms = 0;
                led_set(0);
                snprintf(line, sizeof(line), "{\"t\":\"occ\",\"v\":0,\"p\":%u}\n", p);
                uart_send(line);
            }
        }

        gas_ms += LOOP_MS;
        if (gas_ms >= GAS_PERIOD_MS) {
            gas_ms = 0;
            int g[N_GAS];
            for (int i = 0; i < N_GAS; i++) {
                g[i] = read_gas(i);
            }
            snprintf(line, sizeof(line), "{\"t\":\"gas\",\"v\":[%d,%d,%d,%d,%d,%d,%d,%d]}\n",
                     g[0], g[1], g[2], g[3], g[4], g[5], g[6], g[7]);
            uart_send(line);
        }

        IotGpioValue btn = IOT_GPIO_VALUE1;
        IoTGpioGetInputVal(BTN_GPIO, &btn);
        if (btn_prev == IOT_GPIO_VALUE1 && btn == IOT_GPIO_VALUE0) {
            user = user % 4 + 1;
            snprintf(line, sizeof(line), "{\"t\":\"uid\",\"v\":%d}\n", user);
            uart_send(line);
        }
        btn_prev = btn;

        hb_ms += LOOP_MS;
        if (hb_ms >= HEARTBEAT_MS) {
            hb_ms = 0;
            uart_send("{\"t\":\"hb\"}\n");
        }

        poll_commands();
        osDelay(LOOP_MS / 10);   /* 10 ms tick */
    }
}

static void peekapoo_entry(void)
{
    osThreadAttr_t attr = {0};
    attr.name = "peekapoo_ctrl";
    attr.stack_size = 4096;
    attr.priority = osPriorityNormal;
    if (osThreadNew(ctrl_task, NULL, &attr) == NULL) {
        printf("[peekapoo] failed to create task\n");
    }
}

APP_FEATURE_INIT(peekapoo_entry);
