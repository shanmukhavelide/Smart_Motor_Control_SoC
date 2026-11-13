# =============================================================================
# Smart ControlSoC - RISC-V Bare-Metal Firmware Makefile
# Architecture: RV32IM / ABI: ilp32
# Target: VeeR EL2 Core
# =============================================================================

CROSS_COMPILE ?= riscv64-unknown-elf-
CC             = $(CROSS_COMPILE)gcc
OBJCOPY        = $(CROSS_COMPILE)objcopy
OBJDUMP        = $(CROSS_COMPILE)objdump
SIZE           = $(CROSS_COMPILE)size

ARCH_FLAGS     = -march=rv32im -mabi=ilp32
CFLAGS         = $(ARCH_FLAGS) -O2 -g -Wall -Wextra -ffreestanding -nostdlib \
                 -I. -Isw -Idrivers -Ibsp
ASFLAGS        = $(ARCH_FLAGS) -g
LDFLAGS        = $(ARCH_FLAGS) -nostdlib -T bsp/link.ld -Wl,-Map=build/firmware.map

BUILD_DIR      = build

SRCS_C         = app/main.c \
                 drivers/uart.c \
                 drivers/timer.c \
                 drivers/gpio.c \
                 drivers/spi.c \
                 drivers/pwm.c \
                 drivers/seg7.c

SRCS_ASM       = bsp/startup.S

OBJS           = $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRCS_C)) \
                 $(patsubst %.S,$(BUILD_DIR)/%.o,$(SRCS_ASM))

TARGET_ELF     = $(BUILD_DIR)/firmware.elf
TARGET_BIN     = $(BUILD_DIR)/firmware.bin
TARGET_HEX     = $(BUILD_DIR)/firmware.hex
TARGET_DIS     = $(BUILD_DIR)/firmware.dis

# VeeR EL2 Bare-Metal Target Configuration
TARGET_VEER_ELF = $(BUILD_DIR)/firmware_veer.elf
TARGET_VEER_BIN = $(BUILD_DIR)/firmware_veer.bin
TARGET_VEER_HEX = $(BUILD_DIR)/firmware_veer.hex
TARGET_VEER_DIS = $(BUILD_DIR)/firmware_veer.dis

SRCS_VEER_C     = app/main_veer.c \
                  drivers/uart.c \
                  drivers/timer.c \
                  drivers/gpio.c \
                  drivers/spi.c \
                  drivers/pwm.c \
                  drivers/seg7.c

SRCS_VEER_ASM   = bsp/startup_veer.S

OBJS_VEER       = $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRCS_VEER_C)) \
                  $(patsubst %.S,$(BUILD_DIR)/%.o,$(SRCS_VEER_ASM))

LDFLAGS_VEER    = $(ARCH_FLAGS) -nostdlib -T bsp/link_veer.ld -Wl,-Map=$(BUILD_DIR)/firmware_veer.map

.PHONY: all clean dis veer

all: $(TARGET_ELF) $(TARGET_BIN) $(TARGET_HEX) $(TARGET_DIS)
	@echo "=================================================================="
	@echo "   RISC-V Firmware Build Successful!"
	@echo "   ELF binary   : $(TARGET_ELF)"
	@echo "   Verilog hex  : $(TARGET_HEX)"
	@echo "   Disassembly  : $(TARGET_DIS)"
	@echo "=================================================================="
	@$(SIZE) $(TARGET_ELF)

veer: $(TARGET_VEER_ELF) $(TARGET_VEER_BIN) $(TARGET_VEER_HEX) $(TARGET_VEER_DIS)
	@echo "=================================================================="
	@echo "   VeeR EL2 Bare-Metal Firmware Build Successful!"
	@echo "   ELF binary   : $(TARGET_VEER_ELF)"
	@echo "   Verilog hex  : $(TARGET_VEER_HEX)"
	@echo "   Disassembly  : $(TARGET_VEER_DIS)"
	@echo "=================================================================="
	@$(SIZE) $(TARGET_VEER_ELF)

$(TARGET_VEER_ELF): $(OBJS_VEER) bsp/link_veer.ld | $(BUILD_DIR)
	$(CC) $(OBJS_VEER) $(LDFLAGS_VEER) -o $@

$(TARGET_VEER_BIN): $(TARGET_VEER_ELF)
	$(OBJCOPY) -O binary $< $@

$(TARGET_VEER_HEX): $(TARGET_VEER_ELF)
	$(OBJCOPY) -O verilog --verilog-data-width 4 $< $@

$(TARGET_VEER_DIS): $(TARGET_VEER_ELF)
	$(OBJDUMP) -d -S $< > $@

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)/app $(BUILD_DIR)/drivers $(BUILD_DIR)/bsp

$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.S | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -c $< -o $@

$(TARGET_ELF): $(OBJS) bsp/link.ld
	$(CC) $(OBJS) $(LDFLAGS) -o $@

$(TARGET_BIN): $(TARGET_ELF)
	$(OBJCOPY) -O binary $< $@

$(TARGET_HEX): $(TARGET_ELF)
	$(OBJCOPY) -O verilog --verilog-data-width 4 $< $@

$(TARGET_DIS): $(TARGET_ELF)
	$(OBJDUMP) -d -S $< > $@

clean:
	rm -rf $(BUILD_DIR)

