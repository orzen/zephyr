/*
 * Copyright (c) 2019, Gerson Fernando Budke
 * Copyright (c) 2019, Aurelien Jarno
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <init.h>

#if defined CONFIG_PWM && defined DT_INST_0_ATMEL_SAM_PWM
/* PWM on EXT1 connector, pin 7, channel 0, inverted */
static const struct soc_gpio_pin pwm_ext1_pin7 = {
	PIO_PA0A_PWM0_PWMH0, PIOA, ID_PIOA, SOC_GPIO_FUNC_A
};

/* PWM on EXT2 connector, pin 7, channel 2, inverted */
static const struct soc_gpio_pin pwm_ext2_pin7 = {
	PIO_PC19B_PWM0_PWMH2, PIOC, ID_PIOC, SOC_GPIO_FUNC_B
};

/* PWM on EXT2 connector, pin 8, channel 2, non-inverted  */
static const struct soc_gpio_pin pwm_ext2_pin8 = {
	PIO_PD26A_PWM0_PWML2, PIOD, ID_PIOD, SOC_GPIO_FUNC_A
};
#endif

static int sam_v71_xplained_init(struct device *dev)
{
	ARG_UNUSED(dev);

#if defined CONFIG_PWM && DT_INST_0_ATMEL_SAM_PWM
	soc_gpio_configure(&pwm_ext1_pin7);
	soc_gpio_configure(&pwm_ext2_pin7);
	soc_gpio_configure(&pwm_ext2_pin8);
#endif

	return 0;
}

SYS_INIT(sam_v71_xplained_init, PRE_KERNEL_1, 0);
