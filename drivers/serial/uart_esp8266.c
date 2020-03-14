#include <drivers/uart.h>

#define DEV_CFG(dev) \
	((const struct esp8266_uart_cfg *const)(dev)->config->config_info)
#define DEV_BASE(dev) \
	((volatile struct esp8266_uart_regs_t  *)(DEV_CFG(dev))->dev_conf.base)
#define DEV_DATA(dev) \
	((struct esp8266_uart_data *)(dev)->driver_data)

struct esp8266_uart_cfg {
	

};


static int uart_esp8266_poll_in(struct device *dev, unsigned char *p_char) {
	volatile struct dev->config;


}

static const struct uart_driver_api esp8266_uart_api = {
#ifdef CONFIG_UART_ASYNC_API
	.callback_set = 
	.tx =
	.tx_abort =
	.rx_enable =
	.rx_buf_rsp =
	.rx_disable =
#endif

	.poll_in = uart_esp8266_poll_in,
	.poll_out = uart_esp8266_poll_out,
	.err_check = uart_esp8266_err_check,
	.configure = ,
	.config_set = ,

#ifdef CONFIG_UART_INTERRUPT_DRIVEN
	.fifo_fill = ,
	.fifo_read = ,
	.irq_tx_enable = ,
	.irq_tx_disable = ,
	.irq_tx_ready =,
	.irq_tx_complete =,
	.irq_rx_enable = ,
	.irq_rx_disable = ,
	.irq_rx_ready =,
	.irq_err_enable = ,
	.irq_err_disable = ,
	.irq_is_pending = ,
	.irq_update = ,
	.irq_callback_set = ,
#endif

#ifdef CONFIG_UART_LINE_CTRL
	.line_ctrl_set = ,
	.line_ctrl_get = ,
#endif

#ifdef CONFIG_UART_DRV_CMD
	.drv_cmd = ,
#endif
};
