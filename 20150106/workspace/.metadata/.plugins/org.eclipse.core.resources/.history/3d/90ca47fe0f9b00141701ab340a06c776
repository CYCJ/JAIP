################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/class_loader.c \
../src/class_manager.c \
../src/file.c \
../src/heap_manager.c \
../src/jpl.c \
../src/main.c \
../src/mem_dbg.c \
../src/native_method.c \
../src/platform.c 

LD_SRCS += \
../src/lscript.ld 

OBJS += \
./src/class_loader.o \
./src/class_manager.o \
./src/file.o \
./src/heap_manager.o \
./src/jpl.o \
./src/main.o \
./src/mem_dbg.o \
./src/native_method.o \
./src/platform.o 

C_DEPS += \
./src/class_loader.d \
./src/class_manager.d \
./src/file.d \
./src/heap_manager.d \
./src/jpl.d \
./src/main.d \
./src/mem_dbg.d \
./src/native_method.d \
./src/platform.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.c
	@echo Building file: $<
	@echo Invoking: MicroBlaze gcc compiler
	mb-gcc -Wall -O0 -g3 -c -fmessage-length=0 -I../../jaip_bsp_0/microblaze_0/include -mxl-barrel-shift -mxl-pattern-compare -mcpu=v8.20.b -mno-xl-soft-mul -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -o"$@" "$<"
	@echo Finished building: $<
	@echo ' '


